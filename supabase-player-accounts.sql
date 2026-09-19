-- Golden Word Games: simple profile collection only.
-- No authentication, password, OTP, or email verification is used.
-- Run this complete file in Supabase -> SQL Editor -> New query -> Run.

create table if not exists public.player_registrations (
  id uuid primary key,
  username text not null,
  email_text text not null default '',
  name text not null default '',
  phone text not null default '',
  age integer check (age between 18 and 120),
  address_line1 text not null default '',
  city text not null default '',
  state text not null default '',
  zip_code text not null default '',
  country text not null default 'United States',
  created_at timestamptz not null default now()
);

alter table public.player_registrations enable row level security;
drop policy if exists "Anyone can create a player ID" on public.player_registrations;
create policy "Anyone can create a player ID" on public.player_registrations
for insert to anon, authenticated with check (true);
revoke all on public.player_registrations from anon, authenticated;
grant insert on public.player_registrations to anon, authenticated;
