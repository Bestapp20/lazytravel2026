// Permanent photo storage: copies Google Places photos into the public `place-photos`
// Storage bucket so the app never depends on expiring googleusercontent URLs.
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";

export const PHOTO_BUCKET = "place-photos";
const PLACES = "https://places.googleapis.com/v1";

function gkey(): string {
  const k = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!k) throw new Error("GOOGLE_PLACES_API_KEY is not set");
  return k;
}

async function sha1(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function isStoredUrl(u: string | null | undefined): boolean {
  return !!u && u.includes(`/storage/v1/object/public/${PHOTO_BUCKET}/`);
}

function extFor(ct: string): string {
  if (ct.includes("png")) return "png";
  if (ct.includes("webp")) return "webp";
  return "jpg";
}

/** Download `src` (an image URL) and upload under `<folder>/<sha1(key)>.<ext>`. Returns the permanent public URL. */
async function copyToBucket(admin: SupabaseClient, src: string, folder: string, key: string, headers: HeadersInit = {}): Promise<string | null> {
  const name = await sha1(key);
  // Already stored (any extension we use)? Reuse it instead of downloading again.
  for (const ext of ["jpg", "png", "webp"]) {
    const p = `${folder}/${name}.${ext}`;
    const pub = admin.storage.from(PHOTO_BUCKET).getPublicUrl(p).data.publicUrl;
    try {
      const h = await fetch(pub, { method: "HEAD" });
      if (h.ok) return pub;
    } catch { /* ignore */ }
    if (ext === "jpg") break; // only probe the common case cheaply
  }
  const res = await fetch(src, { headers, redirect: "follow" });
  if (!res.ok) return null;
  const ct = (res.headers.get("content-type") ?? "image/jpeg").split(";")[0];
  if (!ct.startsWith("image/")) return null;
  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.length < 500 || bytes.length > 5_000_000) return null;
  const path = `${folder}/${name}.${extFor(ct)}`;
  const { error } = await admin.storage.from(PHOTO_BUCKET).upload(path, bytes, {
    contentType: ct,
    cacheControl: "31536000",
    upsert: true,
  });
  if (error) {
    console.error("upload failed", path, error.message);
    return null;
  }
  return admin.storage.from(PHOTO_BUCKET).getPublicUrl(path).data.publicUrl;
}

/** Store a Places API (New) photo resource name (places/{id}/photos/{ref}). */
export function storePhotoRef(admin: SupabaseClient, ref: string, maxWidth = 1000): Promise<string | null> {
  return copyToBucket(admin, `${PLACES}/${ref}/media?maxWidthPx=${maxWidth}&key=${gkey()}`, "places", ref);
}

/** Store any still-valid image URL (used for the one-off backfill of legacy URLs). */
export function storeUrl(admin: SupabaseClient, url: string, folder: string, key: string): Promise<string | null> {
  return copyToBucket(admin, url, folder, key);
}

/** Fresh photo reference for a place (photo names can go stale). */
export async function freshPhotoRef(placeId: string): Promise<string | null> {
  try {
    const r = await fetch(`${PLACES}/places/${encodeURIComponent(placeId)}`, {
      headers: { "X-Goog-Api-Key": gkey(), "X-Goog-FieldMask": "photos" },
    });
    if (!r.ok) return null;
    const d = await r.json();
    return d.photos?.[0]?.name ?? null;
  } catch {
    return null;
  }
}

/** Photo reference of the city itself (for trip covers). */
export async function cityPhotoRef(city: string, country?: string): Promise<string | null> {
  try {
    const r = await fetch(`${PLACES}/places:searchText`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": gkey(), "X-Goog-FieldMask": "places.photos" },
      body: JSON.stringify({ textQuery: `${city}${country ? ", " + country : ""} city`, languageCode: "en", pageSize: 5 }),
    });
    if (!r.ok) return null;
    const d = await r.json();
    for (const p of d.places ?? []) if (p.photos?.[0]?.name) return p.photos[0].name;
    return null;
  } catch {
    return null;
  }
}
