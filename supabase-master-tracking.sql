-- Golden Word Games: canonical profiles + complete activity tracking.
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
-- It keeps existing data, makes public.profiles the single player account table,
-- and connects every visit, game, and event to profiles.id.

create extension if not exists pgcrypto;

-- Convert the older auth-based profiles table into the canonical player table.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'user_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'id'
  ) then
    alter table public.profiles drop constraint if exists profiles_user_id_fkey;
    alter table public.profiles rename column user_id to id;
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  email text not null default '',
  name text not null default '',
  age integer check (age between 18 and 120),
  username text not null,
  phone text not null default '',
  avatar text not null default '🐶',
  address_line1 text not null default '',
  city text not null default '',
  country text not null default 'United States',
  state text not null default '',
  zip_code text not null default '',
  box1 text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists email text not null default '';
alter table public.profiles add column if not exists name text not null default '';
alter table public.profiles add column if not exists age integer;
alter table public.profiles add column if not exists username text not null default '';
alter table public.profiles add column if not exists phone text not null default '';
alter table public.profiles add column if not exists avatar text not null default '🐶';
alter table public.profiles add column if not exists address_line1 text not null default '';
alter table public.profiles add column if not exists city text not null default '';
alter table public.profiles add column if not exists country text not null default 'United States';
alter table public.profiles add column if not exists state text not null default '';
alter table public.profiles add column if not exists zip_code text not null default '';
alter table public.profiles add column if not exists box1 text not null default '';
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- Bring previously collected registrations into the one profiles table.
insert into public.profiles (
  id, username, email, name, phone, age, address_line1, city,
  state, zip_code, country, box1, created_at, updated_at
)
select
  id, username, email_text, name, phone, age, address_line1, city,
  state, zip_code, country, box1, created_at, now()
from public.player_registrations
on conflict (id) do update set
  username = excluded.username,
  email = excluded.email,
  name = excluded.name,
  phone = excluded.phone,
  age = excluded.age,
  address_line1 = excluded.address_line1,
  city = excluded.city,
  state = excluded.state,
  zip_code = excluded.zip_code,
  country = excluded.country,
  box1 = excluded.box1,
  updated_at = now();

-- Visit sessions: one row per browser visit.
create table if not exists public.user_sessions (
  id uuid primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  ended_at timestamptz,
  active_seconds integer not null default 0 check (active_seconds >= 0),
  user_agent text,
  page_url text
);

-- Upgrade older tracking tables from user_id to profile_id.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='user_sessions' and column_name='user_id')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='user_sessions' and column_name='profile_id') then
    alter table public.user_sessions drop constraint if exists user_sessions_user_id_fkey;
    alter table public.user_sessions rename column user_id to profile_id;
  end if;
end $$;
alter table public.user_sessions add column if not exists page_url text;
alter table public.user_sessions drop constraint if exists user_sessions_profile_id_fkey;
alter table public.user_sessions add constraint user_sessions_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade;

create table if not exists public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid references public.user_sessions(id) on delete set null,
  game_type text not null check (game_type in ('crossword','wordsearch','sudoku','memory')),
  puzzle_id text not null,
  difficulty text not null check (difficulty in ('easy','medium','hard')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  score integer check (score >= 0),
  hints_used integer not null default 0 check (hints_used >= 0),
  completed boolean not null default false,
  end_reason text
);

do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='game_sessions' and column_name='user_id')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='game_sessions' and column_name='profile_id') then
    alter table public.game_sessions drop constraint if exists game_sessions_user_id_fkey;
    alter table public.game_sessions rename column user_id to profile_id;
  end if;
end $$;
alter table public.game_sessions add column if not exists ended_at timestamptz;
alter table public.game_sessions add column if not exists end_reason text;
alter table public.game_sessions alter column duration_seconds set default 0;
update public.game_sessions set duration_seconds = 0 where duration_seconds is null;
alter table public.game_sessions alter column duration_seconds set not null;
alter table public.game_sessions drop constraint if exists game_sessions_profile_id_fkey;
alter table public.game_sessions add constraint game_sessions_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade;

create table if not exists public.game_events (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid references public.user_sessions(id) on delete set null,
  game_session_id uuid references public.game_sessions(id) on delete set null,
  event_type text not null,
  game_type text,
  difficulty text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='game_events' and column_name='user_id')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='game_events' and column_name='profile_id') then
    alter table public.game_events drop constraint if exists game_events_user_id_fkey;
    alter table public.game_events rename column user_id to profile_id;
  end if;
end $$;
alter table public.game_events drop constraint if exists game_events_profile_id_fkey;
alter table public.game_events add constraint game_events_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade;

create index if not exists profiles_created_idx on public.profiles(created_at desc);
create index if not exists user_sessions_profile_started_idx on public.user_sessions(profile_id, started_at desc);
create index if not exists game_sessions_profile_started_idx on public.game_sessions(profile_id, started_at desc);
create index if not exists game_sessions_game_difficulty_idx on public.game_sessions(game_type, difficulty, started_at desc);
create index if not exists game_events_profile_created_idx on public.game_events(profile_id, created_at desc);
create index if not exists game_events_type_created_idx on public.game_events(event_type, created_at desc);

