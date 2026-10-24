-- Booking tracking: extra columns, webhook secret table, pg_cron poll.
alter table public.hotel_bookings
  add column if not exists status_synced_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists confirmation_code text,
  add column if not exists confirmation_email_sent_at timestamptz,
  add column if not exists cancel_info jsonb,
  add column if not exists sync_error text;
alter table public.flight_bookings
  add column if not exists status_synced_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists confirmation_code text,
  add column if not exists confirmation_email_sent_at timestamptz,
  add column if not exists cancel_info jsonb,
  add column if not exists sync_error text;

create table if not exists public.webhook_secrets (
  name text primary key,
  secret text not null,
  created_at timestamptz not null default now()
);
alter table public.webhook_secrets enable row level security; -- no policies: service role only
revoke all on public.webhook_secrets from anon, authenticated;
insert into public.webhook_secrets(name, secret)
values ('nuitee', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (name) do nothing;

-- Poll LiteAPI for booking status every 5 minutes. <ANON_KEY> is applied out-of-band.
select cron.schedule('booking-sync-poll', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://pgjhspqlimqxggthdzbu.supabase.co/functions/v1/booking-manage',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
    body := '{"action":"poll"}'::jsonb) $$);
