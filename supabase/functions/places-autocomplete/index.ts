import { json, optionsResponse } from "../_shared/cors.ts";
import { autocomplete } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    await userClient(req);
    const body = req.method === "GET"
      ? Object.fromEntries(new URL(req.url).searchParams)
      : await req.json();
    const input = String(body.input ?? body.query ?? "").trim();
    if (input.length < 2) return json({ predictions: [] });
    const types = String(body.types ?? "(cities)");
    const data = await autocomplete(input, types);
    return json(data);
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
