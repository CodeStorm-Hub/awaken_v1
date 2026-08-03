-- The 2026-08-01 "security_invoker" hardening migration
-- (20260801110000_add_fk_indexes_and_security_invoker.sql) blanket-converted
-- several RPCs to SECURITY INVOKER, presumably to silence the Supabase
-- advisor's "authenticated_security_definer_function_executable" lint. That
-- conversion is correct for functions whose work is already covered by a
-- matching self-service RLS policy, but it broke every function below,
-- which relies on running with elevated (definer) privilege by design:
--
--   - submit_run: territories/territory_captures have no client
--     INSERT/UPDATE policy at all — writes only ever happen through this
--     SECURITY DEFINER RPC (see docs/decisions.md). Under invoker mode,
--     every real outdoor run that closes a loop failed to award territory.
--   - create_squad: squads has no INSERT policy — nobody could create one.
--   - join_squad: squads_select_member only allows reading a squad you're
--     already a member of, so looking up a squad by invite code (in order
--     to join it) always missed under invoker, raising a false "invite
--     code not found".
--   - squad_members: profiles_select_own limits reads to your own row, so
--     the member list only ever showed the caller.
--   - global_leaderboard/nearby_leaderboard/squad_leaderboard/
--     my_global_rank/my_nearby_rank/my_squad_rank: all call the private
--     _area_for_window helper, which is deliberately definer-only and
--     revoked from authenticated/anon — calling it from an invoker-mode
--     function raised "permission denied for function _area_for_window"
--     (confirmed live on the Leaderboards sheet).
--
-- Verified still fine under invoker mode (left untouched — matching RLS
-- policies already permit what these need): leave_squad, bump_wake_up_tax,
-- reset_wake_up_tax (user_stats_all_own covers all three), current_rival,
-- my_owned_area_sqm (territories_select_all is public-read),
-- recent_territory_captures.
--
-- Re-applying SECURITY DEFINER on these 10 will re-surface the advisor's
-- "Signed-In Users Can Execute SECURITY DEFINER Function" WARN lint for
-- each — that's expected and already accepted project-wide (see
-- CLAUDE.md's Supabase backend section: "SECURITY DEFINER and deliberately
-- EXECUTE-granted to authenticated — Supabase's security advisor flags
-- that by default; it's expected here, not a regression"), not a new
-- problem introduced by this migration.

ALTER FUNCTION public.submit_run(uuid, jsonb, timestamp with time zone, timestamp with time zone, timestamp with time zone[]) SECURITY DEFINER;
ALTER FUNCTION public.create_squad(text) SECURITY DEFINER;
ALTER FUNCTION public.join_squad(text) SECURITY DEFINER;
ALTER FUNCTION public.squad_members(uuid) SECURITY DEFINER;
ALTER FUNCTION public.global_leaderboard(text, integer, integer) SECURITY DEFINER;
ALTER FUNCTION public.nearby_leaderboard(numeric, text, integer, integer) SECURITY DEFINER;
ALTER FUNCTION public.squad_leaderboard(uuid, text) SECURITY DEFINER;
ALTER FUNCTION public.my_global_rank(text) SECURITY DEFINER;
ALTER FUNCTION public.my_nearby_rank(numeric, text) SECURITY DEFINER;
ALTER FUNCTION public.my_squad_rank(uuid, text) SECURITY DEFINER;
