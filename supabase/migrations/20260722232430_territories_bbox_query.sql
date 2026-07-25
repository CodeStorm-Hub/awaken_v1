-- Bbox/viewport spatial query for territories (closes the gap flagged in
-- the territory feature review — territories_geojson previously had no
-- spatial filter, just order-by-updated_at + limit).
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
as $$
  select
    t.id,
    t.user_id,
    t.area_sqm,
    t.updated_at,
    ST_AsGeoJSON(t.geom)::json as geom_geojson
  from public.territories t
  where t.deleted_at is null
    and t.geom && ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
  order by t.updated_at desc
  limit row_limit;
$$;

revoke all on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from public;
grant execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) to authenticated;
revoke execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from anon;
