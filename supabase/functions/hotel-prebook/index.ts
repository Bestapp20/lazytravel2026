import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { isSandbox, prebook } from "../_shared/liteapi.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client, userId } = await userClient(req);
    const { offer_id } = await req.json();
    const { data: offer } = await client.from("trip_offers").select("*").eq("id", offer_id).maybeSingle();
    if (!offer) return json({ error: "offer not found" }, 404);
    const p = await prebook(offer.hotel_offer_id);
    const { data: bk, error } = await serviceClient().from("hotel_bookings").insert({
      user_id: userId, offer_id, prebook_id: p.prebookId, transaction_id: p.transactionId,
      hotel_name: offer.hotel_name, checkin: offer.checkin, checkout: offer.checkout,
      price: Number(p.price), currency: p.currency, sandbox: isSandbox(),
    }).select("id").single();
    if (error) throw error;
    return json({
      booking_id: bk.id, prebook_id: p.prebookId, transaction_id: p.transactionId, secret_key: p.secretKey,
      price: Number(p.price), currency: p.currency, sandbox: isSandbox(),
      cancellation_changed: p.cancellationChanged, price_changed: Number(p.priceDifferencePercent ?? 0) !== 0,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String((err as Error).message ?? err) }, 500);
  }
});
