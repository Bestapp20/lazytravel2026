// Place -> bookable ticket matcher. Never returns a guessed product:
//  1) LiteAPI Experiences (native, priced) only when name AND location match above THRESHOLD;
//  2) otherwise, for clearly ticketed sights, a Travelpayouts-tracked partner *search* for the exact place.
export type Offer = {
  provider: "liteapi" | "tiqets" | "klook" | "getyourguide" | null;
  partner_name?: string; product_id?: string; title?: string; url?: string;
  price?: number | null; currency?: string | null; confidence: number;
};
export const THRESHOLD = 0.75;
const LITE = "https://api.liteapi.travel/v3.0";
const MARKER = () => Deno.env.get("TRAVELPAYOUTS_MARKER") || "744429";

const TICKETED = /(museum|museo|musée|gallery|galleria|colosseum|colosseo|roman forum|foro romano|palatine|palace|palazzo|castle|castel|fort\b|fortress|archaeolog|ruins|domus|catacomb|vatican|sistine|zoo|aquarium|theme park|water ?park|observatory|pantheon|tomb|mausoleum|cathedral museum|tour\b|cruise|exhibition|planetarium|crypt|מוזיאון|גלריה|מבצר|ארמון|טירה|קולוסיאום)/i;
const FREE = /(fountain|fontana|piazza|square|steps|street|via |beach|market|hill|bridge|ponte|promenade|marina|harbou?r|mouth of truth|bocca della|arch of|arco di|viewpoint|lake|park\b|memorial|monument|church|chiesa|basilica|mosque|synagogue|statue|cemetery)/i;

export function ticketable(name: string, category: string): boolean {
  if (["flight", "transport", "hotel", "restaurant", "cafe", "bar", "food", "nightlife", "beach", "market"].includes(category)) return false;
  if (TICKETED.test(name)) return true;
  if (FREE.test(name)) return false;
  return category === "museum";
}

const norm = (s: string) => s.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9\u0590-\u05ff ]/g, " ");
const STOP = new Set(["the", "of", "a", "and", "di", "de", "la", "il", "ticket", "tickets", "entry", "admission", "tour", "guided", "skip", "line", "with", "to", "in", "museum"]);
const toks = (s: string) => new Set(norm(s).split(/\s+/).filter((w) => w.length > 1 && !STOP.has(w)));
/** Share of the place's significant words that appear in the product title. */
export function nameScore(place: string, title: string): number {
  const p = toks(place), t = toks(title);
  if (!p.size) return 0;
  let hit = 0; p.forEach((w) => { if (t.has(w)) hit++; });
  return hit / p.size;
}
export function km(a: number, b: number, c: number, d: number) {
  const R = 6371, r = Math.PI / 180, x = Math.sin((c - a) * r / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin((d - b) * r / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}
/** name 70% + distance 30%; a product >3km away or with weak name overlap can never pass. */
export function confidence(place: { name: string; lat?: number; lng?: number }, prod: { title: string; lat?: number; lng?: number }) {
  const n = nameScore(place.name, prod.title);
  if (n < 0.6) return n * 0.5;
  if (place.lat == null || prod.lat == null) return n * 0.8; // no coords -> capped below threshold unless exact name
  const d = km(place.lat, place.lng!, prod.lat, prod.lng!);
  if (d > 3) return 0.3;
  return 0.7 * n + 0.3 * Math.max(0, 1 - d / 3);
}

let liteDisabled = false;
async function liteSearch(name: string, city: string, currency: string): Promise<any[] | null> {
  const key = Deno.env.get("LITEAPI_KEY");
  if (!key || liteDisabled) return null;
  const u = new URL(`${LITE}/experiences/tours`);
  u.searchParams.set("language", "en"); u.searchParams.set("currency", currency);
  u.searchParams.set("q", name); if (city) u.searchParams.set("city", city);
  const r = await fetch(u, { headers: { "X-API-Key": key, accept: "application/json" } });
  if (r.status === 403) { liteDisabled = true; return null; } // Experiences access not enabled on this account
  if (!r.ok) return null;
  const d = await r.json();
  return (d.data ?? d.tours ?? d.results ?? []) as any[];
}

export function tpLink(program: number | string, url: string) {
  const trs = Deno.env.get("TP_TRS") || "544254"; // Travelpayouts project id (not secret)
  const u = new URL("https://tp.media/r");
  u.searchParams.set("marker", MARKER()); if (trs) u.searchParams.set("trs", trs);
  u.searchParams.set("p", String(program)); u.searchParams.set("u", url);
  return u.toString();
}

export async function matchPlace(p: { name: string; city?: string; lat?: number; lng?: number; category: string }, currency = "ILS"): Promise<Offer> {
  if (!ticketable(p.name, p.category)) return { provider: null, confidence: 0 };
  const tours = await liteSearch(p.name, p.city ?? "", currency).catch(() => null);
  if (tours?.length) {
    let best: Offer = { provider: null, confidence: 0 };
    for (const t of tours.slice(0, 15)) {
      const title = t.title ?? t.name ?? "";
      const loc = t.location ?? t.coordinates ?? t.geo ?? {};
      const c = confidence(p, { title, lat: loc.latitude ?? loc.lat, lng: loc.longitude ?? loc.lng });
      if (c > best.confidence) {
        const pr = t.price ?? t.fromPrice ?? t.pricing ?? {};
        best = { provider: "liteapi", partner_name: "LAZYTRAVEL", product_id: String(t.id ?? t.tourId), title, confidence: c,
          price: pr.amount ?? pr.value ?? (typeof pr === "number" ? pr : null), currency: pr.currency ?? currency };
      }
    }
    if (best.confidence >= THRESHOLD) return best;
  }
  // Affiliate fallback: partner search for the exact place (not a guessed product), tracked with our marker.
  const q = encodeURIComponent([p.name, p.city].filter(Boolean).join(" "));
  const gyg = Deno.env.get("TP_GYG_P");
  if (gyg) return { provider: "getyourguide", partner_name: "GetYourGuide", url: tpLink(gyg, `https://www.getyourguide.com/s/?q=${q}`), confidence: 0.8, title: p.name };
  return { provider: "tiqets", partner_name: "Tiqets", url: tpLink(2074, `https://www.tiqets.com/en/search?q=${q}`), confidence: 0.8, title: p.name };
}

export const placeKey = (name: string, lat?: number, lng?: number) =>
  `${norm(name).trim().replace(/\s+/g, " ")}|${lat?.toFixed(3) ?? ""}|${lng?.toFixed(3) ?? ""}`;

