// Cheapest Trip Finder pipeline. Stages are pluggable: discovery (flights, later) → hotels → rank.
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";
import { BagMode, flightLive, hotelRates, HotelRate, LiveFlight } from "./liteapi.ts";
import { aviasalesLink, cheapestDays, Fare, Place, resolvePlace, roundTrips } from "./travelpayouts.ts";

type Search = Record<string, any>;
export type Candidate = {
  destination: string; lat: number; lng: number; checkin: string; checkout: string; nights: number;
  flight_price?: number; flight?: any; orig?: string; dcode?: string;
};

const iso = (d: Date) => d.toISOString().slice(0, 10);
const addDays = (s: string, n: number) => { const d = new Date(s + "T00:00:00Z"); d.setUTCDate(d.getUTCDate() + n); return iso(d); };

async function cached<T>(db: SupabaseClient, key: string, ttlMin: number, fn: () => Promise<T>): Promise<T> {
  const { data } = await db.from("price_cache").select("payload,expires_at").eq("key", key).maybeSingle();
  if (data && new Date(data.expires_at) > new Date()) return data.payload as T;
  const v = await fn();
  await db.from("price_cache").upsert({ key, payload: v, expires_at: new Date(Date.now() + ttlMin * 60000).toISOString() });
  return v;
}

/** Stage 1: discovery. Flights (Travelpayouts cache) pick destination + dates; hotel stage verifies live. */
async function discover(db: SupabaseClient, s: Search): Promise<Candidate[]> {
  const pax = s.adults + s.children;
  const origin = s.origin ? (await cached(db, `tp:place:${s.origin}`, 43200, () => resolvePlace(s.origin)))?.code ?? "TLV" : "TLV";
  let dest: Place | null = null;
  if (s.destination) {
    dest = await cached(db, `tp:place:${s.destination}`, 43200, () => resolvePlace(s.destination));
    if (!dest) throw new Error("לא נמצא היעד");
    await db.from("trip_searches").update({ dest_lat: dest.lat, dest_lng: dest.lng }).eq("id", s.id);
  }
  const fares = await cached(db, `tp:rt:${origin}:${dest?.code ?? "*"}:${s.date_from}:${s.date_to}:${s.currency}`, 360,
    () => roundTrips({ origin, destination: dest?.code, from: s.date_from, to: s.date_to, currency: s.currency }));
  const nightsOf = (f: Fare) => (Date.parse(f.ret) - Date.parse(f.depart)) / 86400000;
  const fit = fares.filter((f) => f.depart >= s.date_from && f.ret <= s.date_to &&
    nightsOf(f) >= s.nights_min && nightsOf(f) <= s.nights_max &&
    (!s.budget || f.price * pax < Number(s.budget) * 0.75)).sort((a, b) => a.price - b.price);

  const out: Candidate[] = [];
  if (dest) {
    const seen = new Set<string>();
    for (const f of fit) { const k = f.depart + f.ret; if (seen.has(k)) continue; seen.add(k);
      out.push({ destination: dest.name, lat: dest.lat, lng: dest.lng, checkin: f.depart, checkout: f.ret, nights: nightsOf(f), flight_price: f.price * pax, flight: f, orig: origin, dcode: dest.code });
      if (out.length >= 6) break; }
    if (out.length) return out;
    // No cached round trips: fall back to the cheapest one-way days (or an even grid) without a flight price.
    const days = await cached(db, `tp:days:${origin}:${dest.code}:${s.date_from}:${s.date_to}:${s.currency}`, 360,
      () => cheapestDays({ origin, destination: dest!.code, from: s.date_from, to: s.date_to, currency: s.currency }));
    const span = (Date.parse(s.date_to) - Date.parse(s.date_from)) / 86400000;
    let starts = Object.entries(days).sort((a, b) => a[1] - b[1]).map(([d]) => d)
      .filter((d) => (Date.parse(s.date_to) - Date.parse(d)) / 86400000 >= s.nights_min).slice(0, 4);
    if (!starts.length) starts = [0, 1, 2, 3].map((i) => addDays(s.date_from, Math.round(((span - s.nights_min) * i) / 3))).filter((d, i, a) => a.indexOf(d) === i);
    for (const d of starts) for (const n of [...new Set([s.nights_min, s.nights_max])]) {
      if (addDays(d, n) > s.date_to) continue;
      out.push({ destination: dest.name, lat: dest.lat, lng: dest.lng, checkin: d, checkout: addDays(d, n), nights: n, orig: origin, dcode: dest.code,
        flight_price: days[d] ? days[d] * 2 * pax : undefined, flight: days[d] ? { estimate: "one-way x2", origin, destination: dest.code } : undefined });
    }
    if (!out.length) throw new Error("טווח התאריכים קצר ממספר הלילות");
    return out.slice(0, 8);
  }
  // Anywhere: cheapest destinations, one fare each.
  const seen = new Set<string>();
  for (const f of fit) {
    if (seen.has(f.destination)) continue;
    const pl = await cached(db, `tp:place:${f.destination}`, 43200, () => resolvePlace(f.destination));
    if (!pl) continue;
    seen.add(f.destination);
    out.push({ destination: pl.name, lat: pl.lat, lng: pl.lng, checkin: f.depart, checkout: f.ret, nights: nightsOf(f), flight_price: f.price * pax, flight: f, orig: origin, dcode: f.destination });
    if (out.length >= 6) break;
  }
  if (!out.length) throw new Error("לא נמצאו טיסות זולות בטווח הזה");
  return out;
}

