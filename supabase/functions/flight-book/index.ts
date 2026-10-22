import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { flightBook } from "../_shared/liteapi.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { userId } = await userClient(req);
    const b = await req.json();
    const db = serviceClient();
    const { data: bk } = await db.from("flight_bookings").select("*").eq("id", b.booking_id).eq("user_id", userId).maybeSingle();
    if (!bk) return json({ error: "booking not found" }, 404);
    if (bk.booking_id) return json({ status: bk.status, booking_id: bk.booking_id, booking_ref: bk.raw?.bookingRef ?? null });
    const r = await flightBook(bk.prebook_id, bk.transaction_id);
    const pnr = r.journey?.pnr ?? r.order?.reference?.airlineBookings?.[0]?.airlinePnr ?? null;
    await db.from("flight_bookings").update({ status: String(r.status ?? "unknown").toLowerCase(), booking_id: r.bookingId, raw: r }).eq("id", bk.id);
    return json({ status: r.status, booking_id: r.bookingId, pnr, booking_ref: r.bookingRef });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String((err as Error).message ?? err) }, 500);
  }
});
