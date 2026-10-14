import { corsHeaders, json, optionsResponse } from "../_shared/cors.ts";
import { photoMediaUri, photoUrl } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    await userClient(req);
    const url = new URL(req.url);
    const ref = url.searchParams.get("ref") ?? "";
    const maxwidth = Number(url.searchParams.get("maxwidth") ?? "800");
    if (!ref) return json({ error: "missing ref" }, 400);
    if (url.searchParams.get("uri") === "1") {
      return json({ uri: await photoMediaUri(ref, maxwidth) });
    }
    const upstream = await fetch(photoUrl(ref, maxwidth));
    const bytes = await upstream.arrayBuffer();
    return new Response(bytes, {
      status: upstream.status,
      headers: {
        ...corsHeaders,
        "Content-Type": upstream.headers.get("Content-Type") ?? "image/jpeg",
        "Cache-Control": "public, max-age=86400",
      },
    });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
