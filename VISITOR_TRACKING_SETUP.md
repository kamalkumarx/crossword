# Visitor tracking setup

The website code and Netlify Function are already prepared. Complete these two dashboard steps once.

## 1. Create the Supabase tables

1. Open Supabase.
2. Select the Golden Word Games project.
3. Open **SQL Editor**.
4. Select **New query**.
5. Paste the complete contents of `supabase-visitor-tracking.sql`.
6. Select **Run**.

## 2. Add protected Netlify environment variables

Open **Netlify -> Golden Word Games -> Project configuration -> Environment variables** and add:

- `SUPABASE_URL`: `https://psmkyenatcpfcsohilkc.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY`: copy the service-role secret from **Supabase -> Project Settings -> API Keys**.
- `VISITOR_HASH_SALT`: enter a private random string of at least 32 characters.

Keep the service-role key and hash salt private. Never add them to GitHub or browser JavaScript.

After adding the variables, trigger a new Netlify deployment.

## Quick reporting query

```sql
select * from public.website_visitor_summary;
```

## Detailed recent visitors

```sql
select
  wl.landed_at,
  wl.visitor_key,
  wl.profile_id,
  p.username,
  wl.landing_path,
  wl.referrer,
  wl.utm_source,
  wl.utm_campaign,
  wl.country_code
from public.website_landings wl
left join public.profiles p on p.id = wl.profile_id
order by wl.landed_at desc
limit 500;
```
