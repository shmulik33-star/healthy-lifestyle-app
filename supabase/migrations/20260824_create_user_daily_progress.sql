create table if not exists public.user_daily_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  day_key text not null,
  water_cups integer not null default 0 check (water_cups >= 0 and water_cups <= 100),
  steps integer not null default 0 check (steps >= 0 and steps <= 500000),
  workout_completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, day_key)
);

alter table public.user_daily_progress enable row level security;

drop policy if exists "Users can read own daily progress" on public.user_daily_progress;
create policy "Users can read own daily progress"
on public.user_daily_progress for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert own daily progress" on public.user_daily_progress;
create policy "Users can insert own daily progress"
on public.user_daily_progress for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own daily progress" on public.user_daily_progress;
create policy "Users can update own daily progress"
on public.user_daily_progress for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.merge_user_daily_progress(
  p_day_key text,
  p_water_cups integer,
  p_steps integer,
  p_workout_completed boolean
)
returns public.user_daily_progress
language plpgsql
security invoker
set search_path = public
as $$
declare
  result public.user_daily_progress;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  insert into public.user_daily_progress (
    user_id,
    day_key,
    water_cups,
    steps,
    workout_completed,
    updated_at
  ) values (
    auth.uid(),
    p_day_key,
    greatest(coalesce(p_water_cups, 0), 0),
    greatest(coalesce(p_steps, 0), 0),
    coalesce(p_workout_completed, false),
    now()
  )
  on conflict (user_id, day_key) do update
  set water_cups = greatest(user_daily_progress.water_cups, excluded.water_cups),
      steps = greatest(user_daily_progress.steps, excluded.steps),
      workout_completed = user_daily_progress.workout_completed or excluded.workout_completed,
      updated_at = now()
  returning * into result;

  return result;
end;
$$;

grant execute on function public.merge_user_daily_progress(text, integer, integer, boolean) to authenticated;
