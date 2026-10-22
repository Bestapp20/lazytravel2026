-- Bag filter on searches + in-app flight bookings (LiteAPI/Nuitee, payment SDK).
alter table public.trip_searches add column if not exists bag_mode text not null default 'none'
  check (bag_mode in ('none','checked','carryon'));

create table if not exists public.flight_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  offer_id uuid references public.trip_offers (id) on delete set null,
  prebook_id text not null,
  transaction_id text,
  booking_id text,
  status text not null default 'prebooked',
  with_bags boolean not null default false,
  price numeric,
  currency text,
  sandbox boolean not null default true,
  raw jsonb,
  created_at timestamptz not null default now()
);
alter table public.flight_bookings enable row level security;
create policy "own flight bookings read" on public.flight_bookings for select using (user_id = auth.uid());
