import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client, userId } = await userClient(req);
    const { trip_id, email } = await req.json();
    const normalized = String(email ?? "").trim().toLowerCase();
    if (!trip_id || !normalized) return json({ error: "trip_id and email required" }, 400);

    const { data: membership } = await client
      .from("trip_members")
      .select("role")
      .eq("trip_id", trip_id)
      .eq("user_id", userId)
      .maybeSingle();
    if (membership?.role !== "owner") {
      return json({ error: "Only the owner can invite" }, 403);
    }

    const admin = serviceClient();
    const { data: existingId } = await admin.rpc("find_user_id_by_email", {
      p_email: normalized,
    });

    const { error: inviteErr } = await admin.from("trip_invites").insert({
      trip_id,
      email: normalized,
      invited_by: userId,
      role: "viewer",
    });
    if (inviteErr) return json({ error: inviteErr.message }, 400);

    if (existingId) {
      const { error: memErr } = await admin.from("trip_members").upsert({
        trip_id,
        user_id: existingId,
        role: "viewer",
        invited_email: normalized,
      });
      if (memErr) return json({ error: memErr.message }, 400);
      await admin
        .from("trip_invites")
        .update({ status: "accepted" })
        .eq("trip_id", trip_id)
        .eq("email", normalized);
      return json({ ok: true, status: "added_existing_user" });
    }

    try {
      await admin.auth.admin.inviteUserByEmail(normalized, {
        data: { invited_trip_id: trip_id },
        redirectTo: "io.lazytravel.app://login-callback/",
      });
    } catch (e) {
      console.error("inviteUserByEmail", e);
    }

    return json({ ok: true, status: "invite_pending" });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
