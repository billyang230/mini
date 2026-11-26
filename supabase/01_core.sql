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
