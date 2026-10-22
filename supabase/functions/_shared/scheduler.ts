// Time-of-day aware day scheduler shared by generate-route, reorder-day and add-place suggestions.
// Rules: category windows, Google regularOpeningHours, geographic ordering, realistic durations/travel,
// and tips generated from the actual slot (never "arrive early" on an evening slot).

export type Cat =
  | "museum" | "cafe" | "restaurant" | "bar" | "beach" | "park" | "temple" | "market"
  | "viewpoint" | "hotel" | "flight" | "transport" | "attraction";

export type Period = { open?: { day: number; hour: number; minute?: number }; close?: { day: number; hour: number; minute?: number } };
export type Hours = { periods?: Period[]; weekdayDescriptions?: string[] } | null | undefined;

export type Stop = {
  key: string;
  name: string;
  category: string;
  lat?: number | null;
  lng?: number | null;
  hours?: Hours;
  duration?: number | null;
  types?: string[];
  rating?: number | null;
  fixedStart?: number | null; // logistics items keep their time
};

export type Slot = { key: string; start: number; end: number; category: Cat; tip: string; warning?: string };

const LEGACY: Record<string, Cat> = { food: "restaurant", nightlife: "bar", nature: "park", shopping: "market" };

export function normCat(c?: string | null): Cat {
  if (!c) return "attraction";
  if (LEGACY[c]) return LEGACY[c];
  const all: Cat[] = ["museum", "cafe", "restaurant", "bar", "beach", "park", "temple", "market", "viewpoint", "hotel", "flight", "transport", "attraction"];
  return (all as string[]).includes(c) ? c as Cat : "attraction";
}

export function categoryFromPlace(types?: string[], name = ""): Cat {
  const t = new Set(types ?? []);
  const n = name.toLowerCase();
  const has = (...k: string[]) => k.some((x) => t.has(x));
  if (has("airport")) return "flight";
  if (has("lodging", "hotel", "resort_hotel")) return "hotel";
  if (has("bar", "night_club", "pub", "wine_bar", "cocktail_bar") || /\b(bar|pub|club)\b/.test(n)) return "bar";
  if (has("museum", "art_gallery")) return "museum";
  if (has("church", "place_of_worship", "mosque", "synagogue", "hindu_temple", "buddhist_temple") || /church|cathedral|basilica|temple|mosque|monastery|chapel/.test(n)) return "temple";
  if (has("beach") || /beach|plage|playa/.test(n)) return "beach";
  if (/viewpoint|lookout|belvedere|panoram|terrazza|observation/.test(n) || has("observation_deck")) return "viewpoint";
  if (has("market", "farmers_market") || /market|mercato|bazaar/.test(n)) return "market";
  if (has("cafe", "coffee_shop", "bakery", "breakfast_restaurant", "brunch_restaurant") || /caf[eé]|coffee|bakery|brunch/.test(n)) return "cafe";
  if (has("restaurant", "food", "meal_takeaway") || [...t].some((x) => x.endsWith("_restaurant"))) return "restaurant";
  if (has("park", "national_park", "natural_feature", "garden", "botanical_garden", "hiking_area")) return "park";
  if (has("shopping_mall", "store")) return "market";
  return "attraction";
}

/** Allowed START windows (minutes from midnight). */
export function windowsFor(cat: Cat, name = ""): [number, number][] {
  const night = /night/i.test(name);
  switch (cat) {
    case "cafe": return [[7 * 60 + 30, 11 * 60]];
    case "restaurant": return [[12 * 60 + 30, 14 * 60], [19 * 60, 21 * 60]];
    case "bar": return [[19 * 60 + 30, 23 * 60]];
    case "museum": return [[10 * 60, 16 * 60]];
    case "beach": return [[8 * 60, 10 * 60 + 30], [16 * 60, 17 * 60 + 30]];
    case "viewpoint": return [[17 * 60, 19 * 60], [8 * 60, 10 * 60]];
    case "market": return night ? [[18 * 60, 21 * 60]] : [[8 * 60 + 30, 17 * 60]];
    case "temple": return [[8 * 60, 16 * 60 + 30]];
    case "park": return [[8 * 60, 17 * 60]];
    case "hotel": return [[14 * 60, 22 * 60]];
    case "flight": case "transport": return [[0, 24 * 60]];
    default: return [[9 * 60, 17 * 60 + 30]];
  }
}

