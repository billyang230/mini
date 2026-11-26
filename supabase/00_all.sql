-- 迷你測試服：一次安裝全部資料庫程式（= 01_core + 02_gm + 03_backup）
-- 用法：Supabase 後台 → SQL Editor → New query → 整份貼上 → Run。可以重複執行。

-- ================= supabase/01_core.sql =================
-- 迷你測試服 第一階段：帳號存檔、排行榜、聊天／全服廣播、伺服器設定、在線人數
-- 用法：Supabase 後台 → SQL Editor → New query → 整份貼上 → Run
-- 可以重複執行，不會刪掉資料。

-- ========== 資料表 ==========

-- 每個帳號一份存檔（整個 mock DB，包含三個角色欄位）
create table if not exists public.saves (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  username   text,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 每個角色一列，用於排行榜、查看玩家、名字是否重複
create table if not exists public.rankings (
  user_id    uuid not null references auth.users(id) on delete cascade,
  slot       int  not null,
  name       text,
  cls        text,
  cls_name   text,
  level      bigint  default 1,
  exp_pct    numeric default 0,
  gold       numeric default 0,
  power      numeric default 0,
  detail     jsonb,
  active     boolean not null default false,
  hidden     boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, slot)
);
create index if not exists rankings_name_idx    on public.rankings (name);
create index if not exists rankings_power_idx   on public.rankings (power desc);
create index if not exists rankings_level_idx   on public.rankings (level desc, exp_pct desc);
create index if not exists rankings_updated_idx on public.rankings (updated_at desc);

-- 聊天與全服通知（掉寶、強化、PK）
create table if not exists public.broadcasts (
  id         bigserial primary key,
  user_id    uuid references auth.users(id) on delete set null,
  kind       text not null,
  data       jsonb,
  created_at timestamptz not null default now()
);
create index if not exists broadcasts_kind_time_idx on public.broadcasts (kind, created_at desc);

-- 伺服器參數（經驗、掉寶倍率等），只有管理者能改
create table if not exists public.settings (
  key   text primary key,
  value jsonb
);

-- 管理者名單（GM）
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- ========== 權限（RLS）==========
alter table public.saves      enable row level security;
alter table public.rankings   enable row level security;
alter table public.broadcasts enable row level security;
alter table public.settings   enable row level security;
alter table public.admins     enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

drop policy if exists saves_own on public.saves;
create policy saves_own on public.saves
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists rankings_read on public.rankings;
create policy rankings_read on public.rankings
  for select to authenticated using (true);
drop policy if exists rankings_write on public.rankings;
create policy rankings_write on public.rankings
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists rankings_update on public.rankings;
create policy rankings_update on public.rankings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists rankings_delete on public.rankings;
create policy rankings_delete on public.rankings
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists broadcasts_read on public.broadcasts;
create policy broadcasts_read on public.broadcasts
  for select to authenticated using (true);
drop policy if exists broadcasts_insert on public.broadcasts;
create policy broadcasts_insert on public.broadcasts
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings
  for select to authenticated using (true);
drop policy if exists settings_admin on public.settings;
create policy settings_admin on public.settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins
  for select to authenticated using (user_id = auth.uid());

-- ========== 伺服器函式 ==========

-- 登入時建立新的連線代號（sid）；同帳號在別處登入時，舊的那邊會被踢下線
create or replace function public.save_sid(p_sid text, p_username text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.saves (user_id, username, data, updated_at)
  values (auth.uid(), p_username, jsonb_build_object('chars', jsonb_build_array(null, null, null, null), 'sid', p_sid), now())
  on conflict (user_id) do update
    set data = jsonb_set(coalesce(saves.data, '{}'::jsonb), '{sid}', to_jsonb(p_sid)),
        username = excluded.username,
        updated_at = now();
  return true;
end $$;

-- 存檔；如果 sid 已經被新登入取代，回傳 false（前端會把這個視窗踢下線）
create or replace function public.save_put(p_data jsonb, p_sid text, p_username text)
returns boolean language plpgsql security definer set search_path = public as $$
declare cur text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select data->>'sid' into cur from public.saves where user_id = auth.uid() for update;
  if cur is not null and cur <> p_sid then
    return false;
  end if;
  insert into public.saves (user_id, username, data, updated_at)
  values (auth.uid(), p_username, jsonb_set(p_data, '{sid}', to_jsonb(p_sid)), now())
  on conflict (user_id) do update
    set data = excluded.data, username = excluded.username, updated_at = now();
  return true;
end $$;

-- 同 IP 帳號數限制：自己人玩，不限制
create or replace function public.ip_ping()
returns jsonb language sql stable as $$ select jsonb_build_object('ok', true) $$;
create or replace function public.ip_leave()
returns void language sql as $$ select $$;

-- 總玩家數
create or replace function public.player_total()
returns bigint language sql stable security definer set search_path = public as $$
  select count(distinct user_id) from public.rankings;
$$;

-- 行為紀錄（目前不保存，只讓前端不報錯）
create or replace function public.log_login(p_chars jsonb)
returns void language sql as $$ select $$;
create or replace function public.log_actions(p_rows jsonb)
returns void language sql as $$ select $$;

grant execute on function public.save_sid(text, text)          to authenticated;
grant execute on function public.save_put(jsonb, text, text)   to authenticated;
grant execute on function public.ip_ping()                     to authenticated;
grant execute on function public.ip_leave()                    to authenticated;
grant execute on function public.player_total()                to authenticated;
grant execute on function public.log_login(jsonb)              to authenticated;
grant execute on function public.log_actions(jsonb)            to authenticated;

-- ========== 即時推播（聊天、全服通知）==========
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'broadcasts'
  ) then
    alter publication supabase_realtime add table public.broadcasts;
  end if;
