-- Antimeridian-safe bbox query (Phase 3 finding). `MapLibreMapController
-- .getVisibleRegion()` returns `southwest.longitude > northeast.longitude`
-- when the viewport straddles ±180° (e.g. viewing the Pacific/Fiji) — a
-- single `ST_MakeEnvelope(min_lng, ..., max_lng, ...)` with min > max
-- either errors or silently matches nothing, since PostGIS doesn't
-- interpret that as "wrap around". When wraparound is detected, this
-- unions two envelopes (min_lng..180 and -180..max_lng) instead of one.
-- Also re-pins `search_path = ''` with fully-qualified references (the
-- `alter function ... set search_path` from a prior migration doesn't
-- survive a `create or replace`).
create or replace function public.territories_in_bbox(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision,
  row_limit integer default 500
)
returns table (
  id uuid,
  user_id uuid,
  area_sqm double precision,
  updated_at timestamptz,
  geom_geojson json
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    t.id,
    t.user_id,
    t.area_sqm,
    t.updated_at,
    extensions.ST_AsGeoJSON(t.geom)::json as geom_geojson
  from public.territories t
  where t.deleted_at is null
    and (
      case
        when min_lng <= max_lng then
          t.geom OPERATOR(extensions.&&) extensions.ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
        else
          t.geom OPERATOR(extensions.&&) extensions.ST_MakeEnvelope(min_lng, min_lat, 180, max_lat, 4326)
          or t.geom OPERATOR(extensions.&&) extensions.ST_MakeEnvelope(-180, min_lat, max_lng, max_lat, 4326)
      end
    )
  order by t.updated_at desc
  limit row_limit;
$$;

revoke all on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from public;
grant execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) to authenticated;
revoke execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from anon;
