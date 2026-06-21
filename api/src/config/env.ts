import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  PORT: z.coerce.number().default(3333),
  DATABASE_URL: z.string().min(1, "DATABASE_URL é obrigatório"),

  JWT_ACCESS_SECRET: z.string().min(1, "JWT_ACCESS_SECRET é obrigatório"),
  JWT_REFRESH_SECRET: z.string().min(1, "JWT_REFRESH_SECRET é obrigatório"),
  JWT_ACCESS_EXPIRES: z.string().default("15m"),
  JWT_REFRESH_EXPIRES: z.string().default("30d"),

  GOOGLE_CLIENT_IDS: z.string().default(""),
  CORS_ORIGINS: z.string().default("http://localhost:5173"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(
    "❌ Variáveis de ambiente inválidas:",
    parsed.error.flatten().fieldErrors
  );
  process.exit(1);
}

const data = parsed.data;

export const env = {
  ...data,
  googleClientIds: data.GOOGLE_CLIENT_IDS.split(",")
    .map((s) => s.trim())
    .filter(Boolean),
  corsOrigins: data.CORS_ORIGINS.split(",")
    .map((s) => s.trim())
    .filter(Boolean),
};
