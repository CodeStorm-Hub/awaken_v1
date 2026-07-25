-- Server-authoritative territory pipeline (plan §3 "Territory pipeline").
-- Clients never write public.territories directly (no INSERT/UPDATE policy
-- exists on that table) — this SECURITY DEFINER RPC is the only path.
create or replace function public.submit_run(
  p_run_id uuid,
  p_path jsonb, -- GeoJSON LineString: {"type":"LineString","coordinates":[[lng,lat],...]}
  p_started_at timestamptz,
  p_ended_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_path geometry;
  v_point_count int;
  v_length_m double precision;
  v_is_closed boolean;
  v_new_geom geometry;      -- MultiPolygon captured by this run
  v_rival record;
  v_diff geometry;
  v_diff_area double precision;
  v_own_id uuid;
  v_own_geom geometry;
  v_merged geometry;
  v_delta_sqm double precision := 0;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  v_path := ST_SetSRID(ST_GeomFromGeoJSON(p_path::text), 4326);
  if GeometryType(v_path) <> 'LINESTRING' then
    raise exception 'path must be a LineString';
  end if;

  v_point_count := ST_NPoints(v_path);
  v_length_m := ST_Length(v_path::geography);

  -- Aggregate sanity gates (plan §3 step 2). Per-segment velocity/teleport
  -- checks are a documented follow-up (plan H7) — not required to land the
  -- schema/pipeline skeleton.
  if v_length_m < 400 then
    insert into public.runs
      (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict, rejected_reason)
    values
      (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'rejected', 'run too short (<400m)');
    return jsonb_build_object('accepted', false, 'reason', 'run too short');
  end if;

  v_is_closed := ST_DWithin(ST_StartPoint(v_path)::geography, ST_EndPoint(v_path)::geography, 30);

  if not v_is_closed then
    insert into public.runs
      (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict)
    values
      (p_run_id, v_user_id, v_path, false, p_started_at, p_ended_at, v_point_count, v_length_m, 'trusted');
    return jsonb_build_object('accepted', true, 'closed_loop', false);
  end if;

  -- Polygonize (plan §3 step 3): ST_MakeValid, not the deprecated
  -- ST_Buffer(geom, 0) trick (plan §2.3 moderate).
  v_new_geom := ST_Multi(
    ST_CollectionExtract(
      ST_MakeValid(ST_MakePolygon(ST_AddPoint(v_path, ST_StartPoint(v_path)))),
      3
    )
  );

  insert into public.runs
    (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict)
  values
    (p_run_id, v_user_id, v_path, true, p_started_at, p_ended_at, v_point_count, v_length_m, 'trusted');

  -- Conflict resolution (plan §3 step 4): subtract from intersecting rival
  -- territories; drop rivals whose remaining area falls below a floor.
  for v_rival in
    select id, geom from public.territories
    where user_id <> v_user_id
      and deleted_at is null
      and ST_Intersects(geom, v_new_geom)
    for update
  loop
    v_diff := ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Difference(v_rival.geom, v_new_geom)), 3));
    v_diff_area := coalesce(ST_Area(v_diff::geography), 0);

    if v_diff_area < 25 or v_diff is null or ST_IsEmpty(v_diff) then
      update public.territories set deleted_at = now() where id = v_rival.id;
    else
      update public.territories set geom = v_diff where id = v_rival.id;
    end if;
  end loop;

  -- Merge into (or create) the capturing user's own territory.
  select id, geom into v_own_id, v_own_geom
  from public.territories
  where user_id = v_user_id
    and deleted_at is null
    and ST_Intersects(geom, v_new_geom)
  limit 1
  for update;

  if v_own_id is not null then
    v_merged := ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Union(v_own_geom, v_new_geom)), 3));
    update public.territories set geom = v_merged where id = v_own_id;
    select area_sqm into v_delta_sqm from public.territories where id = v_own_id;
  else
    insert into public.territories (id, user_id, geom)
    values (gen_random_uuid(), v_user_id, v_new_geom)
    returning area_sqm into v_delta_sqm;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'closed_loop', true,
    'captured_area_sqm', ST_Area(v_new_geom::geography),
    'territory_area_sqm', v_delta_sqm
  );
end;
$$;

revoke all on function public.submit_run(uuid, jsonb, timestamptz, timestamptz) from public;
grant execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz) to authenticated;
