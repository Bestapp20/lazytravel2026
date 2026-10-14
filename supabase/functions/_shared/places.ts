const PLACES = "https://maps.googleapis.com/maps/api/place";

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

export async function autocomplete(input: string, types = "(cities)"): Promise<unknown> {
  const url = `${PLACES}/autocomplete/json?input=${encodeURIComponent(input)}&types=${encodeURIComponent(types)}&language=he&key=${key()}`;
  const res = await fetch(url);
  return await res.json();
}

export async function textSearch(query: string, location?: { lat: number; lng: number }): Promise<PlaceHit[]> {
  const loc = location ? `&location=${location.lat},${location.lng}&radius=15000` : "";
  const url = `${PLACES}/textsearch/json?query=${encodeURIComponent(query)}${loc}&language=en&key=${key()}`;
  const res = await fetch(url);
  const data = await res.json();
  return (data.results ?? []).slice(0, 12).map(mapResult);
}

export async function placeDetails(placeId: string): Promise<PlaceHit | null> {
  const fields =
    "place_id,name,formatted_address,geometry,rating,price_level,types,photos,url,opening_hours";
  const url = `${PLACES}/details/json?place_id=${encodeURIComponent(placeId)}&fields=${fields}&key=${key()}`;
  const res = await fetch(url);
  const data = await res.json();
  if (!data.result) return null;
  return mapResult(data.result);
}

export function photoUrl(photoReference: string, maxwidth = 800): string {
  return `${PLACES}/photo?maxwidth=${maxwidth}&photo_reference=${encodeURIComponent(photoReference)}&key=${key()}`;
}

function mapResult(r: Record<string, unknown>): PlaceHit {
  const geo = r.geometry as { location?: { lat: number; lng: number } } | undefined;
  const photos = r.photos as Array<{ photo_reference: string }> | undefined;
  const lat = geo?.location?.lat;
  const lng = geo?.location?.lng;
  return {
    place_id: String(r.place_id ?? ""),
    name: String(r.name ?? ""),
    address: (r.formatted_address as string) ?? (r.vicinity as string),
    lat,
    lng,
    rating: r.rating as number | undefined,
    price_level: r.price_level as number | undefined,
    types: r.types as string[] | undefined,
    photo_reference: photos?.[0]?.photo_reference,
    map_link:
      (r.url as string) ??
      (lat != null && lng != null ? `https://maps.google.com/?q=${lat},${lng}` : undefined),
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
