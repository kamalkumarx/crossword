-- GOLDEN WORD GAMES: ANONYMOUS LANDING TRACKING
-- Run this entire file once in Supabase: SQL Editor -> New query -> Run.

create extension if not exists pgcrypto;

create table if not exists public.website_visitors (
  visitor_key text primary key,
  ip_hash text not null,
  anonymous_id uuid not null,
  profile_id uuid null references public.profiles(id) on delete set null,
  first_landed_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  visit_count bigint not null default 1,
  first_landing_path text,
  last_landing_path text,
  first_referrer text,
  last_referrer text,
  country_code text,
  user_agent text
);

create table if not exists public.website_landings (
  id bigint generated always as identity primary key,
  visitor_key text not null references public.website_visitors(visitor_key) on delete cascade,
  session_id uuid not null unique,
  profile_id uuid null references public.profiles(id) on delete set null,
  landed_at timestamptz not null default now(),
  page_url text,
  landing_path text,
  referrer text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  country_code text,
  user_agent text
);

create index if not exists website_landings_landed_at_idx on public.website_landings(landed_at desc);
create index if not exists website_landings_visitor_idx on public.website_landings(visitor_key, landed_at desc);
create index if not exists website_landings_profile_idx on public.website_landings(profile_id, landed_at desc);
create index if not exists website_landings_campaign_idx on public.website_landings(utm_campaign, landed_at desc);

alter table public.website_visitors enable row level security;
alter table public.website_landings enable row level security;
revoke all on public.website_visitors from anon, authenticated;
revoke all on public.website_landings from anon, authenticated;

create or replace function public.record_website_landing(
  p_visitor_key text,
  p_ip_hash text,
  p_anonymous_id uuid,
  p_session_id uuid,
  p_profile_id uuid default null,
  p_page_url text default null,
  p_landing_path text default null,
  p_referrer text default null,
  p_utm_source text default null,
  p_utm_medium text default null,
  p_utm_campaign text default null,
  p_utm_content text default null,
  p_utm_term text default null,
  p_user_agent text default null,
  p_country_code text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.website_visitors (
    visitor_key, ip_hash, anonymous_id, profile_id, first_landing_path,
    last_landing_path, first_referrer, last_referrer, country_code, user_agent
  ) values (
    p_visitor_key, p_ip_hash, p_anonymous_id, p_profile_id, p_landing_path,
    p_landing_path, p_referrer, p_referrer, p_country_code, p_user_agent
  )
  on conflict (visitor_key) do update set
    profile_id = coalesce(excluded.profile_id, website_visitors.profile_id),
    last_seen_at = now(),
    visit_count = website_visitors.visit_count + 1,
    last_landing_path = excluded.last_landing_path,
    last_referrer = excluded.last_referrer,
    country_code = coalesce(excluded.country_code, website_visitors.country_code),
    user_agent = excluded.user_agent;

  insert into public.website_landings (
    visitor_key, session_id, profile_id, page_url, landing_path, referrer,
    utm_source, utm_medium, utm_campaign, utm_content, utm_term,
    country_code, user_agent
  ) values (
    p_visitor_key, p_session_id, p_profile_id, p_page_url, p_landing_path, p_referrer,
    p_utm_source, p_utm_medium, p_utm_campaign, p_utm_content, p_utm_term,
    p_country_code, p_user_agent
  ) on conflict (session_id) do nothing;
end;
$$;

create or replace function public.link_website_visitor(
  p_visitor_key text,
  p_profile_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_profile_id is null then return; end if;
  update public.website_visitors set profile_id = p_profile_id where visitor_key = p_visitor_key;
  update public.website_landings set profile_id = p_profile_id where visitor_key = p_visitor_key and profile_id is null;
end;
$$;

revoke all on function public.record_website_landing(text,text,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text) from public, anon, authenticated;
revoke all on function public.link_website_visitor(text,uuid) from public, anon, authenticated;
grant execute on function public.record_website_landing(text,text,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text) to service_role;
grant execute on function public.link_website_visitor(text,uuid) to service_role;

create or replace view public.website_visitor_summary as
select
  count(*)::bigint as total_landings,
  count(distinct visitor_key)::bigint as unique_visitors,
  count(distinct visitor_key) filter (where profile_id is not null)::bigint as registered_visitors,
  count(distinct visitor_key) filter (where profile_id is null)::bigint as anonymous_visitors,
  count(*) filter (where coalesce(utm_source,'') <> '')::bigint as campaign_landings,
  min(landed_at) as first_recorded_landing,
  max(landed_at) as latest_landing
from public.website_landings;

-- MASTER REPORT: run this whenever you want the latest totals.
select * from public.website_visitor_summary;

-- DAILY REPORT.
select
  landed_at::date as visit_date,
  count(*) as total_landings,
  count(distinct visitor_key) as unique_visitors,
  count(distinct visitor_key) filter (where profile_id is not null) as registered_visitors,
  count(distinct visitor_key) filter (where profile_id is null) as anonymous_visitors
from public.website_landings
group by landed_at::date
order by visit_date desc;

-- GOOGLE ADS / UTM REPORT.
select
  coalesce(utm_source, 'direct') as source,
  coalesce(utm_campaign, '(none)') as campaign,
  count(*) as landings,
  count(distinct visitor_key) as unique_visitors
from public.website_landings
group by 1, 2
order by landings desc;
