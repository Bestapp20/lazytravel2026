// booking-manage: poll (cron), refresh, quote, cancel, resend e-mail. verify_jwt = true.
import {
  corsHeaders, json, Kind, pollAll, sendConfirmationEmail, serviceClient, syncRow, TABLE, userClient,
} from "../_shared/bookings.ts";
import { flightBookingCancel, flightCancelQuote, hotelBookingCancel } from "../_shared/liteapi.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const action = body.action ?? "poll";
    const db = serviceClient();

    if (action === "poll") return json({ ok: true, results: await pollAll(db) });

    const u = await userClient(req);
    if (!u) return json({ error: "Unauthorized" }, 401);
    const kind = body.kind as Kind;
    if (!TABLE[kind] || !body.id) return json({ error: "kind/id required" }, 400);
    // RLS ("own bookings read") guarantees the caller owns the row.
    const { data: row } = await u.client.from(TABLE[kind]).select("*").eq("id", body.id).maybeSingle();
    if (!row) return json({ error: "not_found" }, 404);

    if (action === "refresh") return json({ ok: true, ...(await syncRow(db, kind, row)) });

    if (action === "resend_email") {
      const { data: fresh } = await db.from(TABLE[kind]).select("*").eq("id", row.id).single();
      return json({ ok: true, ...(await sendConfirmationEmail(db, kind, fresh, true)) });
    }

    if (action === "quote") {
      if (kind === "flight" && row.booking_id && row.status !== "cancelled") {
        return json({ ok: true, cancellable: true, quote: await flightCancelQuote(row.booking_id) });
      }
      return json({ ok: true, cancellable: kind === "hotel" && row.status === "confirmed" });
    }

    if (action === "cancel") {
      if (!row.booking_id || row.status === "cancelled") return json({ error: "not_cancellable" }, 409);
      if (kind === "hotel" && row.raw?.cancellationPolicies?.refundableTag === "NRFN") {
        // Still allowed by the API (charges apply), the app warns the user first.
      }
      const res = kind === "hotel" ? await hotelBookingCancel(row.booking_id) : await flightBookingCancel(row.booking_id);
      await db.from(TABLE[kind]).update({ cancel_info: { source: "user", result: res }, status_synced_at: null }).eq("id", row.id);
      const { data: fresh } = await db.from(TABLE[kind]).select("*").eq("id", row.id).single();
      const synced = await syncRow(db, kind, fresh);
      return json({ ok: true, cancel: res, ...synced });
    }
    return json({ error: "unknown_action" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
