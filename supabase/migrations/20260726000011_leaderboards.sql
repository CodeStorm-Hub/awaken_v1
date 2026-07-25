-- Leaderboards (refined territory plan, item 4): nearby + global scopes,
-- and a time_window param on squad_leaderboard/global_leaderboard/
-- nearby_leaderboard for the "all_time" (total held area) vs "weekly"
-- (area captured in the trailing 7 days, from territory_captures) split.
--
-- last_run_location is deliberately NOT directly selectable by other users
-- (profiles_select_own stays row-scoped to the caller) — nearby_leaderboard
-- reads it only inside a SECURITY DEFINER function and never returns the
-- raw coordinate, only id/display_name/distance/area, same privacy posture
-- as the rest of the profiles table.

alter table public.profiles
  add column if not exists last_run_location extensions.geography(Point, 4326);

create index if not exists profiles_last_run_location_gix
  on public.profiles using gist (last_run_location);

-- Shared helper: per-user captured area within a time window, used by all
-- three leaderboard functions below.
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
  group by c.winner_id;
$$;

revoke all on function public._area_for_window(text) from public, anon, authenticated;

create or replace function public.squad_leaderboard(p_squad_id uuid, p_time_window text default 'all_time')
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision)
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

  if p_time_window not in ('all_time', 'weekly') then
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
      coalesce(a.area_sqm, 0)::double precision
    from public.profiles p
    left join public._area_for_window(p_time_window) a on a.user_id = p.id
    where p.squad_id = p_squad_id
    order by coalesce(a.area_sqm, 0) desc;
end;
$$;

revoke all on function public.squad_leaderboard(uuid, text) from public, anon;
grant execute on function public.squad_leaderboard(uuid, text) to authenticated;

create or replace function public.global_leaderboard(p_time_window text default 'all_time', p_row_limit integer default 100)
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;

  if p_time_window not in ('all_time', 'weekly') then
    raise exception 'invalid time_window: %', p_time_window;
  end if;

  if p_row_limit < 1 or p_row_limit > 500 then
    raise exception 'row_limit out of range';
  end if;

  return query
    select p.id, p.display_name, p.streak_tier, a.area_sqm
    from public._area_for_window(p_time_window) a
    join public.profiles p on p.id = a.user_id
    where p.deleted_at is null and a.area_sqm > 0
    order by a.area_sqm desc
    limit p_row_limit;
end;
$$;

revoke all on function public.global_leaderboard(text, integer) from public, anon;
grant execute on function public.global_leaderboard(text, integer) to authenticated;

create or replace function public.nearby_leaderboard(p_radius_m numeric default 5000, p_time_window text default 'all_time', p_row_limit integer default 100)
returns table (user_id uuid, display_name text, streak_tier smallint, area_sqm double precision, distance_m double precision)
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

  if p_time_window not in ('all_time', 'weekly') then
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
      extensions.ST_Distance(p.last_run_location, v_origin)
    from public.profiles p
    left join public._area_for_window(p_time_window) a on a.user_id = p.id
    where p.deleted_at is null
      and p.last_run_location is not null
      and extensions.ST_DWithin(p.last_run_location, v_origin, p_radius_m)
    order by coalesce(a.area_sqm, 0) desc
    limit p_row_limit;
end;
$$;

revoke all on function public.nearby_leaderboard(numeric, text, integer) from public, anon;
grant execute on function public.nearby_leaderboard(numeric, text, integer) to authenticated;