/** Stage 1b (bag filter on): live LiteAPI pricing for up to 6 date pairs, in parallel, cached 30 min. */
async function liveFlights(db: SupabaseClient, s: Search, cands: Candidate[], mode: BagMode): Promise<Candidate[]> {
  const cur = String(s.currency ?? "ILS");
  const top = cands.filter((c) => c.orig && c.dcode).slice(0, 6);
  const res = await Promise.all(top.map(async (c) => {
    const k = `lf:${c.orig}:${c.dcode}:${c.checkin}:${c.checkout}:${s.adults}:${s.children}:${mode}:${cur}`;
    const lf = await cached<LiveFlight | null>(db, k, 30, () => flightLive({
      origin: c.orig!, destination: c.dcode!, depart: c.checkin, ret: c.checkout, adults: s.adults, children: s.children, currency: cur, mode,
    })).catch((e) => { console.error("flightLive", e); return null; });
    if (!lf) return null;
    return { ...c, flight_price: lf.total, flight: { ...(c.flight ?? {}), live: lf, provider: "liteapi", bag_mode: mode } } as Candidate;
  }));
  const ok = res.filter((c): c is Candidate => !!c);
  if (!ok.length) throw new Error("לא נמצאו טיסות עם הכבודה המבוקשת בתאריכים הזולים");
  return ok;
}

export async function runSearch(db: SupabaseClient, id: string): Promise<void> {
  const { data: s } = await db.from("trip_searches").select("*").eq("id", id).single();
  if (!s) return;
  const set = (v: Record<string, unknown>) => db.from("trip_searches").update(v).eq("id", id);
  try {
    await set({ status: "discovering", progress: 10, error: null });
    let cands = await discover(db, s);
    // Pax-correct Aviasales links (documented format) for every candidate.
    for (const c of cands) if (c.orig && c.dcode) {
      c.flight = { ...(c.flight ?? {}), origin: c.orig, destination: c.dcode, depart: c.checkin, ret: c.checkout,
        link: aviasalesLink(c.orig, c.dcode, c.checkin, c.checkout, s.adults, s.children) };
    }
    const mode = (s.bag_mode ?? "none") as BagMode;
    if (mode !== "none") cands = await liveFlights(db, s, cands, mode);
    await set({ status: "verifying", progress: 25 });
    const rows: any[] = [];
    let done = 0;
    const errs: string[] = [];
    await Promise.all(cands.map(async (c) => {
      const k = `lite:${c.lat.toFixed(3)},${c.lng.toFixed(3)}:${c.checkin}:${c.checkout}:${s.adults}:${s.children}:${s.currency}`;
      const rates = await cached<HotelRate[]>(db, k, 30, () => hotelRates({
        lat: c.lat, lng: c.lng, checkin: c.checkin, checkout: c.checkout, adults: s.adults, children: s.children, currency: s.currency,
      })).catch((e) => { console.error(e); errs.push(String((e as Error).message ?? e)); return [] as HotelRate[]; });
      for (const r of rates) {
        const total = r.price + (c.flight_price ?? 0);
        if (s.budget && total > Number(s.budget)) continue;
        rows.push({
          search_id: id, destination: c.destination, dest_lat: c.lat, dest_lng: c.lng, checkin: c.checkin, checkout: c.checkout, nights: c.nights,
          flight_price: c.flight_price ?? null, flight: c.flight ?? null,
          hotel_id: r.hotel_id, hotel_name: r.hotel_name, hotel_stars: r.stars, hotel_rating: r.rating,
          hotel_photo: r.photo, hotel_address: r.address, room_name: r.room_name, board_name: r.board_name,
          refundable: r.refundable, hotel_offer_id: r.offer_id, hotel_price: r.price, total, currency: r.currency,
        });
      }
      done++;
      await set({ progress: 25 + Math.round((65 * done) / cands.length) });
    }));
    // Rank: price per night with a quality bonus; one offer per hotel.
    const score = (r: any) => (r.total / r.nights) * (1 - Math.min(0.25, ((r.hotel_rating ?? 7) - 7) * 0.08));
    rows.sort((a, b) => score(a) - score(b));
    const seen = new Set<string>();
    const perDest: Record<string, number> = {};
    const top = rows.filter((r) => {
      if (seen.has(r.hotel_id) || (perDest[r.destination] ?? 0) >= (s.destination ? 10 : 3)) return false;
      seen.add(r.hotel_id); perDest[r.destination] = (perDest[r.destination] ?? 0) + 1; return true;
    }).slice(0, 10);
    top.forEach((r, i) => {
      r.rank = i + 1;
      const perNight = Math.round(r.total / r.nights);
      const bagNote = r.flight?.live?.bag_note;
      r.ai_reason = (bagNote ? `🧳 ${bagNote}. ` : "") + (r.flight_price ? `טיסה ${Math.round(r.flight_price)} + מלון ${Math.round(r.hotel_price)}. ` : "") + `${r.nights} לילות, ${perNight} ${r.currency} ללילה` +
        (r.hotel_rating ? `, דירוג אורחים ${r.hotel_rating}` : "") + (r.refundable ? ", ביטול חינם" : "");
    });
    if (top.length) await db.from("trip_offers").insert(top);
    if (!top.length && errs.length === cands.length) throw new Error(`שגיאת ספק מלונות: ${errs[0]}`);
    await set({ status: "done", progress: 100, error: top.length ? null : "לא נמצאו הצעות בתקציב" });
  } catch (e) {
    await set({ status: "error", error: String((e as Error).message ?? e) });
  }
}
