-- Pin search_path on trigger functions (function_search_path_mutable)
alter function public.set_updated_at() set search_path = public;
alter function public.territories_set_area() set search_path = public;

-- handle_new_user is trigger-only; should not be directly callable via
-- PostgREST /rpc/handle_new_user by anon/authenticated.
revoke all on function public.handle_new_user() from public, anon, authenticated;
