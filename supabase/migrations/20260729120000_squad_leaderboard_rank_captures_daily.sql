-- Squad page UI/UX audit (2026-07-29) follow-ups:
--
-- 1. `daily` time window — the audit's leaderboard sheet redesign adds a
--    daily/weekly/all-time segmented control, but `_area_for_window` and its
--    three callers (squad_leaderboard/global_leaderboard/nearby_leaderboard)
--    only ever recognized 'all_time'/'weekly'. Adds a third branch (trailing
--    24h from territory_captures, same source table as 'weekly') and widens
--    every check constraint.
-- 2. `my_global_rank`/`my_nearby_rank` — the leaderboard sheet's "You: #N"
--    pinned row needs the caller's own rank as a targeted query, not a full
--    client-side scan of a page-limited list. Mirrors the ordering each
--    existing leaderboard RPC already uses.
-- 3. `recent_territory_captures` — the new "conquest ticker" activity feed
--    needs a cross-user read of `territory_captures`, but that table's RLS
--    (`territory_captures_select_own`) only lets a user see rows they were
--    a party to. Exposes only display_name/area/created_at (never location),
--    same public-aggregate posture `global_leaderboard` already established
--    for `territories`/`profiles`.
--
-- NOTE (applied as `squad_leaderboard_rank_captures_daily_v2`): the first
-- draft of this migration redefined squad_leaderboard/global_leaderboard/
-- nearby_leaderboard without `avatar_url`, which `squad_repository_impl.
-- dart`'s `_mapLeaderboardRows` reads for every leaderboard row's avatar —
-- caught before it reached the live project; `avatar_url` is preserved in
-- all three return shapes below via an explicit `drop function` (the column
-- addition otherwise fails with 42P13, Postgres won't widen a RETURNS TABLE
-- shape via CREATE OR REPLACE).

create or replace function public._area_for_window(p_time_window text)
returns table (user_id uuid, area_sqm double precision)
language sql
stable
security definer
set search_path = ''
as $$
  select t.user_id, coalesce(sum(t.area_sqm), 0)::double precision
  from public.territories t
  where p_time_window = 'all_time' and t.deleted_at is null
  group by t.user_id

  union all

  select c.winner_id, coalesce(sum(c.area_taken_sqm), 0)::double precision
  from public.territory_captures c
  where p_time_window = 'weekly' and c.created_at >= now() - interval '7 days'
  group by c.winner_id

  union all

  select c.winner_id, coalesce(sum(c.area_taken_sqm), 0)::double precision
  from public.territory_captures c
  where p_time_window = 'daily' and c.created_at >= now() - interval '1 day'
  group by c.winner_id;
$$;

drop function if exists public.squad_leaderboard(uuid, text);
create function public.squad_leaderboard(p_squad_id uuid, p_time_window text default 'all_time')
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision, avatar_url text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly', 'daily') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  if not exists (select 1 from public.profiles where id = v_uid and squad_id = p_squad_id) then
    raise exception 'not a member of this squad';
  end if;

  return query
    select
      p.id,
      p.display_name,
      p.streak_tier,
      coalesce(a.area_sqm, 0)::double precision,
      p.avatar_url
    from public.profiles p
    left join public._area_for_window(p_time_window) a on a.user_id = p.id
    where p.squad_id = p_squad_id
    order by coalesce(a.area_sqm, 0) desc;
end;
$$;

drop function if exists public.global_leaderboard(text, integer);
create function public.global_leaderboard(p_time_window text default 'all_time', p_row_limit integer default 100)
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision, avatar_url text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly', 'daily') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  if p_row_limit < 1 or p_row_limit > 500 then
    raise exception 'row_limit out of range';
  end if;

  return query
    select p.id, p.display_name, p.streak_tier, a.area_sqm, p.avatar_url
    from public._area_for_window(p_time_window) a
    join public.profiles p on p.id = a.user_id
    where p.deleted_at is null and a.area_sqm > 0
    order by a.area_sqm desc
    limit p_row_limit;
end;
$$;