end $$;

-- 伺服器參數不預先寫入：直接用 game-debug2.js 裡的預設倍率（和可樂測試服相同）

-- ========== 資料表存取權限（新版 Supabase 不會自動開放）==========
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- ================= supabase/02_gm.sql =================
-- 迷你測試服：GM 管理功能（開帳號、重設密碼、帳號列表）
-- 只有 public.admins 裡的帳號能呼叫
create extension if not exists pgcrypto with schema extensions;

create or replace function public.gm_create_user(p_username text, p_password text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  v_email text := lower(p_username) || '@afei.gg';
  v_id uuid := gen_random_uuid();
begin
  if not public.is_admin() then raise exception '只有 GM 可以開帳號'; end if;
  if p_username !~ '^[A-Za-z0-9]{4,16}$' then raise exception '帳號要 4～16 個英文或數字'; end if;
  if length(p_password) < 8 then raise exception '密碼至少 8 個字'; end if;
  if lower(p_password) = lower(p_username) then raise exception '密碼不可以和帳號相同'; end if;
  if exists (select 1 from auth.users where email = v_email) then raise exception '這個帳號已經存在'; end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    crypt(p_password, gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', p_username), now(), now(),
    '', '', '', '', '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
  values (gen_random_uuid(), v_id, v_id::text,
          jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
          'email', now(), now(), now());
  return p_username;
end $$;

create or replace function public.gm_reset_password(p_username text, p_password text)
returns text language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_admin() then raise exception '只有 GM 可以重設密碼'; end if;
  if length(p_password) < 8 then raise exception '密碼至少 8 個字'; end if;
  if lower(p_password) = lower(p_username) then raise exception '密碼不可以和帳號相同'; end if;
  update auth.users set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
   where email = lower(p_username) || '@afei.gg';
  if not found then raise exception '找不到這個帳號'; end if;
  return p_username;
end $$;

create or replace function public.gm_list_users()
returns table (username text, created_at timestamptz, last_sign_in_at timestamptz, chars text, is_gm boolean)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '只有 GM 可以查看'; end if;
  return query
    select split_part(u.email, '@', 1)::text, u.created_at, u.last_sign_in_at,
           (select string_agg(r.name || ' Lv' || r.level, '、' order by r.slot) from public.rankings r where r.user_id = u.id)::text,
           exists (select 1 from public.admins a where a.user_id = u.id)
      from auth.users u
     order by u.created_at;
end $$;

revoke execute on function public.gm_create_user(text, text) from public, anon;
revoke execute on function public.gm_reset_password(text, text) from public, anon;
revoke execute on function public.gm_list_users() from public, anon;
grant execute on function public.gm_create_user(text, text) to authenticated;
grant execute on function public.gm_reset_password(text, text) to authenticated;
grant execute on function public.gm_list_users() to authenticated;

-- ================= supabase/03_backup.sql =================
-- 迷你測試服：存檔自動備份（每人最多保留 14 份，至少相隔 6 小時）＋ GM 還原
create table if not exists public.save_backups (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  username   text,
  data       jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists save_backups_user_idx on public.save_backups (user_id, created_at desc);
alter table public.save_backups enable row level security;  -- 不開任何 policy：一般玩家完全讀不到

create or replace function public.trg_backup_save() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.data is null or new.data = '{}'::jsonb then return new; end if;
  if not exists (select 1 from public.save_backups b
                 where b.user_id = new.user_id and b.created_at > now() - interval '6 hours') then
    insert into public.save_backups (user_id, username, data) values (new.user_id, new.username, new.data);
    delete from public.save_backups where user_id = new.user_id and id not in (
      select id from public.save_backups where user_id = new.user_id order by created_at desc limit 14);
  end if;
  return new;
end $$;

drop trigger if exists save_backup_trg on public.saves;
create trigger save_backup_trg after insert or update of data on public.saves
  for each row execute function public.trg_backup_save();

-- GM：列出某帳號的備份
create or replace function public.gm_list_backups(p_username text)
returns table (id bigint, created_at timestamptz, kb int)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '只有 GM 可以使用'; end if;
  return query select b.id, b.created_at, (length(b.data::text) / 1024)::int
               from public.save_backups b where lower(b.username) = lower(p_username)
               order by b.created_at desc;
end $$;

-- GM：把某份備份還原成目前存檔（請該玩家先登出）
create or replace function public.gm_restore_backup(p_id bigint) returns text
language plpgsql security definer set search_path = public as $$
declare b public.save_backups;
begin
  if not public.is_admin() then raise exception '只有 GM 可以使用'; end if;
  select * into b from public.save_backups where public.save_backups.id = p_id;
  if not found then raise exception '找不到這份備份'; end if;
  update public.saves set data = b.data, updated_at = now() where user_id = b.user_id;
  return '已還原 ' || coalesce(b.username, '') || ' 於 ' || b.created_at::text || ' 的備份';
end $$;

grant execute on function public.gm_list_backups(text), public.gm_restore_backup(bigint) to authenticated;
-- 先替現有存檔各做一份備份
insert into public.save_backups (user_id, username, data)
  select user_id, username, data from public.saves where data <> '{}'::jsonb;