-- Browser clients may write tracking data but cannot list everybody's private details.
alter table public.profiles enable row level security;
alter table public.user_sessions enable row level security;
alter table public.game_sessions enable row level security;
alter table public.game_events enable row level security;

drop policy if exists "Public creates profile" on public.profiles;
create policy "Public creates profile" on public.profiles for insert to anon, authenticated with check (true);
drop policy if exists "Public updates profile by id" on public.profiles;
create policy "Public updates profile by id" on public.profiles for update to anon, authenticated using (true) with check (true);

drop policy if exists "Public creates visit" on public.user_sessions;
create policy "Public creates visit" on public.user_sessions for insert to anon, authenticated with check (true);
drop policy if exists "Public updates visit" on public.user_sessions;
create policy "Public updates visit" on public.user_sessions for update to anon, authenticated using (true) with check (true);

drop policy if exists "Public creates game" on public.game_sessions;
create policy "Public creates game" on public.game_sessions for insert to anon, authenticated with check (true);
drop policy if exists "Public updates game" on public.game_sessions;
create policy "Public updates game" on public.game_sessions for update to anon, authenticated using (true) with check (true);

drop policy if exists "Public creates event" on public.game_events;
create policy "Public creates event" on public.game_events for insert to anon, authenticated with check (true);

revoke all on public.profiles, public.user_sessions, public.game_sessions, public.game_events from anon, authenticated;
grant insert, update on public.profiles to anon, authenticated;
grant insert, update on public.user_sessions to anon, authenticated;
grant insert, update on public.game_sessions to anon, authenticated;
grant insert on public.game_events to anon, authenticated;
grant usage, select on sequence public.game_events_id_seq to anon, authenticated;

-- Reliable profile-based tracking API.
-- The website calls these functions instead of writing directly through RLS.
-- Every function first verifies that the supplied profile exists.

create or replace function public.gwg_start_visit(
  p_profile_id uuid,
  p_session_id uuid,
  p_user_agent text default '',
  p_page_url text default ''
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = p_profile_id) then
    return false;
  end if;
  insert into public.user_sessions (
    id, profile_id, started_at, last_active_at, active_seconds, user_agent, page_url
  ) values (
    p_session_id, p_profile_id, now(), now(), 0, left(coalesce(p_user_agent,''),1000), left(coalesce(p_page_url,''),2000)
  ) on conflict (id) do update set
    last_active_at = now(),
    user_agent = excluded.user_agent,
    page_url = excluded.page_url;
  return true;
end;
$$;

create or replace function public.gwg_start_game(
  p_profile_id uuid,
  p_session_id uuid,
  p_game_session_id uuid,
  p_game_type text,
  p_puzzle_id text,
  p_difficulty text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = p_profile_id)
     or p_game_type not in ('crossword','wordsearch','sudoku','memory')
     or p_difficulty not in ('easy','medium','hard') then
    return false;
  end if;
  insert into public.game_sessions (
    id, profile_id, session_id, game_type, puzzle_id, difficulty, started_at,
    duration_seconds, hints_used, completed
  ) values (
    p_game_session_id, p_profile_id, p_session_id, p_game_type,
    left(coalesce(p_puzzle_id,''),100), p_difficulty, now(), 0, 0, false
  ) on conflict (id) do nothing;
  insert into public.game_events (
    profile_id, session_id, game_session_id, event_type,
    game_type, difficulty, event_data
  ) values (
    p_profile_id, p_session_id, p_game_session_id, 'game_started',
    p_game_type, p_difficulty, jsonb_build_object('puzzle_id',p_puzzle_id)
  );
  return true;
end;
$$;

