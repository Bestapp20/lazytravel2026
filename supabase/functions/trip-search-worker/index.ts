// Background worker: processes queued (or stale) searches. Call with service role (pg_cron) or by owner with {id}.
import { json, optionsResponse } from "../_shared/cors.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";
import { runSearch } from "../_shared/tripfinder.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const db = serviceClient();
    const body = await req.json().catch(() => ({}));
    const auth = req.headers.get("Authorization") ?? "";
    const isService = auth === `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`;
    if (body.id) {
      if (!isService) {
        const { client } = await userClient(req);
        const { data } = await client.from("trip_searches").select("id").eq("id", body.id).maybeSingle();
        if (!data) return json({ error: "not found" }, 404);
      }
      await runSearch(db, body.id);
      return json({ ok: true });
    }
    if (!isService) return json({ error: "forbidden" }, 403);
    const stale = new Date(Date.now() - 3 * 60000).toISOString();
    const { data } = await db.from("trip_searches").select("id")
      .or(`status.eq.queued,and(status.in.(discovering,verifying),updated_at.lt.${stale})`).limit(5);
    for (const r of data ?? []) await runSearch(db, r.id);
    return json({ processed: (data ?? []).length });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
