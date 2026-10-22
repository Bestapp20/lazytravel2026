import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { runSearch } from "../_shared/tripfinder.ts";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client, userId } = await userClient(req);
    const b = await req.json();
    const row = {
      user_id: userId,
      origin: b.origin ?? null,
      destination: b.destination ? String(b.destination) : null,
      dest_lat: b.lat ?? null, dest_lng: b.lng ?? null,
      date_from: b.date_from, date_to: b.date_to,
      nights_min: Number(b.nights_min ?? 4), nights_max: Number(b.nights_max ?? b.nights_min ?? 4),
      adults: Number(b.adults ?? 2), children: Number(b.children ?? 0),
      budget: b.budget ?? null, currency: b.currency ?? "ILS",
      bag_mode: ["checked", "carryon", "trolley"].includes(b.bag_mode) ? b.bag_mode : "none",
      components: Array.isArray(b.components) && b.components.length ? b.components.filter((x: unknown) => ["flight", "hotel", "itinerary"].includes(String(x))) : ["flight", "hotel"],
    };
    const { data, error } = await client.from("trip_searches").insert(row).select("id").single();
    if (error) return json({ error: error.message }, 400);
    EdgeRuntime.waitUntil(runSearch(serviceClient(), data.id));
    return json({ id: data.id });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
