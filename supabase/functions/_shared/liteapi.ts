// LiteAPI (Nuitee Connect) client. Key comes from the LITEAPI_KEY edge secret.
const API = "https://api.liteapi.travel/v3.0";
const BOOK = "https://book.liteapi.travel/v3.0";

function key(): string {
  const k = Deno.env.get("LITEAPI_KEY");
  if (!k) throw new Error("LITEAPI_KEY is not set");
  return k;
}
export const isSandbox = () => key().startsWith("sand");

async function call(url: string, body?: unknown): Promise<any> {
  const res = await fetch(url, {
    method: body ? "POST" : "GET",
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
