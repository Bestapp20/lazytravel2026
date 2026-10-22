alter table public.trip_searches add column if not exists components text[] not null default '{flight,hotel}';
alter table public.trip_searches drop constraint if exists trip_searches_bag_mode_check;
alter table public.trip_searches add constraint trip_searches_bag_mode_check check (bag_mode = any (array['none','carryon','trolley','checked']));
