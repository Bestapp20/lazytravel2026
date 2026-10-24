// booking-webhook: receiver for Nuitee Connect webhooks (booking.book / booking.cancel / flight.book.*).
// verify_jwt = false (the sender can't send a Supabase JWT); protected by a secret in the URL: ?s=<secret>
// stored in public.webhook_secrets. The payload is NOT trusted: we only read the booking id from it
// and re-fetch the live booking from LiteAPI.
import { corsHeaders, json, Kind, serviceClient, syncRow, TABLE } from "../_shared/bookings.ts";

function findBookingId(p: any): string | null {
  const c = [p?.response?.bookingId, p?.response?.data?.bookingId, p?.response?.data?.[0]?.booking?.bookingId,
    p?.request?.bookingId, p?.bookingId, p?.data?.bookingId, p?.response?.booking?.bookingId];
  return c.find((x) => typeof x === "string" && x) ?? null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const db = serviceClient();
  const s = new URL(req.url).searchParams.get("s");
  const { data: sec } = await db.from("webhook_secrets").select("secret").eq("name", "nuitee").maybeSingle();
  if (!s || !sec || s !== sec.secret) return json({ error: "forbidden" }, 403);
  const payload = await req.json().catch(() => ({}));
  const event = String(payload?.event ?? payload?.type ?? payload?.eventType ?? "");
  const id = findBookingId(payload);
  if (!id) return json({ ok: true, ignored: "no_booking_id", event });
  for (const kind of ["hotel", "flight"] as Kind[]) {
    const { data: row } = await db.from(TABLE[kind]).select("*").eq("booking_id", id).maybeSingle();
    if (row) return json({ ok: true, event, kind, ...(await syncRow(db, kind, row)) });
  }
  return json({ ok: true, ignored: "unknown_booking", event });
});
