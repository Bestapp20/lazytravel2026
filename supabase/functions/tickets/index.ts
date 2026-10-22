import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { matchPlace, placeKey } from "../_shared/tickets.ts";

// POST {trip_id} or {item_ids:[...]} -> {offers: {item_id: Offer}}; matches cached 7 days in ticket_matches.
const TTL = 7 * 864e5;
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client } = await userClient(req);
    const body = await req.json();
    let q = client.from("items").select("id,place_name,category,lat,lng,trip_id");
    q = body.trip_id ? q.eq("trip_id", body.trip_id) : q.in("id", body.item_ids ?? []);
    const { data: items } = await q;
    if (!items?.length) return json({ offers: {} });
    const { data: trip } = await client.from("trips").select("destinations,title").eq("id", items[0].trip_id).single();
    const city = trip?.destinations?.[0]?.city ?? "";
    const svc = serviceClient();
    const keys = items.map((i: any) => placeKey(i.place_name ?? "", i.lat, i.lng));
    const { data: cached } = await svc.from("ticket_matches").select("*").in("place_key", keys);
    const byKey = new Map((cached ?? []).filter((c: any) => Date.now() - Date.parse(c.checked_at) < TTL).map((c: any) => [c.place_key, c]));
    const offers: Record<string, any> = {};
    await Promise.all(items.map(async (it: any, i: number) => {
      let row: any = byKey.get(keys[i]);
      if (!row) {
        const o = await matchPlace({ name: it.place_name ?? "", city, lat: it.lat, lng: it.lng, category: it.category ?? "" });
        row = { place_key: keys[i], provider: o.provider, partner_name: o.partner_name ?? null, product_id: o.product_id ?? null,
          title: o.title ?? null, url: o.url ?? null, price: o.price ?? null, currency: o.currency ?? null, confidence: o.confidence, checked_at: new Date().toISOString() };
        await svc.from("ticket_matches").upsert(row);
      }
      if (row.provider) offers[it.id] = row;
    }));
    return json({ offers });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
