-- user_stats.current_tax_multiplier was client-writable via the generic
-- outbox upsert path (any authenticated user could POST an arbitrary
-- value directly to /rest/v1/user_stats, bypassing the app's own bounded
-- step-up/reset rules). Replace direct writes with two SECURITY DEFINER
-- RPCs that recompute the value server-side from the *current* stored
-- value — mirrors WakeUpTaxStore.bump()/reset() (Dart) exactly; keep both
-- in sync if the step/cap constants change (AppConstants.
-- penaltyMultiplierStep = 1.5, penaltyMultiplierCap = 4.0).

create or replace function public.bump_wake_up_tax()
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_current numeric;
  v_next numeric;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select current_tax_multiplier into v_current from public.user_stats where user_id = v_uid;
  v_next := least(coalesce(v_current, 1.0) * 1.5, 4.0);

  insert into public.user_stats (user_id, current_tax_multiplier)
  values (v_uid, v_next)
  on conflict (user_id) do update set current_tax_multiplier = v_next, updated_at = now();

  return v_next;
end;
$$;

revoke all on function public.bump_wake_up_tax() from public;
grant execute on function public.bump_wake_up_tax() to authenticated;

create or replace function public.reset_wake_up_tax()
returns numeric
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

  insert into public.user_stats (user_id, current_tax_multiplier)
  values (v_uid, 1.0)
  on conflict (user_id) do update set current_tax_multiplier = 1.0, updated_at = now();

  return 1.0;
end;
$$;

revoke all on function public.reset_wake_up_tax() from public;
grant execute on function public.reset_wake_up_tax() to authenticated;

-- Now safe to close off direct client mutation entirely — all writes go
-- through the RPCs above. SELECT stays (needed for pull hydration/reads),
-- gated by the existing user_stats_all_own RLS policy.
revoke insert, update, delete on public.user_stats from anon, authenticated;
