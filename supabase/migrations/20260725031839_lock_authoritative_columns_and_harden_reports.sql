-- Remove direct client write access to authoritative profile fields.
-- squad_id is only ever legitimately changed via create_squad/join_squad/
-- leave_squad (SECURITY DEFINER RPCs); streak_tier is only ever set by the
-- recompute_streak_tier trigger. Neither is written directly by the client
-- app today, so this is safe with no client-code change required.
revoke update (squad_id, streak_tier) on public.profiles from anon, authenticated;

-- recompute_streak_tier is trigger-only. The prior revoke
-- (revoke_anon_execute_on_squad_functions) revoked the explicit anon/
-- authenticated grants but left the PUBLIC pseudo-role's EXECUTE grant in
-- place, so anon/authenticated could still call it via inherited PUBLIC
-- privilege (confirmed live via the security advisor still flagging it).
revoke execute on function public.recompute_streak_tier() from public;

-- squad_reports previously only checked reporter_id = auth.uid() — it
-- never verified the reporter and the reported user actually share the
-- submitted squad_id, so a report could reference an arbitrary user/squad
-- combination. Require both parties to currently belong to the stated
-- squad at insert time.
drop policy if exists "squad_reports_insert_own" on public.squad_reports;
create policy "squad_reports_insert_own" on public.squad_reports
  for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and exists (
      select 1 from public.profiles
      where id = (select auth.uid()) and squad_id = squad_reports.squad_id
    )
    and exists (
      select 1 from public.profiles
      where id = squad_reports.reported_user_id and squad_id = squad_reports.squad_id
    )
  );
