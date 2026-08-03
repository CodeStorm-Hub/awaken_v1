-- Bounty zones (refined territory plan, item 2). A flat multiplier per
-- zone (not a range) applied to a separate bonus_area_sqm credited on
-- capture — never scales the actual stored polygon, which would falsify
-- the map.

create table public.bounty_zones (
  id uuid primary key default extensions.gen_random_uuid(),
  center extensions.geography(Point, 4326) not null,
  radius_m numeric not null check (radius_m > 0),
  multiplier numeric not null default 2.0 check (multiplier > 1.0),
  active_from timestamptz not null default now(),
  active_until timestamptz, -- null = indefinite
  created_at timestamptz not null default now()
);

create index bounty_zones_center_gix on public.bounty_zones using gist (center);
create index bounty_zones_active_idx on public.bounty_zones (active_from, active_until);

alter table public.bounty_zones enable row level security;

-- Public read of currently-active zones only; no client write at all —
-- zones are seeded/rotated by an operator (table editor or a future admin
-- RPC), same posture as territories' server-only mutation.
create policy "bounty_zones_select_active" on public.bounty_zones
  for select
  using (active_from <= now() and (active_until is null or active_until > now()));

revoke insert, update, delete on public.bounty_zones from anon, authenticated;