export const DURATION: Record<Cat, number> = {
  museum: 120, cafe: 45, restaurant: 75, bar: 90, beach: 150, park: 75, temple: 45, market: 75,
  viewpoint: 45, hotel: 30, flight: 120, transport: 45, attraction: 75,
};

/** Open intervals for a weekday (0=Sun), from Places API (New) regularOpeningHours.periods. null = unknown (treat as open). */
export function openIntervals(h: Hours, weekday: number): [number, number][] | null {
  const periods = h?.periods;
  if (!periods || periods.length === 0) return null;
  // 24/7: single period with open only
  if (periods.length === 1 && periods[0].open && !periods[0].close) return [[0, 48 * 60]];
  const out: [number, number][] = [];
  for (const p of periods) {
    if (!p.open || !p.close) continue;
    const prev = (weekday + 6) % 7;
    const o = p.open.hour * 60 + (p.open.minute ?? 0);
    let c = p.close.hour * 60 + (p.close.minute ?? 0);
    if (p.open.day === weekday) {
      if (p.close.day !== weekday || c <= o) c += 24 * 60;
      out.push([o, c]);
    } else if (p.open.day === prev && (p.close.day === weekday) && c > 0) {
      out.push([0, c]); // spill-over from previous night
    }
  }
  return out;
}

type LL = { lat?: number | null; lng?: number | null };
export function km(a: LL, b: LL): number {
  if (a.lat == null || a.lng == null || b.lat == null || b.lng == null) return 2;
  const r = 6371, d = Math.PI / 180;
  const x = Math.sin((b.lat - a.lat) * d / 2) ** 2 + Math.cos(a.lat * d) * Math.cos(b.lat * d) * Math.sin((b.lng - a.lng) * d / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(x));
}

/** Door-to-door minutes: walk short legs, taxi longer ones. */
export function travelMin(a: Stop | null, b: Stop): number {
  if (!a) return 0;
  const k = km(a, b);
  const m = k <= 1.2 ? 5 + k * 12 : 12 + k * 2.2;
  return Math.min(90, Math.ceil(m / 5) * 5);
}

const r15 = (m: number) => Math.ceil(m / 15) * 15;

/** Earliest feasible start >= t, inside a category window and opening hours with time to finish. */
export function earliestStart(s: Stop, t: number, weekday: number): number | null {
  const cat = normCat(s.category);
  const dur = s.duration ?? DURATION[cat];
  const open = openIntervals(s.hours, weekday);
  let best: number | null = null;
  for (const [ws, we] of windowsFor(cat, s.name)) {
    const ranges = open ?? [[0, 48 * 60]];
    for (const [os, oc] of ranges) {
      const lo = r15(Math.max(t, ws, os));
      const hi = Math.min(we, oc - Math.min(dur, 90)); // time to see it before closing
      if (lo <= hi && (best == null || lo < best)) best = lo;
    }
  }
  return best;
}

export function fits(s: Stop, start: number, weekday: number): string | null {
  const cat = normCat(s.category);
  if (cat === "flight" || cat === "transport" || cat === "hotel") return null;
  const dur = s.duration ?? DURATION[cat];
  const open = openIntervals(s.hours, weekday);
  if (open && !open.some(([o, c]) => start >= o && start + Math.min(dur, 90) <= c)) {
    return open.length === 0 ? "סגור ביום הזה" : "מחוץ לשעות הפתיחה";
  }
  if (!windowsFor(cat, s.name).some(([a, b]) => start >= a - 15 && start <= b + 30)) {
    return ({
      bar: "בר/חיי לילה מתאים לערב", cafe: "בית קפה מתאים לבוקר", restaurant: "מחוץ לשעות צהריים/ערב",
      museum: "מוזיאון עדיף בשעות היום", beach: "חוף עדיף בבוקר או אחה״צ מאוחר", viewpoint: "תצפית עדיפה בשקיעה",
    } as Record<string, string>)[cat] ?? "שעה לא מתאימה למקום";
  }
  return null;
}

