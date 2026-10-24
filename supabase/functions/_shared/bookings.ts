// Booking status sync, cancellation and confirmation e-mail (self-contained: one file to keep deploys small).
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";
import { flightBookingGet, hotelBookingGet } from "./liteapi.ts";

export type Kind = "hotel" | "flight";
export const TABLE: Record<Kind, string> = { hotel: "hotel_bookings", flight: "flight_bookings" };

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};
export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false, autoRefreshToken: false } });
}
export async function userClient(req: Request): Promise<{ client: SupabaseClient; userId: string } | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const client = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return { client, userId: data.user.id };
}

/** LiteAPI status -> our status column. */
export function normalizeStatus(kind: Kind, s: string | undefined | null): string {
  const u = String(s ?? "").toUpperCase();
  if (u.startsWith("CANCEL")) return "cancelled";
  if (u === "CONFIRMED") return "confirmed";
  if (u === "PENDING_CONFIRMATION" || u === "CREATED" || u === "PENDING") return "pending_confirmation";
  if (u === "FAILED" || u === "REJECTED") return "failed";
  return u ? u.toLowerCase() : (kind === "hotel" ? "confirmed" : "pending_confirmation");
}

function confirmationCode(kind: Kind, d: any): string | null {
  if (kind === "hotel") return d?.hotelConfirmationCode ?? d?.supplierBookingId ?? d?.clientReference ?? null;
  return d?.order?.reference?.airlineBookings?.[0]?.pnr || d?.airlineLocators?.[0]?.airlinePnr ||
    d?.order?.reference?.orderId || d?.ticketData?.confirmationId || null;
}

/** Fetch the live booking, update the row, send the confirmation mail on first confirmation. */
export async function syncRow(db: SupabaseClient, kind: Kind, row: any): Promise<{ id: string; status: string; changed: boolean; emailed?: string }> {
  const out = { id: row.id, status: row.status as string, changed: false, emailed: undefined as string | undefined };
  if (!row.booking_id) return out;
  try {
    const fresh = kind === "hotel" ? await hotelBookingGet(row.booking_id) : await flightBookingGet(row.booking_id);
    const status = normalizeStatus(kind, fresh?.status);
    const upd: Record<string, unknown> = {
      status, status_synced_at: new Date().toISOString(), sync_error: null,
      raw: { ...(row.raw ?? {}), ...fresh },
    };
    const code = confirmationCode(kind, fresh);
    if (code) upd.confirmation_code = code;
    if (status === "confirmed" && !row.confirmed_at) upd.confirmed_at = new Date().toISOString();
    if (status === "cancelled" && !row.cancelled_at) {
      upd.cancelled_at = new Date().toISOString();
      upd.cancel_info = { source: "sync", liteapi_status: fresh?.status, cancelIntentAt: fresh?.cancelIntentAt ?? null };
    }
    out.changed = status !== row.status;
    out.status = status;
    await db.from(TABLE[kind]).update(upd).eq("id", row.id);
    if (status === "confirmed" && !row.confirmation_email_sent_at) {
      const r = await sendConfirmationEmail(db, kind, { ...row, ...upd });
      out.emailed = r.status;
    }
  } catch (e) {
    await db.from(TABLE[kind]).update({ status_synced_at: new Date().toISOString(), sync_error: String((e as Error).message ?? e).slice(0, 300) }).eq("id", row.id);
  }
  return out;
}

/** Poll every non-final booking. Pending ones each run, confirmed ones at most every 6 h. */
export async function pollAll(db: SupabaseClient, limit = 40) {
  const results: unknown[] = [];
  const now = Date.now();
  for (const kind of ["hotel", "flight"] as Kind[]) {
    const { data } = await db.from(TABLE[kind]).select("*").not("booking_id", "is", null)
      .neq("status", "cancelled").order("status_synced_at", { ascending: true, nullsFirst: true }).limit(limit);
    for (const r of data ?? []) {
      const age = r.status_synced_at ? now - Date.parse(r.status_synced_at) : Infinity;
      const stale = r.status === "confirmed" ? 6 * 3600e3 : 4 * 60e3;
      if (age < stale) continue;
      results.push({ kind, ...(await syncRow(db, kind, r)) });
    }
  }
  return results;
}

