create or replace view public.territories_geojson
with (security_invoker = true) as
select
  id,
  user_id,
  area_sqm,
  health,
  updated_at,
  extensions.ST_AsGeoJSON(geom)::json as geom_geojson
from public.territories
where deleted_at is null;

grant select on public.territories_geojson to authenticated, anon;
