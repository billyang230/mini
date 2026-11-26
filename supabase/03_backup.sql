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
