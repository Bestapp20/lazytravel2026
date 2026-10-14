import { json, optionsResponse } from "../_shared/cors.ts";
import { INTEREST_QUERIES, textSearch } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client } = await userClient(req);
    const body = await req.json();
    const { data: trip, error } = await client
      .from("trips")
      .select("id, destinations, hotel, kosher")
      .eq("id", body.trip_id)
      .maybeSingle();
    if (error || !trip) return json({ error: "Trip not found" }, 404);

    const dest = Array.isArray(trip.destinations) ? trip.destinations[0] : null;
    const city = dest?.city ?? "";
    const hotel = trip.hotel as { lat?: number; lng?: number } | null;
    const interest = String(body.interest ?? "attractions");
    const q = INTEREST_QUERIES[interest] ?? interest;
    const location = hotel?.lat != null ? { lat: hotel.lat, lng: hotel.lng } : undefined;
    const kosherExtra = trip.kosher ? " kosher" : "";
    const results = await textSearch(`${q}${kosherExtra} in ${city}`, location);
    return json({ results });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
