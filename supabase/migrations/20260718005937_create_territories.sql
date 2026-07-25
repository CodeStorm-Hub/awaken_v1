create table public.territories (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- MultiPolygon, not Polygon: ST_Difference can split a territory into
  -- disjoint pieces when a rival captures part of it (plan §3 C4).
  geom geometry(MultiPolygon, 4326) not null,
  -- computed via trigger from geom::geography — never client-supplied.
  area_sqm double precision not null default 0,
  health smallint not null default 100 check (health between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index territories_user_id_idx on public.territories(user_id) where deleted_at is null;
create index territories_geom_gix on public.territories using gist(geom);

alter table public.territories enable row level security;

-- Territories are public read (everyone sees the map); mutation is
-- exclusively via the submit_run() SECURITY DEFINER RPC (plan §3).
create policy "territories_select_all" on public.territories
  for select using (true);

create or replace function public.territories_set_area()
returns trigger
language plpgsql
as $$
begin
  new.area_sqm = ST_Area(new.geom::geography);
  new.updated_at = now();
  return new;
end;
$$;

create trigger territories_set_area_trigger
  before insert or update on public.territories
  for each row execute function public.territories_set_area();
