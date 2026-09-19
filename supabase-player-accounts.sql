-- Golden Word Games custom player IDs (no email verification or email sending)
-- Run this complete file in Supabase -> SQL Editor -> New query -> Run.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.player_accounts (
  id uuid primary key default gen_random_uuid(), username text not null,
  password_hash text not null, email_text text not null default '', name text not null default '',
  phone text not null default '', age integer not null check (age between 18 and 120),
  avatar text not null default '🐶', address_line1 text not null default '', city text not null default '',
  state text not null default '', zip_code text not null default '', country text not null default 'United States',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists player_accounts_username_unique on public.player_accounts (lower(username));
create table if not exists public.player_sessions (
  token_hash text primary key, player_id uuid not null references public.player_accounts(id) on delete cascade,
  created_at timestamptz not null default now(), expires_at timestamptz not null default (now() + interval '90 days')
);
alter table public.player_accounts enable row level security;
alter table public.player_sessions enable row level security;
revoke all on public.player_accounts from anon, authenticated;
revoke all on public.player_sessions from anon, authenticated;

create or replace function public.gwg_player_json(p public.player_accounts)
returns jsonb language sql stable as $$ select jsonb_build_object(
  'id',p.id,'username',p.username,'email',p.email_text,'name',p.name,'phone',p.phone,'age',p.age,
  'avatar',p.avatar,'address_line1',p.address_line1,'city',p.city,'state',p.state,
  'zip_code',p.zip_code,'country',p.country); $$;

create or replace function public.create_player_account(
  p_username text,p_password text,p_email text,p_name text,p_phone text,p_age integer,
  p_address_line1 text default '',p_city text default '',p_state text default '',
  p_zip_code text default '',p_country text default 'United States')
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_player public.player_accounts; v_token text;
begin
  if length(trim(p_username))<3 then raise exception 'Username must have at least 3 characters'; end if;
  if length(p_password)<8 then raise exception 'Password must have at least 8 characters'; end if;
  if exists(select 1 from public.player_accounts where lower(username)=lower(trim(p_username))) then raise exception 'USERNAME_TAKEN'; end if;
  insert into public.player_accounts(username,password_hash,email_text,name,phone,age,address_line1,city,state,zip_code,country)
  values(trim(p_username),crypt(p_password,gen_salt('bf',10)),coalesce(p_email,''),trim(p_name),p_phone,p_age,
    coalesce(p_address_line1,''),coalesce(p_city,''),coalesce(p_state,''),coalesce(p_zip_code,''),coalesce(p_country,'United States'))
  returning * into v_player;
  v_token:=encode(gen_random_bytes(32),'hex');
  insert into public.player_sessions(token_hash,player_id) values(encode(digest(v_token,'sha256'),'hex'),v_player.id);
  return jsonb_build_object('token',v_token,'player',public.gwg_player_json(v_player));
end; $$;

create or replace function public.login_player(p_username text,p_password text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_player public.player_accounts; v_token text;
begin
  select * into v_player from public.player_accounts where lower(username)=lower(trim(p_username));
  if v_player.id is null or v_player.password_hash<>crypt(p_password,v_player.password_hash) then raise exception 'INVALID_LOGIN'; end if;
  v_token:=encode(gen_random_bytes(32),'hex');
  insert into public.player_sessions(token_hash,player_id) values(encode(digest(v_token,'sha256'),'hex'),v_player.id);
  return jsonb_build_object('token',v_token,'player',public.gwg_player_json(v_player));
end; $$;

create or replace function public.get_player_session(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_player public.player_accounts;
begin
  select p.* into v_player from public.player_accounts p join public.player_sessions s on s.player_id=p.id
  where s.token_hash=encode(digest(p_token,'sha256'),'hex') and s.expires_at>now();
  if v_player.id is null then return null; end if;
  return public.gwg_player_json(v_player);
end; $$;

create or replace function public.logout_player(p_token text)
returns void language sql security definer set search_path=public,extensions as $$
  delete from public.player_sessions where token_hash=encode(digest(p_token,'sha256'),'hex'); $$;

create or replace function public.update_player_profile(
  p_token text,p_username text,p_name text,p_phone text,p_age integer,p_avatar text,
  p_address_line1 text,p_city text,p_state text,p_zip_code text,p_country text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid; v_player public.player_accounts;
begin
  select player_id into v_id from public.player_sessions
  where token_hash=encode(digest(p_token,'sha256'),'hex') and expires_at>now();
  if v_id is null then raise exception 'SESSION_EXPIRED'; end if;
  if exists(select 1 from public.player_accounts where lower(username)=lower(trim(p_username)) and id<>v_id) then raise exception 'USERNAME_TAKEN'; end if;
  update public.player_accounts set username=trim(p_username),name=trim(p_name),phone=p_phone,age=p_age,
    avatar=p_avatar,address_line1=coalesce(p_address_line1,''),city=coalesce(p_city,''),state=coalesce(p_state,''),
    zip_code=coalesce(p_zip_code,''),country=coalesce(p_country,'United States'),updated_at=now()
  where id=v_id returning * into v_player;
  return public.gwg_player_json(v_player);
end; $$;

grant execute on function public.create_player_account(text,text,text,text,text,integer,text,text,text,text,text) to anon,authenticated;
grant execute on function public.login_player(text,text) to anon,authenticated;
grant execute on function public.get_player_session(text) to anon,authenticated;
grant execute on function public.logout_player(text) to anon,authenticated;
grant execute on function public.update_player_profile(text,text,text,text,integer,text,text,text,text,text,text) to anon,authenticated;
