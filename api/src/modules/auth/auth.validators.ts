import { z } from "zod";

// ── App (usuários) ──
export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6, "A senha deve ter ao menos 6 caracteres"),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const requestCodeSchema = z.object({
  email: z.string().email(),
});

export const loginCodeSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6, "O código tem 6 dígitos"),
});

export const googleSchema = z.object({
  idToken: z.string().min(10),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(10),
});

// ── Painel (admins) ──
export const adminRegisterSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8, "A senha deve ter ao menos 8 caracteres"),
});

export const adminLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
