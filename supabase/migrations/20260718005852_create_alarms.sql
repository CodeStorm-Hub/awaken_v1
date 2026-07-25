create table public.alarms (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  scheduled_time timestamptz not null,
  exercise_mode text not null check (exercise_mode in ('squat', 'pushup')),
  required_reps smallint not null check (required_reps > 0),
  -- bounded penalty schedule (plan §2.3 moderate: no unbounded exponential)
  penalty_multiplier numeric(3,2) not null default 1.0
    check (penalty_multiplier >= 1.0 and penalty_multiplier <= 4.0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index alarms_user_id_idx on public.alarms(user_id) where deleted_at is null;

alter table public.alarms enable row level security;

create policy "alarms_all_own" on public.alarms
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger alarms_set_updated_at
  before update on public.alarms
  for each row execute function public.set_updated_at();
