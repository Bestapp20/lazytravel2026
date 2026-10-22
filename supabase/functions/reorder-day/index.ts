import { json, optionsResponse } from "../_shared/cors.ts";
import { cityCoverPhoto, placeDetails } from "../_shared/places.ts";
import { userClient } from "../_shared/supabase.ts";
import { categoryFromPlace, DURATION, fmtHM, Hours, normCat, parseHM, retimeInOrder, scheduleDay, Stop, suggestSlot } from "../_shared/scheduler.ts";

// Modes:
//  {day_id, item_ids}            keep the user's order, re-time, return per-item warnings
//  {day_id | trip_id, optimize}  re-sequence by time-of-day rules + geography (logistics stay fixed)
//  {day_id, suggest:{place_id, category?, duration_minutes?}}  best start time for a new stop
type Row = Record<string, any>;
const LOGI = new Set(["flight", "transport", "hotel"]);

async function ensureHours(client: any, rows: Row[]) {
  await Promise.all(rows.map(async (r) => {
    if (r.hours?.periods || !r.google_place_id || LOGI.has(r.category)) return;
    const d = await placeDetails(r.google_place_id).catch(() => null);
    if (!d) return;
    r.hours = d.hours ?? { periods: [] , unknown: true };
    const cat = r.category === "attraction" || ["food", "nature", "shopping", "nightlife"].includes(r.category)
      ? categoryFromPlace(d.types, d.name) : r.category;
    r.category = cat === "attraction" && r.category !== "attraction" ? normCat(r.category) : cat;
    await client.from("items").update({ hours: d.hours ?? null, category: r.category }).eq("id", r.id);
  }));
}

const toStop = (r: Row, keepFixed: boolean): Stop => ({
  key: r.id, name: r.place_name ?? "", category: r.category, lat: r.lat, lng: r.lng,
  hours: (r.hours?.periods ? r.hours : null) as Hours,
  duration: r.duration_minutes ?? DURATION[normCat(r.category)],
  fixedStart: keepFixed && LOGI.has(r.category) ? parseHM(r.start_time) : null,
});

async function loadDay(client: any, dayId: string) {
  const { data: day } = await client.from("days").select("id,date,trip_id").eq("id", dayId).single();
  const { data: items } = await client.from("items").select("*").eq("day_id", dayId).order("sort_order");
  return { day, items: (items ?? []) as Row[] };
}

