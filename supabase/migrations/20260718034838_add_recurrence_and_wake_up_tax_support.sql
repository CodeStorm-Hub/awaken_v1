-- Recurring alarms (client: AlarmSchedule.recurringDays)
alter table public.alarms
  add column recurring_days text not null default '';

-- Session context that the client already logs locally but never had a
-- remote column for (LocalWriter.insertSession sends these; without these
-- columns every session upsert fails and retries forever).
alter table public.sessions
  add column exercise_mode text not null default 'squat'
    check (exercise_mode = any (array['squat'::text, 'pushup'::text])),
  add column started_at timestamptz not null default now();

-- Global, per-user wake-up tax (moved off individual alarms so deleting
-- and recreating an alarm can't reset it).
create table public.user_stats (
  user_id uuid primary key references public.profiles(id),
  current_tax_multiplier numeric not null default 1.0
    check (current_tax_multiplier >= 1.0 and current_tax_multiplier <= 4.0),
  updated_at timestamptz not null default now()
);

alter table public.user_stats enable row level security;

create policy user_stats_all_own on public.user_stats
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