export function tipFor(cat: Cat, start: number, name = ""): string {
  const morning = start < 11 * 60, evening = start >= 17 * 60;
  switch (cat) {
    case "museum": return start < 11 * 60 ? "הגיעו בפתיחה כדי להקדים את התורים, ושווה להזמין כרטיס מראש" : "הזמינו כרטיס מראש לשעה הזו כדי לדלג על התור";
    case "cafe": return "התחלה רגועה של היום. בקשו מאפה מקומי עם הקפה";
    case "restaurant": return evening ? "מומלץ להזמין שולחן לערב מראש" : "שאלו על מנת הצהריים, לרוב משתלמת יותר";
    case "bar": return "הערב מתחיל להתעורר אחרי 21:00. בדקו קוד לבוש";
    case "beach": return morning ? "בבוקר החוף שקט והשמש נעימה. קחו מים וקרם הגנה" : "אחה״צ המאוחר נעים יותר. הישארו לשקיעה";
    case "viewpoint": return evening ? "הגיעו כ-20 דקות לפני השקיעה לאור הטוב ביותר" : "אור הבוקר רך ויש פחות אנשים";
    case "market": return /night/i.test(name) ? "השוק מתעורר אחרי החשכה. קחו מזומן" : morning ? "בבוקר הסחורה הכי טרייה. קחו מזומן" : "שווה להתמקח. קחו מזומן";
    case "temple": return "לבוש צנוע (כתפיים וברכיים מכוסות)";
    case "park": return morning ? "בבוקר קריר ונעים יותר להליכה" : "קחו מים וכובע";
    case "hotel": return "השאירו מזוודות בקבלה אם החדר עוד לא מוכן";
    default: return morning ? "הגיעו מוקדם כדי להימנע מעומס" : evening ? "בערב יש אווירה מיוחדת ופחות חום" : "שמרו על חפצי ערך באזורים הומי תיירים";
  }
}

/**
 * Greedy time-aware nearest-neighbour: at each step pick the stop that can start soonest
 * (travel + wait), with a bonus for stops whose window is closing. Max one lunch + one dinner.
 */
export function scheduleDay(stops: Stop[], dateIso: string, base?: Stop | null, dayStart = 9 * 60): { slots: Slot[]; dropped: Stop[] } {
  const weekday = new Date(dateIso + "T12:00:00Z").getUTCDay();
  const fixed = stops.filter((s) => s.fixedStart != null).sort((a, b) => a.fixedStart! - b.fixedStart!);
  const busy = fixed.map((f) => [f.fixedStart!, f.fixedStart! + (f.duration ?? DURATION[normCat(f.category)])] as [number, number]);
  const rest = stops.filter((s) => s.fixedStart == null);
  // Day may start earlier for cafes/beaches.
  let t = Math.min(dayStart, rest.some((s) => normCat(s.category) === "cafe") ? 8 * 60 + 30 : dayStart);
  let here: Stop | null = base ?? null;
  const slots: Slot[] = fixed.map((f) => ({
    key: f.key, start: f.fixedStart!, end: f.fixedStart! + (f.duration ?? DURATION[normCat(f.category)]),
    category: normCat(f.category), tip: "",
  }));
  let meals = { lunch: false, dinner: false };
  const pool = [...rest];
  while (pool.length) {
    let pick = -1, pickStart = 0, pickScore = Infinity;
    for (let i = 0; i < pool.length; i++) {
      const s = pool[i];
      const cat = normCat(s.category);
      const tr = travelMin(here, s);
      let st = earliestStart(s, t + tr, weekday);
      if (st == null) continue;
      const dur = s.duration ?? DURATION[cat];
      // skip over fixed logistics
      for (const [bs, be] of busy) if (st < be && st + dur > bs) st = r15(be + 15);
      if (earliestStart(s, st, weekday) !== st) { const again = earliestStart(s, st, weekday); if (again == null) continue; st = again; }
      if (cat === "restaurant") {
        const isLunch = st < 16 * 60;
        if ((isLunch && meals.lunch) || (!isLunch && meals.dinner)) continue;
      }
      const latest = windowsFor(cat, s.name).reduce((m, [, we]) => (we >= st ? Math.min(m, we) : m), 24 * 60);
      let score = (st - t) + tr * 1.5 + Math.max(0, latest - st) * 0.12;
      if (cat === "cafe") score -= 240; // breakfast opens the day
      if (cat === "viewpoint" && st < 12 * 60) score += 150; // prefer sunset
      if (cat === "bar" || (cat === "market" && /night/i.test(s.name))) score += 60; // close the day
      if (score < pickScore) { pick = i; pickScore = score; pickStart = st; }
    }
    if (pick < 0) break;
    const s = pool.splice(pick, 1)[0];
    const cat = normCat(s.category);
    const dur = s.duration ?? DURATION[cat];
    if (cat === "restaurant") { if (pickStart < 16 * 60) meals.lunch = true; else meals.dinner = true; }
    slots.push({ key: s.key, start: pickStart, end: pickStart + dur, category: cat, tip: tipFor(cat, pickStart, s.name) });
    t = pickStart + dur;
    here = s;
  }
  slots.sort((a, b) => a.start - b.start);
  return { slots, dropped: pool };
}

