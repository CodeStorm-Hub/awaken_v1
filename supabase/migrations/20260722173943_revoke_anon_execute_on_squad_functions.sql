-- Supabase grants EXECUTE on new public-schema functions to anon and
-- authenticated by default (ALTER DEFAULT PRIVILEGES), independent of the
-- PUBLIC pseudo-role — `revoke all from public` in the prior migration
-- didn't touch those direct grants. Explicitly revoke anon; these RPCs all
-- require auth.uid(), same posture as submit_run.
revoke execute on function public.create_squad(text) from anon;
revoke execute on function public.join_squad(text) from anon;
revoke execute on function public.leave_squad() from anon;
revoke execute on function public.squad_leaderboard(uuid) from anon;
revoke execute on function public.squad_members(uuid) from anon;

-- recompute_streak_tier is a trigger function only — it should never be
-- directly callable via /rest/v1/rpc/ by anyone.
revoke execute on function public.recompute_streak_tier() from anon;
revoke execute on function public.recompute_streak_tier() from authenticated;
