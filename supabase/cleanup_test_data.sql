-- LAZYTRAVEL – test-data cleanup helper (project pgjhspqlimqxggthdzbu)
-- PART 1 only SELECTs. PART 2 (DELETE) is commented out and must be approved by Edward first.
-- The Thailand trip a8b5dc8a-ade3-4f4a-882b-9fc88e045689 is EXCLUDED everywhere.

-- ===== PART 1: LISTING (safe, read-only) =====

-- 1a. Test trips: Rome / Larnaca / Bucharest (all owners). Athens is listed separately to review.
select t.id, t.title, u.email owner, t.created_at, (select count(*) from items i where i.trip_id=t.id) items,
       (select count(*) from days d where d.trip_id=t.id) days
from trips t join auth.users u on u.id=t.owner_id
where t.id <> 'a8b5dc8a-ade3-4f4a-882b-9fc88e045689'
  and t.title in ('Rome','Larnaca','Bucharest')
order by t.created_at;

-- 1b. Trips to REVIEW (not auto-selected): Athens
select id, title, owner_id, created_at from trips where title = 'Athens';

-- 1c. Test users: the e2e account (its trips/profile are the only data attached to it)
select id, email, created_at, last_sign_in_at from auth.users where email = 'lazytravel.e2e.test@gmail.com';

-- 1d. Sandbox bookings (hotel + flight). All are sandbox=true; 'prebooked' rows are abandoned checkouts.
select 'hotel' kind, id, status, hotel_name label, booking_id, confirmation_code, created_at from hotel_bookings where sandbox
union all
select 'flight', id, status, null, booking_id, confirmation_code, created_at from flight_bookings where sandbox
order by created_at;

-- 1e. Search sessions and offers created by tests (offers cascade from searches)
select s.id, s.user_id, s.origin, s.destination, s.status, s.created_at,
       (select count(*) from trip_offers o where o.search_id=s.id) offers
from trip_searches s order by s.created_at;

-- 1f. Documents attached to test trips
select d.id, d.trip_id, d.title, d.storage_path from documents d
where d.trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'))
  and d.trip_id <> 'a8b5dc8a-ade3-4f4a-882b-9fc88e045689';

-- 1g. Caches (harmless, re-creatable): ticket matches, price cache
select count(*) ticket_matches from ticket_matches;
select count(*) price_cache from price_cache;

-- 1h. Photos copied to Storage for test trips (bucket place-photos, files are sha1-named and shared across trips; usually keep)
select count(*) stored_photo_items from items where photo_url like '%/place-photos/%'
  and trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'));

-- ===== PART 2: DELETION (COMMENTED OUT – run only after Edward approves) =====
/*
begin;
-- bookings first (FK -> trip_offers)
delete from hotel_bookings  where sandbox;
delete from flight_bookings where sandbox;
-- searches (offers cascade or delete explicitly first)
delete from trip_offers   where search_id in (select id from trip_searches);
delete from trip_searches;
-- documents, then trips (days/items/members cascade or are removed explicitly)
delete from documents where trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'));
delete from items   where trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'));
delete from days    where trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'));
delete from trip_members where trip_id in (select id from trips where title in ('Rome','Larnaca','Bucharest'));
delete from trips   where title in ('Rome','Larnaca','Bucharest')
                      and id <> 'a8b5dc8a-ade3-4f4a-882b-9fc88e045689';
-- test user (delete trips first; profile cascades from auth.users)
-- delete from auth.users where email = 'lazytravel.e2e.test@gmail.com';
-- caches
-- delete from ticket_matches; delete from price_cache;
commit;
*/
