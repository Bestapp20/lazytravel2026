create table if not exists public.ticket_matches (
  place_key text primary key,
  provider text,
  partner_name text,
  product_id text,
  title text,
  url text,
  price numeric,
  currency text,
  confidence real not null default 0,
  checked_at timestamptz not null default now()
);
alter table public.ticket_matches enable row level security;
create policy ticket_matches_read on public.ticket_matches for select to authenticated using (true);
