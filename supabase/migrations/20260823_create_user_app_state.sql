create table if not exists public.user_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  revision bigint not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.user_app_state enable row level security;

create policy "user_app_state_select_own"
on public.user_app_state for select
to authenticated
using (auth.uid() = user_id);

create policy "user_app_state_insert_own"
on public.user_app_state for insert
to authenticated
with check (auth.uid() = user_id);

create policy "user_app_state_update_own"
on public.user_app_state for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "user_app_state_delete_own"
on public.user_app_state for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.touch_user_app_state()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.revision := old.revision + 1;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_app_state_touch on public.user_app_state;
create trigger user_app_state_touch
before update on public.user_app_state
for each row execute function public.touch_user_app_state();
