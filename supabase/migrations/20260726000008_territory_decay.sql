-- Territory decay (refined territory plan, item 1): a territory not
-- defended (created or re-captured) for a fixed inactivity period reverts
-- to unclaimed. `last_defended_at` is distinct from `updated_at` (which the
-- area-recompute trigger also touches for unrelated reasons, e.g. a rival
-- subtracting from this row) — only submit_run()'s own-territory
-- create/merge branch advances it.

alter table public.territories
  add column if not exists last_defended_at timestamptz not null default now();

-- Backfill: best available proxy for existing rows is updated_at.
update public.territories set last_defended_at = updated_at where last_defended_at = created_at;

create index if not exists territories_last_defended_at_idx
  on public.territories (last_defended_at)
  where deleted_at is null;

create extension if not exists pg_cron schema cron;

-- Runs as postgres (cron jobs execute with the privileges of the role that
-- scheduled them); SECURITY DEFINER not needed here since it's not called
-- via the client API surface at all.
create or replace function public.expire_decayed_territories()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.territories
  set deleted_at = now()
  where deleted_at is null
    and last_defended_at < now() - interval '7 days';
end;
$$;

revoke all on function public.expire_decayed_territories() from public, anon, authenticated;

select cron.schedule(
  'expire-decayed-territories',
  '0 3 * * *', -- daily at 03:00 UTC
  $$select public.expire_decayed_territories();$$
);

-- Read-only helper so the client can show an "at risk" warning before
-- actual expiry, without a separate stored decay-state column (computed
-- on read, per the plan's simplification note). 2-day warning window
-- before the 7-day hard expiry above.
create or replace function public.my_territories_at_risk()
returns table (id uuid, area_sqm double precision, last_defended_at timestamptz, expires_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$
  select t.id, t.area_sqm, t.last_defended_at, t.last_defended_at + interval '7 days' as expires_at
  from public.territories t
  where t.user_id = (select auth.uid())
    and t.deleted_at is null
    and t.last_defended_at < now() - interval '5 days';
$$;

revoke all on function public.my_territories_at_risk() from public, anon;
grant execute on function public.my_territories_at_risk() to authenticated;
