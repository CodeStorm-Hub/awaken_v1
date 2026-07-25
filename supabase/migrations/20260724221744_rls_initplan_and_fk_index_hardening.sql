-- Rewrite auth.uid() calls as (select auth.uid()) in RLS policies so
-- Postgres evaluates the auth check once per query instead of once per
-- row (Supabase RLS performance advisory 0003_auth_rls_initplan).
-- Behavior is identical; this is a pure performance rewrite.

drop policy if exists "alarms_all_own" on public.alarms;
create policy "alarms_all_own" on public.alarms
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to public
  using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to public
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to public
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "runs_select_own" on public.runs;
create policy "runs_select_own" on public.runs
  for select to public
  using ((select auth.uid()) = user_id);

drop policy if exists "runs_insert_own" on public.runs;
create policy "runs_insert_own" on public.runs
  for insert to public
  with check ((select auth.uid()) = user_id);

drop policy if exists "sessions_all_own" on public.sessions;
create policy "sessions_all_own" on public.sessions
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "squad_reports_insert_own" on public.squad_reports;
create policy "squad_reports_insert_own" on public.squad_reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()));

drop policy if exists "user_stats_all_own" on public.user_stats;
create policy "user_stats_all_own" on public.user_stats
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Missing covering indexes for foreign keys (Supabase performance advisory
-- 0001_unindexed_foreign_keys). Small tables today; cheap to add now
-- before squads/reports have real volume.
create index if not exists profiles_squad_id_idx on public.profiles (squad_id);
create index if not exists sessions_alarm_id_idx on public.sessions (alarm_id);
create index if not exists squad_reports_reporter_id_idx on public.squad_reports (reporter_id);
create index if not exists squad_reports_reported_user_id_idx on public.squad_reports (reported_user_id);
create index if not exists squad_reports_squad_id_idx on public.squad_reports (squad_id);
create index if not exists squads_owner_id_idx on public.squads (owner_id);
