-- Attempt 4: fully qualify the 5 DECLARE-block variable types
-- (extensions.geometry) since those resolve immediately at CREATE
-- FUNCTION time, unlike the function body's ST_*/::geography references,
-- which resolve lazily at first execution via the function's own
-- `SET search_path` clause (which does work for those, per attempt 3's
-- partial success getting past territories_set_area cleanly).
--
-- KNOWN BUG (see 20260722232548 and the codebase review that flagged it):
-- the `set search_path to 'public, extensions'` clauses below are a single
-- quoted string, not two schema entries — Postgres treats it as one
-- (nonexistent) schema literally named "public, extensions". This was
-- fixed properly for territories_in_bbox in a later migration but never
-- backported here. Left as-is in this file to accurately reflect what was
-- actually deployed; see the follow-up migration that fixes both
-- submit_run() and territories_set_area() with `search_path = ''` and
-- fully-qualified references instead.

drop trigger if exists territories_set_area_trigger on public.territories;
drop function if exists public.territories_set_area();

drop extension if exists postgis cascade;

create extension if not exists postgis schema extensions;

alter table public.runs
  add column if not exists path extensions.geometry(LineString, 4326) not null;

alter table public.territories
  add column if not exists geom extensions.geometry(MultiPolygon, 4326) not null;

create index if not exists runs_path_gix on public.runs using gist (path);
create index if not exists territories_geom_gix on public.territories using gist (geom);

create or replace function public.territories_set_area()
returns trigger
language plpgsql
set search_path to 'public, extensions'
as $function$
begin
  new.area_sqm = ST_Area(new.geom::geography);
  new.updated_at = now();
  return new;
end;
$function$;

create trigger territories_set_area_trigger
  before insert or update on public.territories
  for each row execute function public.territories_set_area();

create or replace function public.submit_run(p_run_id uuid, p_path jsonb, p_started_at timestamptz, p_ended_at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path to 'public, extensions'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_path extensions.geometry;
  v_point_count int;
  v_length_m double precision;
  v_is_closed boolean;
  v_new_geom extensions.geometry;      -- MultiPolygon captured by this run
  v_rival record;
  v_diff extensions.geometry;
  v_diff_area double precision;
  v_own_id uuid;
  v_own_geom extensions.geometry;
  v_merged extensions.geometry;
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
$function$;

revoke execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz) from public, anon;
