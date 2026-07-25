-- Same PUBLIC-vs-anon gotcha as `recompute_streak_tier` before it: Supabase
-- grants EXECUTE on new public-schema functions to anon/authenticated
-- individually by default (ALTER DEFAULT PRIVILEGES), separate from the
-- PUBLIC pseudo-role. `revoke all ... from public` in the migration that
-- created these two RPCs only removed the PUBLIC grant, not anon's own —
-- confirmed live via the security advisor still flagging both as
-- anon-executable after that migration. Both require auth.uid(), so anon
-- has no legitimate reason to call them.
revoke execute on function public.bump_wake_up_tax() from anon;
revoke execute on function public.reset_wake_up_tax() from anon;
