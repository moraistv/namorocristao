/** Distância em km entre duas coordenadas (fórmula de Haversine). */
export function distanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // raio da Terra em km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/** Coordenadas aproximadas de cidades brasileiras (fallback quando não há GPS). */
const CITY_COORDS: Record<string, [number, number]> = {
  "são paulo": [-23.55, -46.63],
  "sao paulo": [-23.55, -46.63],
  "guarulhos": [-23.46, -46.53],
  "osasco": [-23.53, -46.79],
  "santo andré": [-23.66, -46.53],
  "santo andre": [-23.66, -46.53],
  "são bernardo": [-23.69, -46.56],
  "sao bernardo": [-23.69, -46.56],
  "são bernardo do campo": [-23.69, -46.56],
  "diadema": [-23.68, -46.62],
  "campinas": [-22.9, -47.06],
  "rio de janeiro": [-22.9, -43.2],
  "belo horizonte": [-19.92, -43.94],
  "curitiba": [-25.43, -49.27],
  "porto alegre": [-30.03, -51.23],
  "salvador": [-12.97, -38.5],
  "recife": [-8.05, -34.9],
  "fortaleza": [-3.73, -38.52],
  "brasília": [-15.79, -47.88],
  "brasilia": [-15.79, -47.88],
  "goiânia": [-16.68, -49.25],
  "goiania": [-16.68, -49.25],
};

/** Resolve coordenadas: usa lat/lng se houver, senão tenta pela cidade. */
export function resolveCoords(
  lat: number | null | undefined,
  lng: number | null | undefined,
  city: string | null | undefined
): [number, number] | null {
  if (lat != null && lng != null) return [lat, lng];
  if (city) {
    const key = city.trim().toLowerCase();
    if (CITY_COORDS[key]) return CITY_COORDS[key];
  }
  return null;
}

/** Distância entre dois perfis, com fallback por cidade. */
export function distanceBetween(
  a: { latitude?: number | null; longitude?: number | null; city?: string | null },
  b: { latitude?: number | null; longitude?: number | null; city?: string | null }
): number | null {
  const ca = resolveCoords(a.latitude, a.longitude, a.city);
  const cb = resolveCoords(b.latitude, b.longitude, b.city);
  if (!ca || !cb) return null;
  return distanceKm(ca[0], ca[1], cb[0], cb[1]);
}
