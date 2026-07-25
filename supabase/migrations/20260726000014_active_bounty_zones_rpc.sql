-- Explicit lat/lng RPC for bounty zones — avoids relying on PostgREST's
-- geography-column serialization (raw WKB vs GeoJSON is ambiguous without
-- an explicit cast), matching the same pattern territories_in_bbox already
-- uses for its geom_geojson column.
create or replace function public.active_bounty_zones()
returns table (id uuid, center_lat double precision, center_lng double precision, radius_m numeric, multiplier numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select b.id, extensions.ST_Y(b.center::extensions.geometry), extensions.ST_X(b.center::extensions.geometry),
         b.radius_m, b.multiplier
  from public.bounty_zones b
  where b.active_from <= now() and (b.active_until is null or b.active_until > now());
$$;

revoke all on function public.active_bounty_zones() from public, anon;
grant execute on function public.active_bounty_zones() to authenticated;
