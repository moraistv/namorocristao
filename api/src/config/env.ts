import "dotenv/config";
import { z } from "zod";

const optionalSecret = z.preprocess(
  (value) =>
    typeof value === "string" && value.trim() === "" ? undefined : value,
  z.string().trim().min(1).optional()
);

const trustProxyHopsFromEnv = z.preprocess((value) => {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value === "string" && value.trim().toLowerCase() === "false") {
    return 0;
  }
  return value;
}, z.coerce.number().int().min(0).max(10).optional());

function rawCorsOrigins(value: string): string[] {
  return value
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

/** Aceita apenas uma origem HTTP(S), sem path/query/hash/credenciais/wildcard. */
function normalizeCorsOrigin(value: string): string | null {
  if (value.includes("*")) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    if (url.username || url.password || url.search || url.hash) return null;
    if (url.pathname !== "/") return null;
    return url.origin;
  } catch {
    return null;
  }
}

const envSchema = z
  .object({
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
    CORS_ORIGINS: z.string().default(""),
    TRUST_PROXY_HOPS: trustProxyHopsFromEnv,

    DEEPSEEK_API_KEY: optionalSecret,
    OPENAI_API_KEY: optionalSecret,
    AI_SECRET_ENCRYPTION_KEY: optionalSecret,
    AI_REQUEST_TIMEOUT_MS: z.coerce
      .number()
      .int()
      .min(1000)
      .max(120000)
      .default(15000),
  })
  .superRefine((value, ctx) => {
    const corsOrigins = rawCorsOrigins(value.CORS_ORIGINS);
    if (value.NODE_ENV === "production" && corsOrigins.length === 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["CORS_ORIGINS"],
        message: "CORS_ORIGINS é obrigatório em produção",
      });
    }
    for (const origin of corsOrigins) {
      if (!normalizeCorsOrigin(origin)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["CORS_ORIGINS"],
          message:
            "CORS_ORIGINS aceita somente origens http/https exatas, sem wildcard, path, query ou hash",
        });
        break;
      }
    }

    if (value.NODE_ENV === "production") {
      const encryptionSecret = value.AI_SECRET_ENCRYPTION_KEY;
      if (!encryptionSecret || encryptionSecret.length < 32) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["AI_SECRET_ENCRYPTION_KEY"],
          message:
            "AI_SECRET_ENCRYPTION_KEY deve ter ao menos 32 caracteres em produção",
        });
      } else if (
        encryptionSecret === value.JWT_ACCESS_SECRET ||
        encryptionSecret === value.JWT_REFRESH_SECRET
      ) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["AI_SECRET_ENCRYPTION_KEY"],
          message:
            "AI_SECRET_ENCRYPTION_KEY deve ser dedicada e diferente dos segredos JWT",
        });
      }
    }
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
const configuredCorsOrigins = Array.from(
  new Set(
    rawCorsOrigins(data.CORS_ORIGINS).flatMap((origin) => {
      const normalized = normalizeCorsOrigin(origin);
      return normalized ? [normalized] : [];
    })
  )
);

export const env = {
  ...data,
  googleClientIds: data.GOOGLE_CLIENT_IDS.split(",")
    .map((clientId) => clientId.trim())
    .filter(Boolean),
  corsOrigins:
    configuredCorsOrigins.length > 0
      ? configuredCorsOrigins
      : data.NODE_ENV === "development"
        ? ["http://localhost:5173"]
        : [],
  trustProxyHops:
    data.TRUST_PROXY_HOPS ?? (data.NODE_ENV === "production" ? 1 : 0),
};
