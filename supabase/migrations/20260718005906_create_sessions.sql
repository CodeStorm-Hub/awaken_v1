create table public.sessions (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  alarm_id uuid references public.alarms(id) on delete set null,
  reps_completed smallint not null check (reps_completed >= 0),
  completed_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index sessions_user_id_idx on public.sessions(user_id) where deleted_at is null;

alter table public.sessions enable row level security;

create policy "sessions_all_own" on public.sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger sessions_set_updated_at
  before update on public.sessions
  for each row execute function public.set_updated_at();
