-- Permanent place photos: public bucket + trigger + cron sweep.
-- NOTE: replace <ANON_KEY> with the project's anon JWT (applied out-of-band, never committed).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('place-photos','place-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true, file_size_limit=5242880,
  allowed_mime_types=array['image/jpeg','image/png','image/webp'];
-- No INSERT/UPDATE/DELETE policies for anon/authenticated: only the service role (edge function) writes.
-- Public bucket => objects readable by URL, but not listable (no SELECT policy).

alter table public.items add column if not exists photo_attempts integer not null default 0;

create or replace function public.items_store_photo() returns trigger
language plpgsql security definer set search_path = public, net as $$
begin
  perform net.http_post(
    url := 'https://pgjhspqlimqxggthdzbu.supabase.co/functions/v1/photo-store',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
    body := jsonb_build_object('mode','item','item_id', new.id));
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.items_store_photo() from public, anon, authenticated;

drop trigger if exists items_store_photo_trg on public.items;
create trigger items_store_photo_trg
after insert or update of photo_reference, photo_url on public.items
for each row
when ((new.photo_reference is not null or new.photo_url is not null)
      and coalesce(new.photo_url,'') not like '%/storage/v1/object/public/place-photos/%')
execute function public.items_store_photo();

select cron.schedule('photo-store-sweep', '*/3 * * * *', $$
  select net.http_post(
    url := 'https://pgjhspqlimqxggthdzbu.supabase.co/functions/v1/photo-store',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
    body := '{"mode":"sweep","batch":25}'::jsonb) $$);