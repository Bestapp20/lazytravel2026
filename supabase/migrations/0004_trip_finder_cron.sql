-- Offer coordinates (for "create trip from offer") + pg_cron sweep of the trip-search worker.
alter table public.trip_offers add column if not exists dest_lat double precision, add column if not exists dest_lng double precision;
create extension if not exists pg_cron;
create extension if not exists pg_net;
-- Scheduled with the project's public anon key (applied out-of-band, not stored here):
-- select cron.schedule('trip-search-worker', '* * * * *', $$
--   select net.http_post(
--     url := 'https://pgjhspqlimqxggthdzbu.supabase.co/functions/v1/trip-search-worker',
--     headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
--     body := '{}'::jsonb) $$);
