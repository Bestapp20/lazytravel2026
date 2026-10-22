import { json, optionsResponse } from "../_shared/cors.ts";
import { photoMediaUri, placeDetails, placeDetailsFull, textSearch } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    await userClient(req);
    const body = await req.json();
    if (body.place_id) {
      if (body.full) {
        return json({ result: await placeDetailsFull(String(body.place_id), String(body.lang ?? "he")) });
      }
      const details = await placeDetails(String(body.place_id));
      return json({ result: details });
    }
    const query = String(body.query ?? "").trim();
    if (!query) return json({ results: [] });
    const location = body.lat != null && body.lng != null
      ? { lat: Number(body.lat), lng: Number(body.lng) }
      : undefined;
    let results = await textSearch(query, location);
    const limit = Number(body.limit ?? 0);
    if (limit > 0) results = results.slice(0, limit);
    if (body.with_photos) {
      results = await Promise.all(results.map(async (r) => ({
        ...r,
        photo_url: r.photo_reference ? await photoMediaUri(r.photo_reference, 600) : null,
      })));
    }
    return json({ results });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
