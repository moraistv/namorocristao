import { z } from "zod";

export const upsertProfileSchema = z.object({
  fullName: z.string().min(2, "Nome muito curto").max(80),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  birthday: z.coerce.date(),
  about: z.string().max(1000).optional(),
  intention: z.string().max(60).optional(),
  denomination: z.string().max(60).optional(),
  churchFrequency: z.string().max(60).optional(),
  city: z.string().max(80).optional(),
  interests: z.array(z.string().max(40)).max(10).optional(),
  mediaFiles: z.array(z.string().url()).max(6).optional(),
  lockedPhotos: z.array(z.string().url()).max(6).optional(),
  profilePicture: z.string().url().optional(),
  instagram: z.string().max(60).optional(),
  tiktok: z.string().max(60).optional(),
  twitter: z.string().max(60).optional(),
  facebook: z.string().max(60).optional(),
  // Perguntas de fé (prompts): [{q, a}]
  prompts: z
    .array(z.object({ q: z.string().max(120), a: z.string().max(300) }))
    .max(5)
    .optional(),
});

export const locationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  addressText: z.string().max(160).optional(),
});

export const preferencesSchema = z.object({
  // filtros de descoberta (guardados em memória do cliente por ora;
  // o backend aceita como query na descoberta)
  minAge: z.number().int().min(18).max(99).optional(),
  maxAge: z.number().int().min(18).max(99).optional(),
  maxDistanceKm: z.number().int().min(1).max(20000).optional(),
});
