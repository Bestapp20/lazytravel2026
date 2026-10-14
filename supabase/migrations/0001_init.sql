-- LAZYTRAVEL v1 schema: trips → days → items, members, documents, expenses, invites.
-- RLS is based on trip_members (owner | viewer). Private storage bucket: trip-docs.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  city text,
  bio text,
  travel_style text,
  interests text[] not null default '{}',
  kosher boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  cover_image_url text,
  destinations jsonb not null default '[]'::jsonb,
  start_date date,
  end_date date,
  travelers int not null default 1,
  kids int not null default 0,
  kid_ages int[] not null default '{}',
  companion_type text,
  pace text,
  budget_tier text,
  budget_total numeric,
  currency text not null default 'ILS',
  kosher boolean not null default false,
  interests jsonb not null default '{}'::jsonb,
  hotel jsonb,
  status text not null default 'planned'
    check (status in ('draft', 'planned', 'active', 'done')),
  origin_city text,
  notes text,
  generation_params jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.trip_members (
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('owner', 'viewer')),
  invited_email text,
  created_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

create table public.days (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  day_index int not null,
  date date,
  title text,
  weather jsonb,
  notes text,
  unique (trip_id, day_index)
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  day_id uuid not null references public.days (id) on delete cascade,
  place_name text not null,
  google_place_id text,
  category text,
  address text,
  lat double precision,
  lng double precision,
  map_link text,
  start_time time,
  end_time time,
  duration_minutes int,
  sort_order int not null default 0,
  notes text,
  ai_tip text,
  rating numeric,
  price_level int,
  photo_url text,
  photo_reference text,
  estimated_cost numeric,
  transport_to_next jsonb,
  hours jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  day_id uuid references public.days (id) on delete set null,
  item_id uuid references public.items (id) on delete set null,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  doc_type text not null check (doc_type in ('flight', 'hotel', 'insurance', 'other')),
  title text not null,
  storage_path text not null,
  mime_type text,
  file_size bigint,
  created_at timestamptz not null default now()
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  day_id uuid references public.days (id) on delete set null,
  item_id uuid references public.items (id) on delete set null,
  category text not null,
  title text,
  amount numeric not null,
  currency text not null default 'ILS',
  spent_at date,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.trip_invites (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  email text not null,
  invited_by uuid not null references public.profiles (id),
  role text not null default 'viewer' check (role in ('owner', 'viewer')),
  token uuid not null default gen_random_uuid(),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'expired')),
  created_at timestamptz not null default now()
);

create index trip_members_user_idx on public.trip_members (user_id);
create index days_trip_idx on public.days (trip_id, day_index);
create index items_day_idx on public.items (day_id, sort_order);
create index items_trip_idx on public.items (trip_id);
create index documents_trip_idx on public.documents (trip_id);
create index expenses_trip_idx on public.expenses (trip_id);
create index trip_invites_email_idx on public.trip_invites (lower(email), status);

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trips_updated_at before update on public.trips
  for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger items_updated_at before update on public.items
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Membership helpers (security definer — used by RLS, no recursion)
-- ---------------------------------------------------------------------------

create or replace function public.user_trip_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select trip_id from public.trip_members where user_id = auth.uid();
$$;

create or replace function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = p_trip_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_trip_owner(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = p_trip_id and user_id = auth.uid() and role = 'owner'
  );
$$;

