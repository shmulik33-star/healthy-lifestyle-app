create table public.user_custom_foods (
  user_id uuid not null references auth.users(id) on delete cascade,
  food_id text not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (user_id, food_id)
);

alter table public.user_custom_foods enable row level security;

grant select, insert, update, delete on public.user_custom_foods to authenticated;

create policy "Users can read own custom foods"
  on public.user_custom_foods
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert own custom foods"
  on public.user_custom_foods
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update own custom foods"
  on public.user_custom_foods
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete own custom foods"
  on public.user_custom_foods
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create index user_custom_foods_updated_at_idx
  on public.user_custom_foods (user_id, updated_at desc);