create or replace function public.gwg_heartbeat(
  p_profile_id uuid,
  p_session_id uuid,
  p_active_seconds integer,
  p_game_session_id uuid default null,
  p_game_seconds integer default 0,
  p_hints_used integer default 0
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.user_sessions
  set last_active_at = now(), active_seconds = greatest(active_seconds, greatest(coalesce(p_active_seconds,0),0))
  where id = p_session_id and profile_id = p_profile_id;
  if p_game_session_id is not null then
    update public.game_sessions
    set duration_seconds = greatest(duration_seconds, greatest(coalesce(p_game_seconds,0),0)),
        hints_used = greatest(hints_used, greatest(coalesce(p_hints_used,0),0))
    where id = p_game_session_id and profile_id = p_profile_id;
  end if;
  return found;
end;
$$;

create or replace function public.gwg_finish_game(
  p_profile_id uuid,
  p_game_session_id uuid,
  p_duration_seconds integer,
  p_hints_used integer,
  p_end_reason text,
  p_completed boolean default false,
  p_score integer default null
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.game_sessions
  set ended_at = now(),
      completed_at = case when p_completed then now() else completed_at end,
      duration_seconds = greatest(duration_seconds, greatest(coalesce(p_duration_seconds,0),0)),
      hints_used = greatest(hints_used, greatest(coalesce(p_hints_used,0),0)),
      completed = p_completed,
      score = case when p_score is null then score else greatest(p_score,0) end,
      end_reason = left(coalesce(p_end_reason,''),100)
  where id = p_game_session_id and profile_id = p_profile_id;
  return found;
end;
$$;

create or replace function public.gwg_log_event(
  p_profile_id uuid,
  p_session_id uuid,
  p_game_session_id uuid,
  p_event_type text,
  p_game_type text,
  p_difficulty text,
  p_event_data jsonb default '{}'::jsonb
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = p_profile_id) then
    return false;
  end if;
  insert into public.game_events (
    profile_id, session_id, game_session_id, event_type,
    game_type, difficulty, event_data
  ) values (
    p_profile_id, p_session_id, p_game_session_id,
    left(coalesce(p_event_type,'event'),100), p_game_type, p_difficulty,
    coalesce(p_event_data,'{}'::jsonb)
  );
  return true;
end;
$$;

revoke all on function public.gwg_start_visit(uuid,uuid,text,text) from public;
revoke all on function public.gwg_start_game(uuid,uuid,uuid,text,text,text) from public;
revoke all on function public.gwg_heartbeat(uuid,uuid,integer,uuid,integer,integer) from public;
revoke all on function public.gwg_finish_game(uuid,uuid,integer,integer,text,boolean,integer) from public;
revoke all on function public.gwg_log_event(uuid,uuid,uuid,text,text,text,jsonb) from public;
grant execute on function public.gwg_start_visit(uuid,uuid,text,text) to anon, authenticated;
grant execute on function public.gwg_start_game(uuid,uuid,uuid,text,text,text) to anon, authenticated;
grant execute on function public.gwg_heartbeat(uuid,uuid,integer,uuid,integer,integer) to anon, authenticated;
grant execute on function public.gwg_finish_game(uuid,uuid,integer,integer,text,boolean,integer) to anon, authenticated;
grant execute on function public.gwg_log_event(uuid,uuid,uuid,text,text,text,jsonb) to anon, authenticated;

-- MASTER REPORT: one row per profile with all key totals.
create or replace view public.player_master_report as
with visits as (
  select
    profile_id,
    max(last_active_at) as last_seen_at,
    coalesce(sum(active_seconds), 0)::bigint as website_seconds,
    count(*) as website_visits
  from public.user_sessions
  group by profile_id
), games as (
  select
    profile_id,
    count(*) as games_started,
    count(*) filter (where completed) as games_completed,
    count(*) filter (where game_type='crossword') as crossword_started,
    count(*) filter (where game_type='wordsearch') as wordsearch_started,
    count(*) filter (where game_type='sudoku') as sudoku_started,
    count(*) filter (where game_type='memory') as memory_started,
    count(*) filter (where difficulty='easy') as easy_games,
    count(*) filter (where difficulty='medium') as medium_games,
    count(*) filter (where difficulty='hard') as hard_games,
    coalesce(sum(duration_seconds), 0)::bigint as gameplay_seconds,
    coalesce(sum(hints_used), 0)::bigint as hints_used,
    coalesce(sum(score), 0)::bigint as total_score,
    max(score) as best_score
  from public.game_sessions
  group by profile_id
)
select
  p.id as profile_id,
  p.username,
  p.name,
  p.email,
  p.phone,
  p.age,
  p.city,
  p.state,
  p.country,
  p.created_at as account_created_at,
  v.last_seen_at,
  coalesce(v.website_seconds, 0) as website_seconds,
  round(coalesce(v.website_seconds, 0) / 60.0, 1) as website_minutes,
  coalesce(v.website_visits, 0) as website_visits,
  coalesce(g.games_started, 0) as games_started,
  coalesce(g.games_completed, 0) as games_completed,
  coalesce(g.crossword_started, 0) as crossword_started,
  coalesce(g.wordsearch_started, 0) as wordsearch_started,
  coalesce(g.sudoku_started, 0) as sudoku_started,
  coalesce(g.memory_started, 0) as memory_started,
  coalesce(g.easy_games, 0) as easy_games,
  coalesce(g.medium_games, 0) as medium_games,
  coalesce(g.hard_games, 0) as hard_games,
  coalesce(g.gameplay_seconds, 0) as gameplay_seconds,
  coalesce(g.hints_used, 0) as hints_used,
  coalesce(g.total_score, 0) as total_score,
  g.best_score
from public.profiles p
left join visits v on v.profile_id = p.id
left join games g on g.profile_id = p.id;

revoke all on public.player_master_report from anon, authenticated;

-- After running this file, use this in SQL Editor any time:
-- select * from public.player_master_report order by last_seen_at desc nulls last;

-- Detailed game breakdown:
-- select p.username, gs.game_type, gs.difficulty,
--        count(*) as games_started,
--        count(*) filter (where gs.completed) as completed,
--        round(avg(gs.duration_seconds)) as avg_seconds,
--        sum(gs.score) as total_score
-- from public.game_sessions gs
-- join public.profiles p on p.id = gs.profile_id
-- group by p.username, gs.game_type, gs.difficulty
-- order by p.username, games_started desc;