async function optimizeDay(client: any, dayId: string) {
  const { day, items } = await loadDay(client, dayId);
  if (!day || !items.length) return { day_id: dayId, changed: 0 };
  await ensureHours(client, items);
  const before = items.map((r) => `${(r.start_time ?? "").slice(0, 5)} ${r.place_name}`);
  const { slots, dropped } = scheduleDay(items.map((r) => toStop(r, true)), day.date);
  // Places with no fitting slot today are kept (never deleted) at the end, flagged.
  const order = [...slots.map((s) => ({ s, r: items.find((x) => x.id === s.key)! })), ...dropped.map((d) => ({ s: null, r: items.find((x) => x.id === d.key)! }))];
  for (let i = 0; i < order.length; i++) {
    const { s, r } = order[i];
    const upd: Row = { sort_order: i };
    if (s && !LOGI.has(r.category)) {
      upd.start_time = fmtHM(s.start); upd.end_time = fmtHM(s.end); upd.ai_tip = s.tip; upd.category = s.category;
    } else if (!s) upd.ai_tip = "⚠️ לא נמצא חלון שמתאים לשעות הפתיחה ביום הזה. שקלו להעביר ליום אחר";
    await client.from("items").update(upd).eq("id", r.id);
  }
  const after = order.map(({ s, r }) => `${s ? fmtHM(s.start) : "--:--"} ${r.place_name}`);
  return { day_id: dayId, date: day.date, before, after, dropped: dropped.map((d) => d.name) };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  try {
    const { client } = await userClient(req);
    const body = await req.json() as Row;
    const { day_id, item_ids, optimize, trip_id, suggest } = body;

    if (body.cover && trip_id) {
      const { data: t } = await client.from("trips").select("cover_image_url,destinations,title").eq("id", trip_id).single();
      if (!t) return json({ error: "trip not found" }, 404);
      if (t.cover_image_url && !body.refresh_cover) return json({ cover_image_url: t.cover_image_url });
      const d0 = (t.destinations ?? [])[0] ?? {};
      const cover = await cityCoverPhoto(d0.city ?? t.title, d0.country);
      if (cover) await client.from("trips").update({ cover_image_url: cover }).eq("id", trip_id);
      return json({ cover_image_url: cover });
    }

    if (optimize) {
      let ids: string[] = day_id ? [day_id] : [];
      if (trip_id) {
        const { data } = await client.from("days").select("id").eq("trip_id", trip_id).order("day_index");
        ids = (data ?? []).map((d: Row) => d.id);
        // Backfill / repair the cover with the destination's own Places photo.
        const { data: t } = await client.from("trips").select("cover_image_url,destinations,title").eq("id", trip_id).single();
        if (t && (!t.cover_image_url || body.refresh_cover)) {
          const d0 = (t.destinations ?? [])[0] ?? {};
          const cover = await cityCoverPhoto(d0.city ?? t.title, d0.country);
          if (cover) await client.from("trips").update({ cover_image_url: cover }).eq("id", trip_id);
        }
      }
      const days = [];
      for (const id of ids) days.push(await optimizeDay(client, id));
      return json({ ok: true, days });
    }

    if (suggest) {
      const { day, items } = await loadDay(client, day_id);
      if (!day) return json({ error: "day not found" }, 404);
      await ensureHours(client, items);
      const d = suggest.place_id ? await placeDetails(suggest.place_id).catch(() => null) : null;
      const cat = suggest.category && !["food", "nature", "shopping", "nightlife", "attraction"].includes(suggest.category)
        ? normCat(suggest.category) : categoryFromPlace(d?.types, d?.name ?? "") ?? normCat(suggest.category);
      const stop: Stop = { key: "new", name: d?.name ?? "", category: cat, lat: d?.lat, lng: d?.lng, hours: d?.hours as Hours,
        duration: suggest.duration_minutes ?? DURATION[cat] };
      const existing = items.filter((r) => parseHM(r.start_time) != null).map((r) => {
        const st = parseHM(r.start_time)!;
        return { start: st, end: st + (r.duration_minutes ?? 60), stop: toStop(r, false) };
      });
      const s = suggestSlot(stop, existing, day.date);
      return json({ start_time: fmtHM(s.start), tip: s.tip, warning: s.warning ?? null, category: cat, hours: d?.hours ?? null,
        duration_minutes: stop.duration });
    }

    if (!day_id || !Array.isArray(item_ids)) return json({ error: "day_id and item_ids required" }, 400);
    const { day, items } = await loadDay(client, day_id);
    if (!day) return json({ error: "day not found" }, 404);
    await ensureHours(client, items);
    const ordered = item_ids.map((id: string) => items.find((r) => r.id === id)).filter(Boolean) as Row[];
    const startRow = ordered.find((r) => !LOGI.has(r.category));
    const dayStart = Math.min(...items.map((r) => parseHM(r.start_time) ?? 9 * 60).filter((m) => m >= 6 * 60), 9 * 60);
    const slots = retimeInOrder(ordered.map((r) => toStop(r, true)), day.date, startRow ? dayStart : 9 * 60);
    const warnings: Row[] = [];
    for (let i = 0; i < ordered.length; i++) {
      const r = ordered[i], s = slots[i];
      const upd: Row = { sort_order: i };
      if (!LOGI.has(r.category)) { upd.start_time = fmtHM(s.start); upd.end_time = fmtHM(s.end); upd.ai_tip = s.tip; }
      const { error } = await client.from("items").update(upd).eq("id", r.id).eq("day_id", day_id);
      if (error) return json({ error: error.message }, 400);
      if (s.warning) warnings.push({ item_id: r.id, name: r.place_name, start_time: fmtHM(s.start), warning: s.warning });
    }
    return json({ ok: true, warnings });
  } catch (err) {
    if (err instanceof Response) return err;
    return json({ error: String(err) }, 500);
  }
});
