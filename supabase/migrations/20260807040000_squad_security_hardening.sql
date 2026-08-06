-- Modernization assessment 2026-08-07 (analysis/this/ASSESSMENT.md), SEC-001
-- and SEC-003.
--
-- SEC-001: invite codes were 6 chars drawn from md5()'s hex alphabet
-- (0-9a-f, effectively 16^6 ≈ 16.7M combinations after uppercasing) with no
-- rate limiting on join_squad -- brute-forceable to join an arbitrary
-- private squad and read its members' leaderboard/display data. Fixed two
-- ways: (1) widen the invite-code alphabet to 32 unambiguous
-- alphanumerics (32^6 ≈ 1.07B combinations), (2) add a per-user attempt
-- counter with a 15-minute rolling window, capped at 10 attempts.
--
-- SEC-003: squads.name and profiles.display_name had no upper length
-- bound (unlike squad_reports.reason, which already has
-- `check (char_length(reason) between 1 and 500)`) -- an authenticated
-- (including anonymous) user could submit an arbitrarily large string,
-- stored indefinitely and echoed to every squad member via leaderboard
-- UI. Both now cap at 60 chars, mirrored in create_squad's own validation
-- so a caller gets a clean RPC error instead of a raw constraint
-- violation.

-- 1. Length bounds -----------------------------------------------------

alter table public.squads
  add constraint squads_name_length check (char_length(trim(name)) between 1 and 60);

alter table public.profiles
  add constraint profiles_display_name_length
  check (display_name is null or char_length(trim(display_name)) between 1 and 60);

-- 2. Per-user join_squad attempt tracking -------------------------------

create table public.squad_join_attempts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  attempt_count int not null default 0,
  window_start timestamptz not null default now()
);

alter table public.squad_join_attempts enable row level security;
-- No policies: this table is only ever touched by the SECURITY DEFINER
-- join_squad function below, same "no client access, RPC-only" posture as
-- `territories`/`squads` themselves. Default-deny is intentional.

-- 3. create_squad: wider invite-code alphabet + explicit length check --

create or replace function public.create_squad(p_name text)
returns public.squads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  -- 32 unambiguous alphanumerics (excludes 0/O/1/I) -- 32^6 ≈ 1.07B
  -- combinations, vs. the previous md5-hex-derived ~16.7M.
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_exists boolean;
  v_squad public.squads;
  v_name text := trim(p_name);
  v_i int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.profiles where id = v_uid and squad_id is not null) then
    raise exception 'already in a squad';
  end if;

  if v_name is null or char_length(v_name) = 0 then
    raise exception 'squad name required';
  end if;
  if char_length(v_name) > 60 then
    raise exception 'squad name must be 60 characters or fewer';
  end if;

  loop
    v_code := '';
    for v_i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    select exists(select 1 from public.squads where invite_code = v_code) into v_exists;
    exit when not v_exists;
  end loop;

  insert into public.squads (name, invite_code, owner_id)
  values (v_name, v_code, v_uid)
  returning * into v_squad;

  update public.profiles set squad_id = v_squad.id, updated_at = now() where id = v_uid;

  return v_squad;
end;
$$;

revoke all on function public.create_squad(text) from public;
grant execute on function public.create_squad(text) to authenticated;

-- 4. join_squad: rate-limited ------------------------------------------

create or replace function public.join_squad(p_invite_code text)
returns public.squads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_squad public.squads;
  v_attempts public.squad_join_attempts;
  v_max_attempts constant int := 10;
  v_window constant interval := interval '15 minutes';
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.profiles where id = v_uid and squad_id is not null) then
    raise exception 'already in a squad';
  end if;

  -- Lock this user's attempt row for the duration of the check so
  -- concurrent requests from the same (e.g. scripted) caller can't race
  -- past the cap.
  select * into v_attempts from public.squad_join_attempts where user_id = v_uid for update;
  if not found then
    insert into public.squad_join_attempts (user_id) values (v_uid) returning * into v_attempts;
  end if;

  if v_attempts.window_start < now() - v_window then
    update public.squad_join_attempts set attempt_count = 0, window_start = now()
      where user_id = v_uid
      returning * into v_attempts;
  end if;

  if v_attempts.attempt_count >= v_max_attempts then
    raise exception 'too many join attempts, please try again later';
  end if;

  select * into v_squad from public.squads where invite_code = upper(trim(p_invite_code));
  if not found then
    update public.squad_join_attempts set attempt_count = attempt_count + 1 where user_id = v_uid;
    raise exception 'invite code not found';
  end if;

  -- Successful join resets the counter -- only *failed* lookups count
  -- against the cap, so a legitimate user who joins on the first correct
  -- code is never penalized.
  update public.squad_join_attempts set attempt_count = 0, window_start = now() where user_id = v_uid;

  update public.profiles set squad_id = v_squad.id, updated_at = now() where id = v_uid;

  return v_squad;
end;
$$;

revoke all on function public.join_squad(text) from public;
grant execute on function public.join_squad(text) to authenticated;
