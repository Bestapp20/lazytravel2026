// photo-store: copies place/cover photos into permanent public Storage.
//   POST {mode:"item", item_id}      -> store one item's photo (called by a DB trigger on insert/update)
//   POST {mode:"sweep", batch?:25}   -> backfill / retry stragglers (called by pg_cron)
// Only ever reads photo references that already exist in the DB and only writes
// items.photo_url / trips.cover_image_url. Never deletes anything.
import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { cityPhotoRef, freshPhotoRef, isStoredUrl, PHOTO_BUCKET, storePhotoRef, storeUrl } from "../_shared/photos.ts";

type Item = { id: string; photo_reference: string | null; photo_url: string | null; google_place_id: string | null; photo_attempts: number };

// deno-lint-ignore no-explicit-any
async function storeItem(admin: any, it: Item): Promise<string> {
  let url: string | null = null;
  let newRef: string | null = null;
  if (it.photo_reference) url = await storePhotoRef(admin, it.photo_reference);
  // legacy googleusercontent URL may still be alive
  if (!url && it.photo_url && !isStoredUrl(it.photo_url)) url = await storeUrl(admin, it.photo_url, "legacy", it.photo_url);
  // reference went stale: ask Google for a fresh one
  if (!url && it.google_place_id) {
    newRef = await freshPhotoRef(it.google_place_id);
    if (newRef) url = await storePhotoRef(admin, newRef);
  }
  if (url) {
    const patch: Record<string, unknown> = { photo_url: url, photo_attempts: 0 };
    if (newRef) patch.photo_reference = newRef;
    await admin.from("items").update(patch).eq("id", it.id);
    return "ok";
  }
  await admin.from("items").update({ photo_attempts: (it.photo_attempts ?? 0) + 1 }).eq("id", it.id);
  return "fail";
}

// deno-lint-ignore no-explicit-any
async function storeCover(admin: any, trip: { id: string; cover_image_url: string; destinations: any }): Promise<string> {
  let url = await storeUrl(admin, trip.cover_image_url, "covers", `cover:${trip.id}`);
  if (!url) {
    const d = Array.isArray(trip.destinations) ? trip.destinations[0] : null;
    if (d?.city) {
      const ref = await cityPhotoRef(d.city, d.country);
      if (ref) url = await storePhotoRef(admin, ref, 1200);
    }
  }
  if (!url) return "fail";
  await admin.from("trips").update({ cover_image_url: url }).eq("id", trip.id);
  return "ok";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const body = await req.json().catch(() => ({}));
    const admin = serviceClient();
    const sel = "id,photo_reference,photo_url,google_place_id,photo_attempts";
    if (body.mode === "item" && body.item_id) {
      const { data } = await admin.from("items").select(sel).eq("id", body.item_id).maybeSingle();
      if (!data || isStoredUrl(data.photo_url)) return json({ ok: true, skipped: true });
      return json({ ok: true, result: await storeItem(admin, data as Item) });
    }
    const batch = Math.min(Number(body.batch ?? 25), 60);
    const likeStored = `%/storage/v1/object/public/${PHOTO_BUCKET}/%`;
    const { data: items } = await admin.from("items").select(sel)
      .or(`photo_reference.not.is.null,photo_url.not.is.null`)
      .or(`photo_url.is.null,photo_url.not.like.${likeStored}`)
      .lt("photo_attempts", 3)
      .order("created_at", { ascending: false }).limit(batch);
    const out = { items_ok: 0, items_fail: 0, covers_ok: 0, covers_fail: 0 };
    const list = (items ?? []) as Item[];
    for (let i = 0; i < list.length; i += 5) {
      const rs = await Promise.all(list.slice(i, i + 5).map((it) => storeItem(admin, it)));
      for (const r of rs) r === "ok" ? out.items_ok++ : out.items_fail++;
    }
    const { data: trips } = await admin.from("trips").select("id,cover_image_url,destinations")
      .not("cover_image_url", "is", null).not("cover_image_url", "like", likeStored).limit(5);
    for (const t of trips ?? []) {
      const r = await storeCover(admin, t as never);
      r === "ok" ? out.covers_ok++ : out.covers_fail++;
    }
    return json({ ok: true, ...out, remaining_hint: list.length === batch });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
