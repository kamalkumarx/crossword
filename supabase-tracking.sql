-- Golden Word Games activity tracking setup.
-- Run this entire file once in Supabase Dashboard > SQL Editor.

create table if not exists public.user_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  ended_at timestamptz,
  active_seconds integer not null default 0 check (active_seconds >= 0),
  user_agent text
);

create table if not exists public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.user_sessions(id) on delete set null,
  game_type text not null check (game_type in ('crossword','wordsearch','sudoku','memory')),
  puzzle_id text not null,
  difficulty text not null check (difficulty in ('easy','medium','hard')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds integer check (duration_seconds >= 0),
  score integer check (score >= 0),
  hints_used integer not null default 0 check (hints_used >= 0),
  completed boolean not null default false
);

create table if not exists public.game_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.user_sessions(id) on delete set null,
  game_session_id uuid references public.game_sessions(id) on delete set null,
  event_type text not null,
  game_type text,
  difficulty text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_sessions_user_started_idx on public.user_sessions(user_id, started_at desc);
create index if not exists game_sessions_user_started_idx on public.game_sessions(user_id, started_at desc);
create index if not exists game_sessions_game_type_idx on public.game_sessions(game_type, difficulty, started_at desc);
create index if not exists game_events_user_created_idx on public.game_events(user_id, created_at desc);
create index if not exists game_events_type_created_idx on public.game_events(event_type, created_at desc);

alter table public.user_sessions enable row level security;
alter table public.game_sessions enable row level security;
alter table public.game_events enable row level security;

revoke all on public.user_sessions from anon, authenticated;
revoke all on public.game_sessions from anon, authenticated;
revoke all on public.game_events from anon, authenticated;
grant select, insert, update on public.user_sessions to authenticated;
grant select, insert, update on public.game_sessions to authenticated;
grant select, insert on public.game_events to authenticated;
grant usage, select on sequence public.game_events_id_seq to authenticated;

drop policy if exists "Users manage own visit sessions" on public.user_sessions;
create policy "Users manage own visit sessions" on public.user_sessions
for all to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage own game sessions" on public.game_sessions;
create policy "Users manage own game sessions" on public.game_sessions
for all to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users read own game events" on public.game_events;
create policy "Users read own game events" on public.game_events
for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users add own game events" on public.game_events;
create policy "Users add own game events" on public.game_events
for insert to authenticated with check ((select auth.uid()) = user_id);

-- Useful owner queries to run in SQL Editor.

-- Daily registered users:
-- select created_at::date as day, count(*) from auth.users group by 1 order by 1 desc;

-- Daily active players and tracked time:
-- select started_at::date as day, count(distinct user_id) as players,
--        round(sum(active_seconds) / 60.0, 1) as active_minutes
-- from public.user_sessions group by 1 order by 1 desc;

-- Games and completion rate:
-- select game_type, difficulty, count(*) as rounds,
--        round(100.0 * avg(completed::int), 1) as completion_percent,
--        round(avg(duration_seconds) filter (where completed), 1) as avg_completion_seconds
-- from public.game_sessions group by game_type, difficulty order by rounds desc;

-- Most active players:
-- select u.email, count(gs.id) as rounds, count(gs.id) filter (where gs.completed) as completed,
--        coalesce(sum(gs.score), 0) as total_score
-- from auth.users u left join public.game_sessions gs on gs.user_id = u.id
-- group by u.id, u.email order by rounds desc limit 100;
