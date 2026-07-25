-- Phase 6: Squad & social
-- 1. squads table (one squad per user via profiles.squad_id)
create table public.squads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  owner_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.squads enable row level security;

-- 2. one-squad-per-user FK on profiles (must exist before the RLS policy
-- below, which reads it)
alter table public.profiles add column squad_id uuid references public.squads(id);

-- 3. Members can read their own squad's row; no public browsing/listing.
-- No client INSERT/UPDATE policy — mutated only via the SECURITY DEFINER
-- RPCs below, same posture as `territories`.
create policy squads_select_member on public.squads
  for select
  using (id = (select squad_id from public.profiles where id = (select auth.uid())));

-- 4. create_squad: creates a squad, assigns the caller as owner+member
create or replace function public.create_squad(p_name text)
returns public.squads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text;
  v_exists boolean;
  v_squad public.squads;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.profiles where id = v_uid and squad_id is not null) then
    raise exception 'already in a squad';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'squad name required';
  end if;

  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    select exists(select 1 from public.squads where invite_code = v_code) into v_exists;
    exit when not v_exists;
  end loop;

  insert into public.squads (name, invite_code, owner_id)
  values (trim(p_name), v_code, v_uid)
  returning * into v_squad;

  update public.profiles set squad_id = v_squad.id, updated_at = now() where id = v_uid;

  return v_squad;
end;
$$;

revoke all on function public.create_squad(text) from public;
grant execute on function public.create_squad(text) to authenticated;

-- 5. join_squad: looks up by invite code, assigns the caller as member
create or replace function public.join_squad(p_invite_code text)
returns public.squads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_squad public.squads;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.profiles where id = v_uid and squad_id is not null) then
    raise exception 'already in a squad';
  end if;

  select * into v_squad from public.squads where invite_code = upper(trim(p_invite_code));
  if not found then
    raise exception 'invite code not found';
  end if;

  update public.profiles set squad_id = v_squad.id, updated_at = now() where id = v_uid;

  return v_squad;
end;
$$;

revoke all on function public.join_squad(text) from public;
grant execute on function public.join_squad(text) to authenticated;

-- 6. leave_squad
create or replace function public.leave_squad()
returns void
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

  update public.profiles set squad_id = null, updated_at = now() where id = v_uid;
end;
$$;

revoke all on function public.leave_squad() from public;
grant execute on function public.leave_squad() to authenticated;

-- 7. squad_leaderboard: squad-mate visibility via SECURITY DEFINER, not
-- relaxed RLS on `profiles` (which is strictly self-only) — same posture
-- as `submit_run`.
create or replace function public.squad_leaderboard(p_squad_id uuid)
returns table(user_id uuid, display_name text, streak_tier smallint, area_sqm double precision)
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

  if not exists (select 1 from public.profiles where id = v_uid and squad_id = p_squad_id) then
    raise exception 'not a member of this squad';
  end if;

  return query
    select
      p.id,
      p.display_name,
      p.streak_tier,
      coalesce(sum(t.area_sqm), 0)::double precision
    from public.profiles p
    left join public.territories t on t.user_id = p.id
    where p.squad_id = p_squad_id
    group by p.id, p.display_name, p.streak_tier
    order by coalesce(sum(t.area_sqm), 0) desc;
end;
$$;

revoke all on function public.squad_leaderboard(uuid) from public;
grant execute on function public.squad_leaderboard(uuid) to authenticated;

-- 8. squad_members: for the "Live now" presence-join list
create or replace function public.squad_members(p_squad_id uuid)
returns table(user_id uuid, display_name text, streak_tier smallint)
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

  if not exists (select 1 from public.profiles where id = v_uid and squad_id = p_squad_id) then
    raise exception 'not a member of this squad';
  end if;

  return query
    select p.id, p.display_name, p.streak_tier
    from public.profiles p
    where p.squad_id = p_squad_id;
end;
$$;

revoke all on function public.squad_members(uuid) from public;
grant execute on function public.squad_members(uuid) to authenticated;

-- 9. streak tier, computed server-side (trustworthy for other squad
-- members to see) from already-synced `sessions` rows, mirroring the
-- existing Dart `watchCurrentStreak` day-walk logic. Fires on insert AND
-- update since the outbox syncs sessions via upsert (idempotent either way).
create or replace function public.recompute_streak_tier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_streak int := 0;
  v_day date := new.completed_at::date;
  v_has_session boolean;
  v_tier smallint;
begin
  if new.completed_at is null then
    return new;
  end if;

  loop
    select exists(
      select 1 from public.sessions
      where user_id = new.user_id
        and completed_at::date = v_day
    ) into v_has_session;

    exit when not v_has_session;
    v_streak := v_streak + 1;
    v_day := v_day - 1;
  end loop;

  -- Thresholds mirror `AppConstants` (Dart) — keep both in sync.
  v_tier := case
    when v_streak >= 14 then 3  -- Gold
    when v_streak >= 7 then 2   -- Silver
    when v_streak >= 3 then 1   -- Bronze
    else 0                       -- None
  end;

  update public.profiles set streak_tier = v_tier, updated_at = now() where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists sessions_recompute_streak_tier on public.sessions;
create trigger sessions_recompute_streak_tier
  after insert or update on public.sessions
  for each row
  execute function public.recompute_streak_tier();
