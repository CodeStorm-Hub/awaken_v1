-- Fixes the malformed search_path bug (was `set search_path to 'public,
-- extensions'` — one quoted schema literal, not two entries) and adds
-- server-side anti-cheat validation + idempotency to submit_run().
-- search_path = '' with fully-qualified references removes resolution
-- ambiguity entirely rather than relying on a correctly-formed multi-schema
-- path (Postgres/Supabase best practice for SECURITY DEFINER functions).

create or replace function public.territories_set_area()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.area_sqm = extensions.ST_Area(new.geom::extensions.geography);
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.submit_run(
  p_run_id uuid,
  p_path jsonb, -- GeoJSON LineString: {"type":"LineString","coordinates":[[lng,lat],...]}
  p_started_at timestamptz,
  p_ended_at timestamptz,
  -- Optional per-point capture timestamps, same length/order as the path's
  -- coordinate array. Nullable for backward compatibility with clients
  -- that haven't been updated yet (Phase 1d) — when absent, only the
  -- aggregate average-speed gate below applies, not per-segment checks.
  p_point_timestamps timestamptz[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing record;
  v_path extensions.geometry;
  v_point_count int;
  v_length_m double precision;
  v_is_closed boolean;
  v_new_geom extensions.geometry;
  v_rival record;
  v_diff extensions.geometry;
  v_diff_area double precision;
  v_own_id uuid;
  v_own_geom extensions.geometry;
  v_merged extensions.geometry;
  v_delta_sqm double precision := 0;
  v_i int;
  v_seg_m double precision;
  v_seg_s double precision;
  v_speed double precision;
  v_pt1 extensions.geometry;
  v_pt2 extensions.geometry;
  -- ~10 m/s (36 km/h) — comfortably above elite sustained running pace but
  -- far below vehicle/teleport speeds; used for both per-segment and
  -- average-speed gates.
  v_max_speed_mps constant double precision := 10;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  -- Idempotency: a repeated submission of an already-processed run id
  -- (lost-response retry) returns the stored authoritative result instead
  -- of erroring on the primary-key conflict.
  select * into v_existing from public.runs where id = p_run_id;
  if found then
    if v_existing.user_id <> v_user_id then
      raise exception 'run id belongs to another user';
    end if;
    return jsonb_build_object(
      'accepted', v_existing.integrity_verdict is distinct from 'rejected',
      'closed_loop', v_existing.is_closed_loop,
      'reason', v_existing.rejected_reason,
      'idempotent_replay', true
    );
  end if;

  -- Payload size cap before any geometry parsing work.
  if octet_length(p_path::text) > 1048576 then -- 1 MiB
    raise exception 'path payload too large';
  end if;

  v_path := extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON(p_path::text), 4326);
  if extensions.GeometryType(v_path) <> 'LINESTRING' then
    raise exception 'path must be a LineString';
  end if;

  v_point_count := extensions.ST_NPoints(v_path);
  if v_point_count < 2 or v_point_count > 20000 then
    raise exception 'point count out of bounds';
  end if;

  -- Coordinate bounds sanity — GeoJSON parsing accepts any numeric lng/lat.
  if extensions.ST_XMin(v_path) < -180 or extensions.ST_XMax(v_path) > 180
     or extensions.ST_YMin(v_path) < -90 or extensions.ST_YMax(v_path) > 90 then
    raise exception 'coordinates out of range';
  end if;

  v_length_m := extensions.ST_Length(v_path::extensions.geography);

  -- Per-segment speed/teleport check — only possible when the client sends
  -- per-point timestamps (Phase 1d client work). Older clients skip this
  -- and rely on the aggregate average-speed gate below instead.
  if p_point_timestamps is not null then
    if array_length(p_point_timestamps, 1) <> v_point_count then
      raise exception 'timestamp count does not match point count';
    end if;
    for v_i in 1 .. array_length(p_point_timestamps, 1) - 1 loop
      if p_point_timestamps[v_i + 1] < p_point_timestamps[v_i] then
        raise exception 'point timestamps must be non-decreasing';
      end if;
      v_seg_s := extract(epoch from (p_point_timestamps[v_i + 1] - p_point_timestamps[v_i]));
      v_pt1 := extensions.ST_PointN(v_path, v_i);
      v_pt2 := extensions.ST_PointN(v_path, v_i + 1);
      v_seg_m := extensions.ST_Distance(v_pt1::extensions.geography, v_pt2::extensions.geography);
      if v_seg_s > 0 and (v_seg_m / v_seg_s) > v_max_speed_mps then
        raise exception 'implausible speed detected between points % and %', v_i, v_i + 1;
      end if;
    end loop;
    if p_point_timestamps[1] < p_started_at - interval '5 minutes'
       or p_point_timestamps[array_length(p_point_timestamps, 1)] > p_ended_at + interval '5 minutes' then
      raise exception 'point timestamps outside submitted run window';
    end if;
  end if;

  -- Aggregate sanity gate (duration vs length) — catches teleport-style
  -- submissions even without per-point timestamps.
  if p_ended_at > p_started_at
     and (v_length_m / extract(epoch from (p_ended_at - p_started_at))) > v_max_speed_mps then
    insert into public.runs
      (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
    values
      (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'average speed implausible');
    return jsonb_build_object('accepted', false, 'reason', 'average speed implausible');
  end if;

  if v_length_m < 400 then
    insert into public.runs
      (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
    values
      (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'run too short (<400m)');
    return jsonb_build_object('accepted', false, 'reason', 'run too short');
  end if;

  v_is_closed := extensions.ST_DWithin(extensions.ST_StartPoint(v_path)::extensions.geography, extensions.ST_EndPoint(v_path)::extensions.geography, 30);

  if not v_is_closed then
    insert into public.runs
      (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict)
    values
      (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'trusted');
    return jsonb_build_object('accepted', true, 'closed_loop', false);
  end if;

  v_new_geom := extensions.ST_Multi(
    extensions.ST_CollectionExtract(
      extensions.ST_MakeValid(extensions.ST_MakePolygon(extensions.ST_AddPoint(v_path, extensions.ST_StartPoint(v_path)))),
      3
    )
  );

  insert into public.runs
    (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict)
  values
    (p_run_id, v_user_id, v_path, true, p_started_at, p_ended_at, v_point_count, v_length_m, 'trusted');

  for v_rival in
    select id, geom from public.territories
    where user_id <> v_user_id
      and deleted_at is null
      and extensions.ST_Intersects(geom, v_new_geom)
    for update
  loop
    v_diff := extensions.ST_Multi(extensions.ST_CollectionExtract(extensions.ST_MakeValid(extensions.ST_Difference(v_rival.geom, v_new_geom)), 3));
    v_diff_area := coalesce(extensions.ST_Area(v_diff::extensions.geography), 0);

    if v_diff_area < 25 or v_diff is null or extensions.ST_IsEmpty(v_diff) then
      update public.territories set deleted_at = now() where id = v_rival.id;
    else
      update public.territories set geom = v_diff where id = v_rival.id;
    end if;
  end loop;

  select id, geom into v_own_id, v_own_geom
  from public.territories
  where user_id = v_user_id
    and deleted_at is null
    and extensions.ST_Intersects(geom, v_new_geom)
  limit 1
  for update;

  if v_own_id is not null then
    v_merged := extensions.ST_Multi(extensions.ST_CollectionExtract(extensions.ST_MakeValid(extensions.ST_Union(v_own_geom, v_new_geom)), 3));
    update public.territories set geom = v_merged where id = v_own_id;
    select area_sqm into v_delta_sqm from public.territories where id = v_own_id;
  else
    insert into public.territories (id, user_id, geom)
    values (extensions.gen_random_uuid(), v_user_id, v_new_geom)
    returning area_sqm into v_delta_sqm;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'closed_loop', true,
    'captured_area_sqm', extensions.ST_Area(v_new_geom::extensions.geography),
    'territory_area_sqm', v_delta_sqm
  );
end;
$$;

revoke execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz, timestamptz[]) from public, anon;
grant execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz, timestamptz[]) to authenticated;

-- The old 4-arg overload is now shadowed by the 5-arg version (default
-- null on the 5th param), but drop it explicitly so there's exactly one
-- submit_run signature live.
drop function if exists public.submit_run(uuid, jsonb, timestamptz, timestamptz);
