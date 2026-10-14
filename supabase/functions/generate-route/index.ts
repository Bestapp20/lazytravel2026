import { json, optionsResponse } from "../_shared/cors.ts";
import { INTEREST_QUERIES, PlaceHit, textSearch } from "../_shared/places.ts";
import { serviceClient, userClient } from "../_shared/supabase.ts";

type Destination = {
  city: string;
  country?: string;
  place_id?: string;
  lat?: number;
  lng?: number;
  flag?: string;
};

type Hotel = {
  name: string;
  place_id?: string;
  lat?: number;
  lng?: number;
  address?: string;
};

type Payload = {
  destination: Destination;
  extra_cities?: Destination[];
  start_date: string;
  end_date: string;
  adults?: number;
  kids?: number;
  kid_ages?: number[];
  companion_type?: string;
  pace?: string;
  budget_tier?: string;
  budget_total?: number;
  currency?: string;
  kosher?: boolean;
  interests?: Record<string, number>;
  hotel?: Hotel | null;
  origin_city?: string;
  flight_ref?: string;
};

type LlmItem = {
  place_id: string;
  start_time: string;
  end_time?: string;
  duration_minutes?: number;
  notes?: string;
  ai_tip?: string;
  category?: string;
};

type LlmDay = {
  day_index: number;
  title?: string;
  items: LlmItem[];
};

function dayCount(start: string, end: string): number {
  const a = new Date(start);
  const b = new Date(end);
  const n = Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
  return Math.max(1, Math.min(n, 21));
}

function addDays(iso: string, n: number): string {
  const d = new Date(iso);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function categoryFromTypes(types?: string[]): string {
  if (!types?.length) return "attraction";
  if (types.includes("lodging")) return "hotel";
  if (types.includes("restaurant") || types.includes("cafe") || types.includes("food")) {
    return "food";
  }
  if (types.includes("bar") || types.includes("night_club")) return "nightlife";
  if (types.includes("museum")) return "museum";
  if (types.includes("park") || types.includes("natural_feature")) return "nature";
  if (types.includes("shopping_mall") || types.includes("store")) return "shopping";
  return "attraction";
}

async function gatherCandidates(p: Payload): Promise<PlaceHit[]> {
  const city = p.destination.city;
  const loc = p.hotel?.lat != null && p.hotel?.lng != null
    ? { lat: p.hotel.lat, lng: p.hotel.lng }
    : p.destination.lat != null && p.destination.lng != null
    ? { lat: p.destination.lat, lng: p.destination.lng }
    : undefined;
  const queries: string[] = [];
  const interests = p.interests ?? {};
  for (const [key, weight] of Object.entries(interests)) {
    if ((weight ?? 0) <= 0) continue;
    const base = INTEREST_QUERIES[key] ?? key;
    const kosher = p.kosher && (key === "food" || key === "nightlife") ? " kosher" : "";
    queries.push(`${base}${kosher} in ${city}`);
  }
  if (p.kosher) queries.push(`kosher restaurants in ${city}`);
  if (queries.length === 0) queries.push(`top attractions in ${city}`);
  for (const extra of p.extra_cities ?? []) {
    queries.push(`top attractions in ${extra.city}`);
  }

  const seen = new Set<string>();
  const out: PlaceHit[] = [];
  for (const q of queries.slice(0, 8)) {
    try {
      const hits = await textSearch(q, loc);
      for (const h of hits) {
        if (!h.place_id || seen.has(h.place_id)) continue;
        seen.add(h.place_id);
        out.push(h);
      }
    } catch (e) {
      console.error("places search failed", q, e);
    }
  }
  return out;
}

async function planWithLlm(
  p: Payload,
  days: number,
  candidates: PlaceHit[],
): Promise<LlmDay[]> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY is not set");
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  const hotelNote = p.hotel
    ? `Daily start AND end point is the hotel: ${p.hotel.name} (${p.hotel.lat}, ${p.hotel.lng}). Cluster nearby places. Do not put the hotel as a sightseeing item unless asked.`
    : "No hotel; pick a central first/last place per day.";

  const prompt = {
    model,
    temperature: 0.4,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content:
          "You are LAZYTRAVEL's itinerary planner. Return ONLY JSON of the form {\"days\":[{\"day_index\":1,\"title\":\"...\",\"items\":[...]}]}. Each item must use a place_id from the candidate list. Order items geographically. Respect kosher, kids, pace, and budget. Time slots between 09:00 and 21:00. Include a short Hebrew ai_tip for each item.",
      },
      {
        role: "user",
        content: JSON.stringify({
          destination: p.destination,
          extra_cities: p.extra_cities ?? [],
          start_date: p.start_date,
          end_date: p.end_date,
          days,
          adults: p.adults ?? 1,
          kids: p.kids ?? 0,
          kid_ages: p.kid_ages ?? [],
          companion_type: p.companion_type,
          pace: p.pace,
          budget_tier: p.budget_tier,
          budget_total: p.budget_total,
          kosher: p.kosher,
          interests: p.interests,
          hotel: p.hotel,
          hotel_rule: hotelNote,
          candidates: candidates.map((c) => ({
            place_id: c.place_id,
            name: c.name,
            address: c.address,
            lat: c.lat,
            lng: c.lng,
            rating: c.rating,
            types: c.types,
          })),
        }),
      },
    ],
  };

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(prompt),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`OpenAI error ${res.status}: ${t}`);
  }
  const data = await res.json();
  const content = data.choices?.[0]?.message?.content ?? "{}";
  const parsed = JSON.parse(content);
  return (parsed.days ?? []) as LlmDay[];
}

