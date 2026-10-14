import { json, optionsResponse } from "../_shared/cors.ts";
import { placeDetails, textSearch } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    await userClient(req);
    const body = await req.json();
    if (body.place_id) {
      const details = await placeDetails(String(body.place_id));
      return json({ result: details });
    }
    const query = String(body.query ?? "").trim();
    if (!query) return json({ results: [] });
    const location = body.lat != null && body.lng != null
      ? { lat: Number(body.lat), lng: Number(body.lng) }
      : undefined;
    const results = await textSearch(query, location);
    return json({ results });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
