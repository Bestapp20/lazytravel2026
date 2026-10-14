
export type PlaceHit = {
  place_id: string;
  name: string;
  address?: string;
  lat?: number;
  lng?: number;
  rating?: number;
  price_level?: number;
  types?: string[];
  photo_reference?: string;
  map_link?: string;
};

function key(): string {
  const k = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!k) throw new Error("GOOGLE_PLACES_API_KEY is not set");
  return k;
}

// Places API (New) — v1 endpoints. Output keeps the legacy shapes the app expects.
const PLACES_NEW = "https://places.googleapis.com/v1";
const PRICE: Record<string, number> = {
  PRICE_LEVEL_FREE: 0,
  PRICE_LEVEL_INEXPENSIVE: 1,
  PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3,
  PRICE_LEVEL_VERY_EXPENSIVE: 4,
};

async function gpost(path: string, body: unknown, fieldMask: string): Promise<Record<string, unknown>> {
  const res = await fetch(`${PLACES_NEW}/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Goog-Api-Key": key(), "X-Goog-FieldMask": fieldMask },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) console.error("places error", path, res.status, JSON.stringify(data).slice(0, 500));
  return data;
}

export async function autocomplete(input: string, types = "(cities)"): Promise<unknown> {
  const body: Record<string, unknown> = { input, languageCode: "he" };
  if (types === "(cities)") body.includedPrimaryTypes = ["locality", "administrative_area_level_1", "country"];
  const data = await gpost("places:autocomplete", body, "*");
  const sugg = (data.suggestions as Array<Record<string, any>> | undefined) ?? [];
  const predictions = sugg.filter((s) => s.placePrediction).map((s) => {
    const p = s.placePrediction;
    return {
      place_id: p.placeId,
      description: p.text?.text ?? "",
      structured_formatting: {
        main_text: p.structuredFormat?.mainText?.text ?? p.text?.text ?? "",
        secondary_text: p.structuredFormat?.secondaryText?.text ?? "",
      },
    };
  });
  return { predictions, status: data.error ? "ERROR" : "OK" };
}

const FIELDS = "id,displayName,formattedAddress,location,rating,priceLevel,types,photos,googleMapsUri";

export async function textSearch(query: string, location?: { lat: number; lng: number }): Promise<PlaceHit[]> {
  const body: Record<string, unknown> = { textQuery: query, languageCode: "en", pageSize: 12 };
  if (location) {
    body.locationBias = { circle: { center: { latitude: location.lat, longitude: location.lng }, radius: 15000 } };
  }
  const data = await gpost("places:searchText", body, FIELDS.split(",").map((f) => `places.${f}`).join(","));
  return ((data.places as Record<string, unknown>[]) ?? []).slice(0, 12).map(mapResult);
}

export async function placeDetails(placeId: string): Promise<PlaceHit | null> {
  const res = await fetch(`${PLACES_NEW}/places/${encodeURIComponent(placeId)}`, {
    headers: { "X-Goog-Api-Key": key(), "X-Goog-FieldMask": FIELDS },
  });
  const data = await res.json();
  if (!res.ok || !data.id) return null;
  return mapResult(data);
}

export function photoUrl(photoReference: string, maxwidth = 800): string {
  // photoReference is the New API photo name: places/{id}/photos/{ref}
  return `${PLACES_NEW}/${photoReference}/media?maxWidthPx=${maxwidth}&key=${key()}`;
}

/** Resolve a photo name to a short-lived public googleusercontent URL (no API key inside). */
export async function photoMediaUri(photoReference: string, maxwidth = 800): Promise<string | null> {
  try {
    const res = await fetch(`${PLACES_NEW}/${photoReference}/media?maxWidthPx=${maxwidth}&skipHttpRedirect=true`, {
      headers: { "X-Goog-Api-Key": key() },
    });
    if (!res.ok) return null;
    const d = await res.json();
    return (d.photoUri as string) ?? null;
  } catch {
    return null;
  }
}

function mapResult(r: Record<string, any>): PlaceHit {
  const lat = r.location?.latitude;
  const lng = r.location?.longitude;
  return {
    place_id: String(r.id ?? ""),
    name: String(r.displayName?.text ?? ""),
    address: r.formattedAddress,
    lat,
    lng,
    rating: r.rating,
    price_level: r.priceLevel != null ? PRICE[r.priceLevel] : undefined,
    types: r.types,
    photo_reference: r.photos?.[0]?.name,
    map_link: r.googleMapsUri ?? (lat != null && lng != null ? `https://maps.google.com/?q=${lat},${lng}` : undefined),
  };
}

export const INTEREST_QUERIES: Record<string, string> = {
  food: "best restaurants",
  nightlife: "nightlife bars clubs",
  culture: "cultural attractions",
  history: "historical landmarks",
  nature: "parks nature viewpoints",
  shopping: "shopping markets",
  museums: "museums",
  attractions: "top attractions",
  photography: "scenic photo spots",
  kids: "family friendly attractions",
  hidden: "hidden gems local favorites",
};
