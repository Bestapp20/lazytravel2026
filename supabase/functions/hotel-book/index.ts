import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { book } from "../_shared/liteapi.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { userId } = await userClient(req);
    const b = await req.json();
    const db = serviceClient();
    const { data: bk } = await db.from("hotel_bookings").select("*").eq("id", b.booking_id).eq("user_id", userId).maybeSingle();
    if (!bk) return json({ error: "booking not found" }, 404);
    if (bk.status === "confirmed") return json({ status: "confirmed", booking_id: bk.booking_id });
    const r = await book({
      prebookId: bk.prebook_id, transactionId: bk.transaction_id,
      firstName: String(b.first_name), lastName: String(b.last_name), email: String(b.email),
    });
    await db.from("hotel_bookings").update({
      status: String(r.status ?? "confirmed").toLowerCase(), booking_id: r.bookingId, raw: r,
    }).eq("id", bk.id);
    return json({ status: r.status, booking_id: r.bookingId, confirmation: r.hotelConfirmationCode });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String((err as Error).message ?? err) }, 500);
  }
});
