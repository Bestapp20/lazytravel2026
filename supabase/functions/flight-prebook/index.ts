// Re-prices the offer's flight live (LiteAPI offers expire), prebooks with the payment SDK, attaches checked bags if asked.
import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { BagMode, flightAttachCheckedBags, flightLive, flightPrebook, isSandbox } from "../_shared/liteapi.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client, userId } = await userClient(req);
    const b = await req.json();
    const { data: offer } = await client.from("trip_offers").select("*").eq("id", b.offer_id).maybeSingle();
    if (!offer?.flight?.origin) return json({ error: "offer has no flight" }, 404);
    const { data: s0 } = await client.from("trip_searches").select("adults,children,bag_mode,currency").eq("id", offer.search_id).single();
    const s = s0 as any;
    const passengers = (b.passengers ?? []) as any[];
    if (passengers.length !== s.adults + s.children) return json({ error: `נדרשים פרטי ${s.adults + s.children} נוסעים` }, 400);
    const mode = (b.with_bags ? "checked" : (s.bag_mode ?? "none")) as BagMode;
    const f = offer.flight;
    const live = await flightLive({ origin: f.origin, destination: f.destination, depart: f.depart, ret: f.ret,
      adults: s.adults, children: s.children, currency: s.currency ?? "ILS", mode });
    if (!live) return json({ error: "הטיסה כבר לא זמינה, חפש שוב" }, 409);
    let pre = await flightPrebook({
      offerId: live.offer_id, usePaymentSdk: true, contact: b.contact,
      passengers: passengers.map((p) => ({ ...p, passengerType: p.passengerType ?? 0 })),
    });
    let bagsAttached = false;
    if (mode === "checked" && !live.checked_included) {
      pre = { ...pre, ...(await flightAttachCheckedBags(pre, passengers.length)) };
      bagsAttached = true;
    }
    const { data: bk, error } = await serviceClient().from("flight_bookings").insert({
      user_id: userId, offer_id: offer.id, prebook_id: pre.prebookId, transaction_id: pre.transactionId,
      with_bags: mode === "checked", price: Number(pre.price), currency: pre.currency, sandbox: isSandbox(),
    }).select("id").single();
    if (error) throw error;
    return json({
      booking_id: bk.id, secret_key: pre.secretKey, price: Number(pre.price), currency: pre.currency, sandbox: isSandbox(),
      bags_attached: bagsAttached, baggage_amount: pre.booking?.pricing?.baggageAmount ?? 0, fare_family: live.fare_family,
      segments: live.segments, live,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String((err as Error).message ?? err) }, 500);
  }
});
