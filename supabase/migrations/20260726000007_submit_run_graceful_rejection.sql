-- Fixes an inconsistency found via live testing: the per-segment
-- speed/teleport check and the timestamp-window check used `raise
-- exception`, unlike the "too short" and "average speed implausible"
-- checks, which gracefully insert a rejected `runs` row and return
-- `{"accepted": false, ...}`. A raised exception aborts the whole RPC call
-- with no row ever inserted -- the client's outbox has no way to
-- distinguish "genuinely rejected, stop retrying" from "transient
-- failure, retry later", so a truly cheated/invalid run would retry
-- forever. Malformed-input checks (bad geometry type, oversized payload,
-- point-count/timestamp-count mismatch) still raise, since those indicate
-- a client bug rather than a legitimate borderline run.

create or replace function public.submit_run(
  p_run_id uuid,
  p_path jsonb,
  p_started_at timestamptz,
  p_ended_at timestamptz,
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
  v_max_speed_mps constant double precision := 10;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

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

  if octet_length(p_path::text) > 1048576 then
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

  if extensions.ST_XMin(v_path) < -180 or extensions.ST_XMax(v_path) > 180
     or extensions.ST_YMin(v_path) < -90 or extensions.ST_YMax(v_path) > 90 then
    raise exception 'coordinates out of range';
  end if;

  v_length_m := extensions.ST_Length(v_path::extensions.geography);

  -- Per-segment speed/teleport check -- now gracefully rejects (matching
  -- the aggregate-speed/too-short checks below) instead of raising.
  if p_point_timestamps is not null then
    if array_length(p_point_timestamps, 1) <> v_point_count then
      raise exception 'timestamp count does not match point count';
    end if;
    for v_i in 1 .. array_length(p_point_timestamps, 1) - 1 loop
      if p_point_timestamps[v_i + 1] < p_point_timestamps[v_i] then
        insert into public.runs
          (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
        values
          (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'point timestamps out of order');
        return jsonb_build_object('accepted', false, 'reason', 'point timestamps out of order');
      end if;
      v_seg_s := extract(epoch from (p_point_timestamps[v_i + 1] - p_point_timestamps[v_i]));
      v_pt1 := extensions.ST_PointN(v_path, v_i);
      v_pt2 := extensions.ST_PointN(v_path, v_i + 1);
      v_seg_m := extensions.ST_Distance(v_pt1::extensions.geography, v_pt2::extensions.geography);
      if v_seg_s > 0 and (v_seg_m / v_seg_s) > v_max_speed_mps then
        insert into public.runs
          (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
        values
          (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'implausible speed between consecutive points');
        return jsonb_build_object('accepted', false, 'reason', 'implausible speed between consecutive points');
      end if;
    end loop;
    if p_point_timestamps[1] < p_started_at - interval '5 minutes'
       or p_point_timestamps[array_length(p_point_timestamps, 1)] > p_ended_at + interval '5 minutes' then
      insert into public.runs
        (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
      values
        (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'point timestamps outside submitted run window');
      return jsonb_build_object('accepted', false, 'reason', 'point timestamps outside submitted run window');
    end if;
  end if;

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
