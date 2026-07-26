-- Fixes two real correctness bugs in submit_run() (session hardening-pass
-- items #12/#13), both in the same code path so fixed together:
--
-- 1. `captured_area_sqm` was the FULL run polygon's area, including any part
--    that overlapped the user's own pre-existing territory — a user
--    re-running a loop they already own would see a reward for land that
--    was never actually new. Now computed as genuinely net-new area:
--    ST_Area(new polygon) minus its overlap with the union of the user's
--    own intersecting territory (before merge).
-- 2. The own-territory merge only looked up ONE intersecting own row
--    (`limit 1`) — if a run bridges two or more previously-disjoint pieces
--    of the user's own territory, only one got merged/updated and the
--    others were left as separate, now-overlapping rows (double-counted in
--    any area sum). Now unions and merges ALL intersecting own rows,
--    keeping one canonical row and soft-deleting the rest (same pattern
--    already used for a shrunk-to-nothing rival row above).
--
-- `v_delta_sqm` is also renamed to `v_territory_area_sqm` — it was always
-- the merged territory's TOTAL area (intentional, matches the client's own
-- `territoryAreaSqm` vs `capturedAreaSqm` distinction), the old name was
-- just misleading, not itself a bug.
--
-- Net-new correctness fixes both downstream consumers of the old (wrong)
-- `v_captured_area_sqm` for free, since they already read that same
-- variable: the bounty bonus (`v_bonus_area_sqm`) and the unclaimed-land
-- leaderboard credit (`v_unclaimed_taken`) both now scale off genuinely new
-- area instead of the full (possibly self-overlapping) run polygon.
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
  v_rival_area double precision;
  v_taken_from_rival double precision;
  v_rival_taken_total double precision := 0;
  v_own_ids uuid[];
  v_own_union extensions.geometry;
  v_merged extensions.geometry;
  v_territory_area_sqm double precision := 0;
  v_captured_area_sqm double precision;
  v_unclaimed_taken double precision;
  v_end_point extensions.geometry;
  v_bounty record;
  v_bounty_multiplier double precision := 1.0;
  v_bonus_area_sqm double precision := 0;
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

  -- Location freshness for nearby_leaderboard() — every accepted run
  -- (closed loop or not) updates it, since even an unclosed run still
  -- establishes where this user was actually running.
  v_end_point := extensions.ST_EndPoint(v_path);
  update public.profiles
  set last_run_location = v_end_point::extensions.geography
  where id = v_user_id;

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

  -- All of the user's own territory rows this run touches, locked and
  -- unioned up front — needed both to compute genuinely net-new area below
  -- and to merge every touched row (not just one) further down. `FOR
  -- UPDATE` can't be combined with an aggregate in the same SELECT, hence
  -- the two-step id-array-then-union.
  select array(
    select id from public.territories
    where user_id = v_user_id
      and deleted_at is null
      and extensions.ST_Intersects(geom, v_new_geom)
    for update
  ) into v_own_ids;

  if array_length(v_own_ids, 1) > 0 then
    select extensions.ST_Union(geom) into v_own_union
    from public.territories
    where id = any(v_own_ids);
  end if;

  -- Net-new captured area: the full run polygon minus whatever part of it
  -- the user already owned. A run entirely over already-owned land reports
  -- (correctly) as 0 new area.
  if v_own_union is not null then
    v_captured_area_sqm := coalesce(
      extensions.ST_Area(extensions.ST_Difference(v_new_geom, v_own_union)::extensions.geography),
      0
    );
  else
    v_captured_area_sqm := extensions.ST_Area(v_new_geom::extensions.geography);
  end if;

  insert into public.runs
    (id, user_id, path, is_closed_loop, started_at, ended_at, point_count, distance_m, integrity_verdict)
  values
    (p_run_id, v_user_id, v_path, true, p_started_at, p_ended_at, v_point_count, v_length_m, 'trusted');

  for v_rival in
    select id, user_id, geom from public.territories
    where user_id <> v_user_id
      and deleted_at is null
      and extensions.ST_Intersects(geom, v_new_geom)
    for update
  loop
    v_rival_area := coalesce(extensions.ST_Area(v_rival.geom::extensions.geography), 0);
    v_diff := extensions.ST_Multi(extensions.ST_CollectionExtract(extensions.ST_MakeValid(extensions.ST_Difference(v_rival.geom, v_new_geom)), 3));
    v_diff_area := coalesce(extensions.ST_Area(v_diff::extensions.geography), 0);
    v_taken_from_rival := greatest(v_rival_area - v_diff_area, 0);
    v_rival_taken_total := v_rival_taken_total + v_taken_from_rival;

    if v_diff_area < 25 or v_diff is null or extensions.ST_IsEmpty(v_diff) then
      update public.territories set deleted_at = now() where id = v_rival.id;
    else
      update public.territories set geom = v_diff where id = v_rival.id;
    end if;

    if v_taken_from_rival > 0 then
      insert into public.territory_captures (winner_id, loser_id, area_taken_sqm)
      values (v_user_id, v_rival.user_id, v_taken_from_rival);
    end if;
  end loop;

  if array_length(v_own_ids, 1) > 0 then
    v_merged := extensions.ST_Multi(extensions.ST_CollectionExtract(extensions.ST_MakeValid(extensions.ST_Union(v_own_union, v_new_geom)), 3));
    -- Keep the first touched row as canonical; fold the rest into it and
    -- soft-delete them, matching the shrunk-rival pattern above — otherwise
    -- a run bridging two disjoint own pieces would leave both rows separately
    -- updated to the same overlapping merged geometry, double-counting area.
    update public.territories
    set geom = v_merged, last_defended_at = now()
    where id = v_own_ids[1];
    if array_length(v_own_ids, 1) > 1 then
      update public.territories
      set deleted_at = now()
      where id = any(v_own_ids[2:array_length(v_own_ids, 1)]);
    end if;
    select area_sqm into v_territory_area_sqm from public.territories where id = v_own_ids[1];
  else
    insert into public.territories (id, user_id, geom, last_defended_at)
    values (extensions.gen_random_uuid(), v_user_id, v_new_geom, now())
    returning area_sqm into v_territory_area_sqm;
  end if;

  -- Unclaimed land taken (not previously any rival's, credited separately
  -- from rival takings) — a rough estimate (net-new captured area minus
  -- whatever was actually removed from rivals), good enough for weekly-
  -- leaderboard credit without needing exact polygon accounting for a
  -- secondary stat.
  v_unclaimed_taken := greatest(v_captured_area_sqm - v_rival_taken_total, 0);
  if v_unclaimed_taken > 0 then
    insert into public.territory_captures (winner_id, loser_id, area_taken_sqm)
    values (v_user_id, null, v_unclaimed_taken);
  end if;

  -- Bounty multiplier: a flat bonus credited on top of the real (net-new)
  -- captured area, never scaling the stored polygon (bounty_zones
  -- migration's own doc comment) — checked against the run's end point
  -- falling inside an active zone's radius.
  select multiplier into v_bounty_multiplier
  from public.bounty_zones
  where active_from <= now() and (active_until is null or active_until > now())
    and extensions.ST_DWithin(center, v_end_point::extensions.geography, radius_m)
  order by multiplier desc
  limit 1;

  if v_bounty_multiplier is not null and v_bounty_multiplier > 1.0 then
    v_bonus_area_sqm := v_captured_area_sqm * (v_bounty_multiplier - 1.0);
  else
    v_bounty_multiplier := 1.0;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'closed_loop', true,
    'captured_area_sqm', v_captured_area_sqm,
    'territory_area_sqm', v_territory_area_sqm,
    'bounty_multiplier', v_bounty_multiplier,
    'bonus_area_sqm', v_bonus_area_sqm
  );
end;
$$;

revoke execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz, timestamptz[]) from public, anon;
grant execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz, timestamptz[]) to authenticated;