drop function if exists public.nearby_leaderboard(numeric, text, integer);
create function public.nearby_leaderboard(p_radius_m numeric default 5000, p_time_window text default 'all_time', p_row_limit integer default 100)
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision, distance_m double precision, avatar_url text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_origin extensions.geography;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly', 'daily') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  if p_radius_m <= 0 or p_radius_m > 100000 then
    raise exception 'radius_m out of range';
  end if;

  if p_row_limit < 1 or p_row_limit > 500 then
    raise exception 'row_limit out of range';
  end if;

  select last_run_location into v_origin from public.profiles where id = v_uid;
  if v_origin is null then
    return;
  end if;

  return query
    select
      p.id,
      p.display_name,
      p.streak_tier,
      coalesce(a.area_sqm, 0)::double precision,
      extensions.ST_Distance(p.last_run_location, v_origin),
      p.avatar_url
    from public.profiles p
    left join public._area_for_window(p_time_window) a on a.user_id = p.id
    where p.deleted_at is null
      and p.last_run_location is not null
      and extensions.ST_DWithin(p.last_run_location, v_origin, p_radius_m)
    order by coalesce(a.area_sqm, 0) desc
    limit p_row_limit;
end;
$$;

-- Caller's own rank in the global leaderboard's ordering — null if the
-- caller has captured no area (not on the board at all), same "area_sqm > 0"
-- gate `global_leaderboard` uses.
create or replace function public.my_global_rank(p_time_window text default 'all_time')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_rank integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly', 'daily') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  select ranked.rank into v_rank
  from (
    select
      p.id as user_id,
      row_number() over (order by a.area_sqm desc) as rank
    from public._area_for_window(p_time_window) a
    join public.profiles p on p.id = a.user_id
    where p.deleted_at is null and a.area_sqm > 0
  ) ranked
  where ranked.user_id = v_uid;

  return v_rank;
end;
$$;

revoke all on function public.my_global_rank(text) from public, anon;
grant execute on function public.my_global_rank(text) to authenticated;

-- Caller's own rank within `nearby_leaderboard`'s radius/ordering — null if
-- the caller has no `last_run_location` yet (same early-return gate
-- `nearby_leaderboard` uses).
create or replace function public.my_nearby_rank(p_radius_m numeric default 5000, p_time_window text default 'all_time')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_origin extensions.geography;
  v_rank integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly', 'daily') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  if p_radius_m <= 0 or p_radius_m > 100000 then
    raise exception 'radius_m out of range';
  end if;

  select last_run_location into v_origin from public.profiles where id = v_uid;
  if v_origin is null then
    return null;
  end if;

  select ranked.rank into v_rank
  from (
    select
      p.id as user_id,
      row_number() over (order by coalesce(a.area_sqm, 0) desc) as rank
    from public.profiles p
    left join public._area_for_window(p_time_window) a on a.user_id = p.id
    where p.deleted_at is null
      and p.last_run_location is not null
      and extensions.ST_DWithin(p.last_run_location, v_origin, p_radius_m)
  ) ranked
  where ranked.user_id = v_uid;

  return v_rank;
end;
$$;

revoke all on function public.my_nearby_rank(numeric, text) from public, anon;
grant execute on function public.my_nearby_rank(numeric, text) to authenticated;

-- "Conquest ticker" feed — recent captures across all users, joined to
-- display names. Deliberately excludes any location/geometry column; the
-- same public-aggregate posture as global_leaderboard (no client-writable
-- policy is added here, this is read-only via a SECURITY DEFINER function).
create or replace function public.recent_territory_captures(p_row_limit integer default 10)
returns table (
  capture_id uuid,
  winner_id uuid,
  winner_display_name text,
  loser_id uuid,
  loser_display_name text,
  area_taken_sqm double precision,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;

  if p_row_limit < 1 or p_row_limit > 50 then
    raise exception 'row_limit out of range';
  end if;

  return query
    select
      c.id,
      pw.id,
      pw.display_name,
      pl.id,
      pl.display_name,
      c.area_taken_sqm,
      c.created_at
    from public.territory_captures c
    join public.profiles pw on pw.id = c.winner_id
    left join public.profiles pl on pl.id = c.loser_id
    where pw.deleted_at is null
    order by c.created_at desc
    limit p_row_limit;
end;
$$;

revoke all on function public.recent_territory_captures(integer) from public, anon;
grant execute on function public.recent_territory_captures(integer) to authenticated;