// ───────────── Confirmation e-mail (Resend) ─────────────
// Needs the RESEND_API_KEY edge secret. MAIL_FROM defaults to Resend's shared sender (works only for the
// account owner's own address until a domain is verified). Sandbox bookings are only ever mailed to the allowlist.
const SANDBOX_ALLOW = ["edi1999.ef@gmail.com"];
const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

function emailFor(kind: Kind, row: any): string | null {
  const raw = row.raw ?? {};
  return raw.holder?.email ?? raw.email ?? raw.contact?.email ?? null;
}

export function renderEmail(kind: Kind, row: any): { subject: string; html: string } {
  const raw = row.raw ?? {};
  const code = row.confirmation_code ?? row.booking_id;
  const money = `${row.price ?? raw.price ?? ""} ${row.currency ?? raw.currency ?? ""}`.trim();
  let title: string, lines: [string, string][];
  if (kind === "hotel") {
    title = "ההזמנה שלך למלון אושרה";
    lines = [["מלון", row.hotel_name ?? raw.hotel?.name ?? ""], ["צ׳ק-אין", row.checkin ?? raw.checkin ?? ""],
      ["צ׳ק-אאוט", row.checkout ?? raw.checkout ?? ""], ["מחיר", money], ["מספר אישור", code]];
  } else {
    const segs = raw.journey?.segments ?? [];
    const route = segs.length ? `${segs[0].originCode} ← ${segs[0].destinationCode}` : "";
    title = "הטיסה שלך אושרה";
    lines = [["מסלול", route], ["יציאה", segs[0]?.departureTime ?? ""], ["מחיר", money], ["קוד הזמנה (PNR)", code]];
  }
  const rows = lines.filter(([, v]) => v).map(([k, v]) =>
    `<tr><td style="padding:6px 0;color:#667">${esc(k)}</td><td style="padding:6px 0;font-weight:600">${esc(v)}</td></tr>`).join("");
  const sandboxNote = row.sandbox ? `<p style="background:#fff3cd;padding:8px 12px;border-radius:8px">הזמנת בדיקה (Sandbox) – לא בוצע חיוב אמיתי.</p>` : "";
  const html = `<div dir="rtl" style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#1a2230">
<h2 style="color:#0b7a75">LazyTravel ✈️</h2><h3>${esc(title)}</h3>${sandboxNote}
<table style="width:100%;border-collapse:collapse">${rows}</table>
<p style="color:#667;font-size:13px">את כל ההזמנות אפשר לראות באפליקציה תחת ״ההזמנות שלי״.</p></div>`;
  return { subject: `${title} · LazyTravel`, html };
}

export async function sendConfirmationEmail(db: SupabaseClient, kind: Kind, row: any, force = false): Promise<{ status: string; to?: string; id?: string }> {
  const to = emailFor(kind, row);
  if (!to) return { status: "no_recipient" };
  if (row.sandbox && !SANDBOX_ALLOW.includes(to.toLowerCase())) return { status: "blocked_sandbox_recipient", to };
  if (row.confirmation_email_sent_at && !force) return { status: "already_sent", to };
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return { status: "skipped_no_resend_key", to };
  const { subject, html } = renderEmail(kind, row);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST", headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: Deno.env.get("MAIL_FROM") ?? "LazyTravel <onboarding@resend.dev>", to: [to], subject, html }),
  });
  const d = await res.json().catch(() => ({}));
  if (!res.ok) {
    await db.from(TABLE[kind]).update({ sync_error: `mail: ${d?.message ?? res.status}`.slice(0, 300) }).eq("id", row.id);
    return { status: `error_${res.status}`, to };
  }
  await db.from(TABLE[kind]).update({ confirmation_email_sent_at: new Date().toISOString() }).eq("id", row.id);
  return { status: "sent", to, id: d.id };
}