-- ---------------------------------------------------------------------------
-- Auth → profile + pending invites
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.trip_members (trip_id, user_id, role, invited_email)
  select ti.trip_id, new.id, ti.role, ti.email
  from public.trip_invites ti
  where lower(ti.email) = lower(new.email)
    and ti.status = 'pending'
  on conflict do nothing;

  update public.trip_invites
     set status = 'accepted'
   where lower(email) = lower(new.email)
     and status = 'pending';

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_new_trip()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.trip_members (trip_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_trip_created on public.trips;
create trigger on_trip_created
  after insert on public.trips
  for each row execute function public.handle_new_trip();

create or replace function public.accept_my_invites()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
begin
  insert into public.trip_members (trip_id, user_id, role, invited_email)
  select ti.trip_id, auth.uid(), ti.role, ti.email
  from public.trip_invites ti
  join auth.users u on u.id = auth.uid()
  where lower(ti.email) = lower(u.email)
    and ti.status = 'pending'
  on conflict do nothing;

  update public.trip_invites ti
     set status = 'accepted'
    from auth.users u
   where u.id = auth.uid()
     and lower(ti.email) = lower(u.email)
     and ti.status = 'pending';

  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.accept_my_invites() to authenticated;

create or replace function public.find_user_id_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function public.find_user_id_by_email(text) from public, anon, authenticated;
grant execute on function public.find_user_id_by_email(text) to service_role;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.days enable row level security;
alter table public.items enable row level security;
alter table public.documents enable row level security;
alter table public.expenses enable row level security;
alter table public.trip_invites enable row level security;

-- profiles
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or id in (select user_id from public.trip_members where trip_id in (select public.user_trip_ids()))
  );
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

-- trips
create policy trips_select on public.trips
  for select to authenticated
  using (id in (select public.user_trip_ids()));
create policy trips_insert on public.trips
  for insert to authenticated
  with check (owner_id = auth.uid());
create policy trips_update_owner on public.trips
  for update to authenticated
  using (public.is_trip_owner(id))
  with check (public.is_trip_owner(id));
create policy trips_delete_owner on public.trips
  for delete to authenticated
  using (public.is_trip_owner(id));

-- trip_members
create policy trip_members_select on public.trip_members
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy trip_members_insert_owner on public.trip_members
  for insert to authenticated
  with check (public.is_trip_owner(trip_id));
create policy trip_members_delete_owner on public.trip_members
  for delete to authenticated
  using (public.is_trip_owner(trip_id) and role <> 'owner');

-- days
create policy days_select on public.days
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy days_write_owner on public.days
  for all to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

-- items
create policy items_select on public.items
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy items_write_owner on public.items
  for all to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

-- documents
create policy documents_select on public.documents
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy documents_insert_owner on public.documents
  for insert to authenticated
  with check (public.is_trip_owner(trip_id) and owner_id = auth.uid());
create policy documents_delete_owner on public.documents
  for delete to authenticated
  using (public.is_trip_owner(trip_id));

-- expenses
create policy expenses_select on public.expenses
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy expenses_write_owner on public.expenses
  for all to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));

-- invites
create policy trip_invites_select on public.trip_invites
  for select to authenticated
  using (public.is_trip_owner(trip_id));
create policy trip_invites_insert on public.trip_invites
  for insert to authenticated
  with check (public.is_trip_owner(trip_id) and invited_by = auth.uid());
create policy trip_invites_update_owner on public.trip_invites
  for update to authenticated
  using (public.is_trip_owner(trip_id));

-- ---------------------------------------------------------------------------
-- Storage: private bucket trip-docs  path = {trip_id}/{file}
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('trip-docs', 'trip-docs', false)
on conflict (id) do update set public = excluded.public;

create policy trip_docs_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'trip-docs'
    and public.is_trip_member(((storage.foldername(name))[1])::uuid)
  );

create policy trip_docs_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'trip-docs'
    and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
  );

create policy trip_docs_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'trip-docs'
    and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
  );

create policy trip_docs_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'trip-docs'
    and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
  );

-- ---------------------------------------------------------------------------
-- v2 extension points (empty tables so booking can land later without a rewrite)
-- ---------------------------------------------------------------------------

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  kind text not null check (kind in ('flight', 'hotel', 'activity', 'transfer', 'other')),
  provider text,
  provider_ref text,
  status text not null default 'draft',
  amount numeric,
  currency text default 'ILS',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.bookings enable row level security;
create policy bookings_member_select on public.bookings
  for select to authenticated
  using (public.is_trip_member(trip_id));
create policy bookings_owner_write on public.bookings
  for all to authenticated
  using (public.is_trip_owner(trip_id))
  with check (public.is_trip_owner(trip_id));
