-- Hardening-pass item #14: `territories_in_bbox()` had no server-side hard
-- row-count cap (a caller-supplied `row_limit` was passed straight into
-- `limit` with only a client-side default of 500, not a server-enforced
-- ceiling) and no coordinate-bounds validation at all. Converted from
-- `language sql` to `language plpgsql` to allow the same `raise exception`
-- pattern already used for bounds checks in `submit_run()`, for consistency.
--
-- `min_lng > max_lng` is deliberately NOT rejected — that's the existing
-- antimeridian-wraparound case (already handled by the `case` branch below),
-- not a malformed input.
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
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_row_limit integer;
begin
  if min_lat < -90 or max_lat > 90 or min_lat > max_lat then
    raise exception 'invalid latitude bounds';
  end if;
  if min_lng < -180 or min_lng > 180 or max_lng < -180 or max_lng > 180 then
    raise exception 'invalid longitude bounds';
  end if;

  -- Hard cap regardless of caller-supplied row_limit — an unbounded or
  -- absurdly large value would otherwise let a single call scan/return the
  -- entire table.
  v_row_limit := greatest(1, least(coalesce(row_limit, 500), 500));

  return query
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
  limit v_row_limit;
end;
$$;

revoke all on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from public;
grant execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) to authenticated;
revoke execute on function public.territories_in_bbox(double precision, double precision, double precision, double precision, integer) from anon;
