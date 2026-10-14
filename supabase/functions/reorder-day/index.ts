import { json, optionsResponse } from "../_shared/cors.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client } = await userClient(req);
    const { day_id, item_ids } = await req.json() as {
      day_id: string;
      item_ids: string[];
    };
    if (!day_id || !Array.isArray(item_ids)) {
      return json({ error: "day_id and item_ids required" }, 400);
    }
    for (let i = 0; i < item_ids.length; i++) {
      const { error } = await client
        .from("items")
        .update({ sort_order: i })
        .eq("id", item_ids[i])
        .eq("day_id", day_id);
      if (error) return json({ error: error.message }, 400);
    }
    return json({ ok: true });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
