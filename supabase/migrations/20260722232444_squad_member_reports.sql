-- UGC report mechanism for squads (Play/App Store UGC-moderation requirement
-- — squads are invite-code/private, so the "specified set of users" tier
-- applies: a report mechanism is sufficient, no public block/moderation
-- queue needed).
create table public.squad_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id),
  reported_user_id uuid not null references public.profiles(id),
  squad_id uuid not null references public.squads(id),
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  constraint squad_reports_no_self_report check (reporter_id <> reported_user_id)
);

alter table public.squad_reports enable row level security;

-- Reporters can insert their own reports; nobody can read/update/delete via
-- the client — reports are reviewed by the operator directly (table editor
-- / a future admin RPC), not surfaced back to any user.
create policy squad_reports_insert_own
  on public.squad_reports
  for insert
  to authenticated
  with check (reporter_id = auth.uid());

revoke all on public.squad_reports from anon;
