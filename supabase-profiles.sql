-- Golden Word Games player profiles
-- Run this entire file once in Supabase: SQL Editor -> New query -> Run.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text not null default '',
  age integer check (age between 18 and 120),
  username text not null default '',
  phone text not null default '',
  avatar text not null default '🐶',
  address_line1 text not null default '',
  city text not null default '',
  country text not null default 'United States',
  state text not null default '',
  zip_code text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Safe upgrade for anyone who already ran an older version of this file.
alter table public.profiles add column if not exists name text not null default '';
alter table public.profiles add column if not exists age integer;
alter table public.profiles add column if not exists city text not null default '';

alter table public.profiles enable row level security;

drop policy if exists "Players can read their profile" on public.profiles;
create policy "Players can read their profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Players can create their profile" on public.profiles;
create policy "Players can create their profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Players can update their profile" on public.profiles;
create policy "Players can update their profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, insert, update on public.profiles to authenticated;

create or replace function public.gwg_create_player_profile()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (
    user_id, email, name, age, username, phone, avatar,
    address_line1, city, country, state, zip_code
  ) values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'age', '')::integer,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(coalesce(new.email, 'player'), '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar', '🐶'),
    coalesce(new.raw_user_meta_data ->> 'address_line1', new.raw_user_meta_data ->> 'address', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    coalesce(new.raw_user_meta_data ->> 'country', 'United States'),
    coalesce(new.raw_user_meta_data ->> 'state', ''),
    coalesce(new.raw_user_meta_data ->> 'zip_code', '')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists gwg_on_auth_user_created on auth.users;
create trigger gwg_on_auth_user_created
after insert on auth.users
for each row execute procedure public.gwg_create_player_profile();

insert into public.profiles (
  user_id, email, name, age, username, phone, avatar,
  address_line1, city, country, state, zip_code
)
select
  id,
  coalesce(email, ''),
  coalesce(raw_user_meta_data ->> 'name', raw_user_meta_data ->> 'full_name', ''),
  nullif(raw_user_meta_data ->> 'age', '')::integer,
  coalesce(raw_user_meta_data ->> 'username', split_part(coalesce(email, 'player'), '@', 1)),
  coalesce(raw_user_meta_data ->> 'phone', ''),
  coalesce(raw_user_meta_data ->> 'avatar', '🐶'),
  coalesce(raw_user_meta_data ->> 'address_line1', raw_user_meta_data ->> 'address', ''),
  coalesce(raw_user_meta_data ->> 'city', ''),
  coalesce(raw_user_meta_data ->> 'country', 'United States'),
  coalesce(raw_user_meta_data ->> 'state', ''),
  coalesce(raw_user_meta_data ->> 'zip_code', '')
from auth.users
on conflict (user_id) do nothing;