/** Keep the user's order, recompute times (wait for open/window when needed) and warn on misfits. */
export function retimeInOrder(stops: Stop[], dateIso: string, dayStart = 9 * 60): Slot[] {
  const weekday = new Date(dateIso + "T12:00:00Z").getUTCDay();
  let t = dayStart, here: Stop | null = null;
  const out: Slot[] = [];
  for (const s of stops) {
    const cat = normCat(s.category);
    const dur = s.duration ?? DURATION[cat];
    let start: number;
    if (s.fixedStart != null) start = s.fixedStart;
    else {
      const arrive = r15(t + travelMin(here, s));
      const e = earliestStart(s, arrive, weekday);
      start = e != null && e - arrive <= 180 ? e : arrive;
    }
    out.push({ key: s.key, start, end: start + dur, category: cat, tip: tipFor(cat, start, s.name), warning: fits(s, start, weekday) ?? undefined });
    t = start + dur;
    here = s;
  }
  return out;
}

/** Best start time for a new stop added to an existing day. */
export function suggestSlot(newStop: Stop, existing: { start: number; end: number; stop: Stop }[], dateIso: string): { start: number; tip: string; warning?: string } {
  const weekday = new Date(dateIso + "T12:00:00Z").getUTCDay();
  const cat = normCat(newStop.category);
  const dur = newStop.duration ?? DURATION[cat];
  const ex = [...existing].sort((a, b) => a.start - b.start);
  let best: { start: number; cost: number } | null = null;
  for (let t = 7 * 60 + 30; t <= 23 * 60; t += 15) {
    const st = earliestStart(newStop, t, weekday);
    if (st == null || st !== t) continue;
    const prev = [...ex].reverse().find((e) => e.end <= st);
    const next = ex.find((e) => e.start >= st);
    const trIn = prev ? travelMin(prev.stop, newStop) : 0;
    const trOut = next ? travelMin(newStop, next.stop) : 0;
    if (prev && prev.end + trIn > st) continue;
    if (next && st + dur + trOut > next.start) continue;
    if (ex.some((e) => st < e.end && st + dur > e.start)) continue;
    const cost = trIn + trOut + (prev ? st - prev.end - trIn : 0) * 0.2;
    if (!best || cost < best.cost) best = { start: st, cost };
  }
  if (best) return { start: best.start, tip: tipFor(cat, best.start, newStop.name) };
  const last = ex.length ? ex[ex.length - 1].end + 30 : 10 * 60;
  const s = r15(last);
  return { start: s, tip: tipFor(cat, s, newStop.name), warning: fits(newStop, s, weekday) ?? "אין חלון פנוי שמתאים לשעות הפתיחה ביום הזה" };
}

export const fmtHM = (m: number) => `${String(Math.floor(m / 60) % 24).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
export const parseHM = (s?: string | null) => (s && s.length >= 5 ? +s.slice(0, 2) * 60 + +s.slice(3, 5) : null);

export const RULES_PROMPT = `Scheduling rules (your output is validated and re-timed against these):
- bars/nightlife/clubs/night markets: 19:30-23:00 only. cafes/breakfast: 07:30-11:00.
- museums: inside opening hours, 10:00-16:00 start. beaches: 08:00-10:30 or 16:00-17:30.
- viewpoints: around sunset (17:00-19:00) when appropriate. restaurants: lunch 12:30-14:00, dinner 19:00-21:00; max one lunch and one dinner per day, never two food stops in a row.
- never schedule outside a place's opening_hours (given per candidate). Order stops geographically to avoid backtracking.
- tips must match the slot: never say "arrive early" (הגיעו מוקדם) for an afternoon/evening slot.`;
