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
