-- Cheapest Trip Finder (hotel stage first; flight stage plugs in later).
create table public.trip_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  origin text,
  destination text,               -- null = anywhere (needs flight stage)
  dest_lat double precision,
  dest_lng double precision,
  date_from date not null,
  date_to date not null,
  nights_min int not null default 3,
  nights_max int not null default 7,
  adults int not null default 2,
  children int not null default 0,
  budget numeric,
  currency text not null default 'ILS',
  status text not null default 'queued'
    check (status in ('queued','discovering','verifying','done','error')),
  progress int not null default 0,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index trip_searches_user_idx on public.trip_searches (user_id, created_at desc);

create table public.trip_offers (
  id uuid primary key default gen_random_uuid(),
  search_id uuid not null references public.trip_searches (id) on delete cascade,
  rank int not null,
  destination text,
  checkin date not null,
  checkout date not null,
  nights int not null,
  flight_price numeric,
  flight jsonb,
  hotel_id text,
  hotel_name text,
  hotel_stars numeric,
  hotel_rating numeric,
  hotel_photo text,
  hotel_address text,
  room_name text,
  board_name text,
  refundable boolean,
  hotel_offer_id text,
  hotel_price numeric,
  total numeric not null,
  currency text not null,
  ai_reason text,
  created_at timestamptz not null default now()
);
create index trip_offers_search_idx on public.trip_offers (search_id, rank);

create table public.price_cache (
  key text primary key,
  payload jsonb not null,
  expires_at timestamptz not null
);

create table public.hotel_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  offer_id uuid references public.trip_offers (id) on delete set null,
  prebook_id text not null,
  transaction_id text,
  booking_id text,
  status text not null default 'prebooked',
  hotel_name text,
  checkin date,
  checkout date,
  price numeric,
  currency text,
  sandbox boolean not null default true,
  raw jsonb,
  created_at timestamptz not null default now()
);

alter table public.trip_searches enable row level security;
alter table public.trip_offers enable row level security;
alter table public.price_cache enable row level security;
alter table public.hotel_bookings enable row level security;

create policy "own searches read" on public.trip_searches for select using (user_id = auth.uid());
create policy "own searches insert" on public.trip_searches for insert with check (user_id = auth.uid());
create policy "own offers read" on public.trip_offers for select using (
  exists (select 1 from public.trip_searches s where s.id = search_id and s.user_id = auth.uid()));
create policy "own bookings read" on public.hotel_bookings for select using (user_id = auth.uid());
-- price_cache: service role only (no policies).

create trigger trip_searches_updated before update on public.trip_searches
  for each row execute function public.set_updated_at();

alter publication supabase_realtime add table public.trip_searches;
