// LiteAPI (Nuitee Connect) client. Key comes from the LITEAPI_KEY edge secret.
const API = "https://api.liteapi.travel/v3.0";
const BOOK = "https://book.liteapi.travel/v3.0";

function key(): string {
  const k = Deno.env.get("LITEAPI_KEY");
  if (!k) throw new Error("LITEAPI_KEY is not set");
  return k;
}
export const isSandbox = () => key().startsWith("sand");

async function call(url: string, body?: unknown, method?: string): Promise<any> {
  const res = await fetch(url, {
    method: method ?? (body ? "POST" : "GET"),
    headers: { "X-API-Key": key(), "Content-Type": "application/json", accept: "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data?.error) {
    const msg = data?.error?.message ?? data?.error?.description ?? res.statusText;
    throw new Error(`liteapi ${res.status}: ${msg}`);
  }
  return data;
}

export type HotelRate = {
  hotel_id: string; hotel_name: string; stars?: number; rating?: number; photo?: string; address?: string;
  offer_id: string; room_name?: string; board_name?: string; refundable?: boolean; price: number; currency: string;
};

/** Cheapest offer per hotel for a stay around a point. */
export async function hotelRates(p: {
  lat: number; lng: number; checkin: string; checkout: string; adults: number; children?: number;
  currency: string; radius?: number; limit?: number;
}): Promise<HotelRate[]> {
  const occ: Record<string, unknown> = { adults: p.adults };
  if (p.children) occ.children = Array(p.children).fill(10);
  const d = await call(`${API}/hotels/rates`, {
    occupancies: [occ], currency: p.currency, guestNationality: "IL",
    checkin: p.checkin, checkout: p.checkout, latitude: p.lat, longitude: p.lng,
    radius: p.radius ?? 20000, limit: p.limit ?? 30, maxRatesPerHotel: 1, timeout: 12,
  });
  const meta = new Map<string, any>((d.hotels ?? []).map((h: any) => [h.id, h]));
  const out: HotelRate[] = [];
  for (const h of d.data ?? []) {
    const m = meta.get(h.hotelId) ?? {};
    let best: HotelRate | null = null;
    for (const rt of h.roomTypes ?? []) {
      const rate = rt.rates?.[0] ?? {};
      const price = Number(rt.offerRetailRate?.amount ?? rate.retailRate?.total?.[0]?.amount);
      if (!price || (best && best.price <= price)) continue;
      best = {
        hotel_id: h.hotelId, hotel_name: m.name ?? h.hotelId, stars: m.stars, rating: m.rating,
        photo: m.main_photo ?? m.thumbnail, address: m.address, offer_id: rt.offerId,
        room_name: rate.name, board_name: rate.boardName,
        refundable: rate.cancellationPolicies?.refundableTag === "RFN",
        price, currency: rt.offerRetailRate?.currency ?? p.currency,
      };
    }
    if (best) out.push(best);
  }
  return out;
}

export async function prebook(offerId: string): Promise<any> {
  const d = await call(`${BOOK}/rates/prebook`, { offerId, usePaymentSdk: true });
  return d.data ?? d;
}

export async function book(p: {
  prebookId: string; transactionId: string; firstName: string; lastName: string; email: string;
}): Promise<any> {
  const person = { firstName: p.firstName, lastName: p.lastName, email: p.email };
  const d = await call(`${BOOK}/rates/book`, {
    prebookId: p.prebookId,
    holder: person,
    payment: { method: "TRANSACTION_ID", transactionId: p.transactionId },
    guests: [{ occupancyNumber: 1, ...person }],
  });
  return d.data ?? d;
}


// ───────────── Flights (LiteAPI / Nuitee) ─────────────
export type BagMode = "none" | "checked" | "carryon" | "trolley";
export type LiveFlight = {
  offer_id: string; total: number; fare_total: number; bag_total: number; currency: string;
  fare_family?: string; airline?: string; carry_on: boolean; checked_included: boolean;
  checked_kg?: number; bag_note: string; segments: { from: string; to: string; dep: string; arr?: string; min?: number; flight?: string; dir?: string }[];
  logo?: string; carrier?: string; legs?: { dir: string; min: number; day_change: number }[];
};

/** Live round-trip search; returns the cheapest offer satisfying the bag mode (bags priced per passenger, estimate). */
export async function flightLive(p: {
  origin: string; destination: string; depart: string; ret: string; adults: number; children: number; currency: string; mode: BagMode;
}): Promise<LiveFlight | null> {
  const d = await call(`${API}/flights/rates`, {
    legs: [{ origin: p.origin, destination: p.destination, date: p.depart }, { origin: p.destination, destination: p.origin, date: p.ret }],
    adults: p.adults, children: p.children, childrenAges: p.children ? Array(p.children).fill(10) : undefined, currency: p.currency,
  });
  const pax = p.adults + p.children;
  let best: LiveFlight | null = null;
  for (const j of d.data?.[0]?.journeys ?? []) {
    for (const o of j.offers ?? [j.cheapestOffer]) {
      if (!o) continue;
      const b = o.baggage ?? {};
      const fare = Number(o.pricing?.display?.total);
      if (!fare) continue;
      let bag = 0, note = "";
      const paidChecked = (b.paid ?? []).filter((x: any) => x.bagType === "checked")
        .sort((a: any, z: any) => a.pricing.display.amount - z.pricing.display.amount)[0];
      const paidCabin = (b.paid ?? []).filter((x: any) => x.bagType === "cabin")[0];
      const inclChecked = (b.included ?? []).find((x: any) => x.bagType === "checked");
      if (p.mode === "checked") {
        if (b.hasCheckedBag) note = `מזוודה ${inclChecked?.weightKg ?? ""} ק״ג כלולה`.replace("  ", " ");
        else if (paidChecked) { bag = paidChecked.pricing.display.amount * pax; note = `+ מזוודה ${paidChecked.weightKg ?? ""} ק״ג (משוער)`; }
        else continue;
      } else if (p.mode === "trolley") {
        // Trolley = cabin bag (~8-10kg) on top of the personal item.
        const inclCabin = (b.included ?? []).find((x: any) => x.bagType === "cabin");
        if (inclCabin) note = `טרולי ${inclCabin.weightKg ?? ""} ק״ג כלול`.replace("  ", " ");
        else if (paidCabin) { bag = paidCabin.pricing.display.amount * pax; note = `+ טרולי ${paidCabin.weightKg ?? ""} ק״ג (משוער)`.replace("  ", " "); }
        else continue;
      } else if (p.mode === "carryon") {
        // Personal item / small bag only: no extra bag needed, cheapest fare wins.
        note = "פריט אישי בלבד";
      }
      const total = Math.round((fare + bag) * 100) / 100;
      if (best && best.total <= total) continue;
      const segs = (j.segments ?? []).map((s: any) => ({
        from: s.originCode, to: s.destinationCode, dep: s.departureTime, arr: s.arrivalTime, min: s.duration?.minutes, dir: s.direction,
        flight: `${s.carrier?.marketingCode ?? ""}${s.flight?.marketingNumber ?? ""}`,
      }));
      best = {
        offer_id: o.offerId, total, fare_total: fare, bag_total: bag, currency: o.pricing.display.currency,
        fare_family: o.fare?.family, airline: j.segments?.[0]?.carrier?.marketingName,
        carry_on: !!b.hasCarryOnBag, checked_included: !!b.hasCheckedBag, checked_kg: inclChecked?.weightKg ?? paidChecked?.weightKg,
        bag_note: note, segments: segs,
        logo: j.segments?.[0]?.carrier?.marketingLogo, carrier: j.segments?.[0]?.carrier?.marketingCode,
        legs: (j.legDurations ?? []).map((l: any) => ({ dir: l.direction, min: l.duration?.minutes, day_change: l.dayChange ?? 0 })),
      };
    }
  }
  return best;
}

export async function flightPrebook(body: unknown): Promise<any> {
  const d = await call(`${API}/flights/prebooks`, body);
  // Keep the top level (prebookId, transactionId, secretKey, price); `booking` holds the journey detail.
  return d.data?.[0] ?? d.data ?? d;
}

/** Attach the cheapest 'CHECKED BAG' service per segment per passenger. Returns the updated prebook. */
export async function flightAttachCheckedBags(prebook: any, pax: number): Promise<any> {
  const svcs = (prebook.servicesAttachable?.groups ?? []).filter((g: any) => g.category === "baggage").flatMap((g: any) => g.services ?? []);
  const bySeg = new Map<string, any>();
  for (const s of svcs) {
    if (!/CHECKED BAG/i.test(s.name ?? "") && s.metadata?.baggage?.bagType !== "checked") continue;
    if (/BICYCLE|SPORT|EXCESS/i.test(s.name ?? "")) continue;
    const cur = bySeg.get(s.segmentKey);
    if (!cur || s.pricing.display.amount < cur.pricing.display.amount) bySeg.set(s.segmentKey, s);
  }
  if (!bySeg.size) throw new Error("no checked-bag service available to attach");
  const selectedServices = [];
  for (let i = 0; i < pax; i++) for (const s of bySeg.values()) selectedServices.push({ passengerIndex: i, serviceId: s.serviceId, quantity: 1 });
  const d = await call(`${API}/flights/prebooks/${prebook.prebookId}/services`, { selectedServices });
  const r = d.data?.[0] ?? d.data ?? d;
  return r.booking ?? r;
}

export async function flightBook(prebookId: string, transactionId: string): Promise<any> {
  const d = await call(`${API}/flights/bookings`, { prebookId, payment: { method: "TRANSACTION_ID", transactionId } });
  const r = d.data?.[0] ?? d.data ?? d;
  return r.booking ?? r;
}


// ───────────── Booking management (status / cancel) ─────────────
export async function hotelBookingGet(bookingId: string): Promise<any> {
  const d = await call(`${BOOK}/bookings/${encodeURIComponent(bookingId)}`);
  return d.data ?? d;
}
export async function hotelBookingCancel(bookingId: string): Promise<any> {
  const d = await call(`${BOOK}/bookings/${encodeURIComponent(bookingId)}`, undefined, "PUT");
  return d.data ?? d;
}
export async function flightBookingGet(bookingId: string): Promise<any> {
  const d = await call(`${API}/flights/bookings/${encodeURIComponent(bookingId)}`);
  const r = d.data?.[0] ?? d.data ?? d;
  return r.booking ?? r;
}
/** Cancellation quote (no commitment). */
export async function flightCancelQuote(bookingId: string): Promise<any> {
  const d = await call(`${API}/flights/bookings/${encodeURIComponent(bookingId)}/cancellations`);
  return d.data ?? d;
}
export async function flightBookingCancel(bookingId: string): Promise<any> {
  const d = await call(`${API}/flights/bookings/${encodeURIComponent(bookingId)}/cancellations`, {});
  return d.data ?? d;
}