async function maybeWeather(lat?: number, lng?: number, days = 1) {
  const key = Deno.env.get("WEATHER_API_KEY");
  if (!key || lat == null || lng == null) return null;
  try {
    const url =
      `https://api.weatherapi.com/v1/forecast.json?key=${key}&q=${lat},${lng}&days=${Math.min(days, 10)}&aqi=no&alerts=no`;
    const res = await fetch(url);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { userId } = await userClient(req);
    const payload = (await req.json()) as Payload;
    if (!payload?.destination?.city || !payload.start_date || !payload.end_date) {
      return json({ error: "destination, start_date, end_date required" }, 400);
    }

    const daysN = dayCount(payload.start_date, payload.end_date);
    const candidates = await gatherCandidates(payload);
    if (candidates.length === 0) {
      return json({ error: "No places found. Check GOOGLE_PLACES_API_KEY." }, 502);
    }

    let plan: LlmDay[] = [];
    try {
      plan = await planWithLlm(payload, daysN, candidates);
    } catch (e) {
      console.error("LLM failed, using fallback clusters", e);
      const perDay = Math.max(3, Math.min(5, Math.ceil(candidates.length / daysN)));
      plan = Array.from({ length: daysN }, (_, i) => ({
        day_index: i + 1,
        title: `${payload.destination.city} — יום ${i + 1}`,
        items: candidates.slice(i * perDay, i * perDay + perDay).map((c, idx) => ({
          place_id: c.place_id,
          start_time: `${String(9 + idx * 2).padStart(2, "0")}:00`,
          duration_minutes: 90,
          category: categoryFromTypes(c.types),
          ai_tip: "הוסף הערה אישית למקום",
        })),
      }));
    }

    const byId = new Map(candidates.map((c) => [c.place_id, c]));
    const weather = await maybeWeather(
      payload.hotel?.lat ?? payload.destination.lat,
      payload.hotel?.lng ?? payload.destination.lng,
      daysN,
    );

    const admin = serviceClient();
    const dests = [payload.destination, ...(payload.extra_cities ?? [])];
    const { data: trip, error: tripErr } = await admin
      .from("trips")
      .insert({
        owner_id: userId,
        title: payload.destination.city,
        destinations: dests,
        start_date: payload.start_date,
        end_date: payload.end_date,
        travelers: (payload.adults ?? 1) + (payload.kids ?? 0),
        kids: payload.kids ?? 0,
        kid_ages: payload.kid_ages ?? [],
        companion_type: payload.companion_type,
        pace: payload.pace,
        budget_tier: payload.budget_tier,
        budget_total: payload.budget_total,
        currency: payload.currency ?? "ILS",
        kosher: payload.kosher ?? false,
        interests: payload.interests ?? {},
        hotel: payload.hotel ?? null,
        status: "planned",
        origin_city: payload.origin_city,
        generation_params: payload,
      })
      .select("id")
      .single();
    if (tripErr || !trip) return json({ error: tripErr?.message ?? "trip insert failed" }, 500);

    const forecastDays = weather?.forecast?.forecastday ?? [];

    for (let i = 0; i < daysN; i++) {
      const date = addDays(payload.start_date, i);
      const llmDay = plan.find((d) => d.day_index === i + 1) ?? plan[i];
      const w = forecastDays[i];
      const { data: dayRow, error: dayErr } = await admin
        .from("days")
        .insert({
          trip_id: trip.id,
          day_index: i + 1,
          date,
          title: llmDay?.title ?? `יום ${i + 1} — ${payload.destination.city}`,
          weather: w
            ? {
              temp_c: w.day?.avgtemp_c,
              condition: w.day?.condition?.text,
              icon: w.day?.condition?.icon,
            }
            : null,
        })
        .select("id")
        .single();
      if (dayErr || !dayRow) continue;

      const items = llmDay?.items ?? [];
      for (let s = 0; s < items.length; s++) {
        const it = items[s];
        const place = byId.get(it.place_id);
        if (!place) continue;
        const duration = it.duration_minutes ?? 90;
        await admin.from("items").insert({
          trip_id: trip.id,
          day_id: dayRow.id,
          place_name: place.name,
          google_place_id: place.place_id,
          category: it.category ?? categoryFromTypes(place.types),
          address: place.address,
          lat: place.lat,
          lng: place.lng,
          map_link: place.map_link,
          start_time: it.start_time || null,
          duration_minutes: duration,
          sort_order: s,
          notes: it.notes ?? null,
          ai_tip: it.ai_tip ?? null,
          rating: place.rating,
          price_level: place.price_level,
          photo_reference: place.photo_reference,
          estimated_cost: null,
        });
      }
    }

    return json({ trip_id: trip.id, candidate_count: candidates.length });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
