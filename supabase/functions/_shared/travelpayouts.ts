// Travelpayouts / Aviasales Data API (cached prices from user searches; NOT live fares).
const API = "https://api.travelpayouts.com/aviasales/v3";

function token(): string {
  const t = Deno.env.get("TRAVELPAYOUTS_TOKEN");
  if (!t) throw new Error("TRAVELPAYOUTS_TOKEN is not set");
  return t;
}
/** Clean Aviasales results link with the right passenger count (documented: {O}{ddmm}{D}{ddmm}{adults}{children}{infants}). */
export function aviasalesLink(o: string, d: string, depart: string, ret: string, adults: number, children: number): string {
  const dm = (s: string) => s.slice(8, 10) + s.slice(5, 7);
  return `https://www.aviasales.com/search/${o}${dm(depart)}${d}${dm(ret)}${Math.min(9, adults)}${children ? Math.min(9, children) : ""}?marker=${marker()}`;
}
export const marker = () => Deno.env.get("TRAVELPAYOUTS_MARKER") ?? "";

async function get(path: string, q: Record<string, string | number | boolean>): Promise<any> {
  const u = new URL(`${API}/${path}`);
  for (const [k, v] of Object.entries(q)) u.searchParams.set(k, String(v));
  u.searchParams.set("token", token());
  const res = await fetch(u, { headers: { "Accept-Encoding": "gzip" } });
  const d = await res.json().catch(() => ({}));
  if (!res.ok || d.success === false) throw new Error(`travelpayouts ${res.status}: ${d.error ?? ""}`);
  return d.data;
}

export type Place = { code: string; name: string; country?: string; lat: number; lng: number };

/** Resolve free text ("Koh Samui", "רומא") or IATA code to a city with coordinates. */
export async function resolvePlace(term: string, locale = "en"): Promise<Place | null> {
  const u = new URL("https://autocomplete.travelpayouts.com/places2");
  u.searchParams.set("term", term);
  u.searchParams.set("locale", locale);
  u.searchParams.append("types[]", "city");
  u.searchParams.append("types[]", "airport");
  const d = await (await fetch(u)).json().catch(() => []);
  const p = d?.[0];
  if (!p?.coordinates) return null;
  return { code: p.city_code ?? p.code, name: p.city_name ?? p.name, country: p.country_name, lat: p.coordinates.lat, lng: p.coordinates.lon };
}

export type Fare = {
  origin: string; destination: string; depart: string; ret: string; price: number; airline?: string;
  transfers?: number; return_transfers?: number; link: string;
};

const months = (from: string, to: string) => {
  const out: string[] = [];
  const d = new Date(from.slice(0, 7) + "-01T00:00:00Z");
  while (d.toISOString().slice(0, 10) <= to && out.length < 4) { out.push(d.toISOString().slice(0, 7)); d.setUTCMonth(d.getUTCMonth() + 1); }
  return out;
};

/** Round-trip fares in the window; destination null = anywhere (one cheapest fare per destination). */
export async function roundTrips(p: { origin: string; destination?: string | null; from: string; to: string; currency: string }): Promise<Fare[]> {
  const all: Fare[] = [];
  for (const m of months(p.from, p.to)) {
    const q: Record<string, string | number | boolean> = {
      origin: p.origin, departure_at: m, one_way: false, sorting: "price", currency: p.currency.toLowerCase(),
      limit: p.destination ? 200 : 100, unique: !p.destination, market: "il",
    };
    if (p.destination) q.destination = p.destination;
    const rows = await get("prices_for_dates", q).catch((e) => { console.error(e); return []; });
    for (const r of rows ?? []) {
      if (!r.return_at) continue;
      all.push({
        origin: r.origin, destination: r.destination, depart: r.departure_at.slice(0, 10), ret: r.return_at.slice(0, 10),
        price: Number(r.price), airline: r.airline, transfers: r.transfers, return_transfers: r.return_transfers,
        link: `https://www.aviasales.com${r.link}&marker=${marker()}`,
      });
    }
  }
  return all;
}

/** Cheapest one-way price per departure day (calendar). */
export async function cheapestDays(p: { origin: string; destination: string; from: string; to: string; currency: string }) {
  const out: Record<string, number> = {};
  for (const m of months(p.from, p.to)) {
    const d = await get("grouped_prices", {
      origin: p.origin, destination: p.destination, departure_at: m, group_by: "departure_at", currency: p.currency.toLowerCase(), market: "il",
    }).catch(() => ({}));
    for (const [day, v] of Object.entries(d ?? {})) if (day >= p.from && day <= p.to) out[day] = Number((v as any).price);
  }
  return out;
}
