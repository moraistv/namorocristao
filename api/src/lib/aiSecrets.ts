import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
  scryptSync,
} from "crypto";
import { env } from "../config/env";

export const AI_PROVIDERS = ["deepseek", "openai"] as const;
export type AiProvider = (typeof AI_PROVIDERS)[number];
export type AiKeySource = "environment" | "database" | null;

const ENVELOPE_PREFIX = "enc:v1";
const IV_BYTES = 12;
const KEY_BYTES = 32;
const KEY_SALT = "namoro-cristao:ai-secrets:v1";

function encryptionKeyMaterial(): string {
  if (env.AI_SECRET_ENCRYPTION_KEY) return env.AI_SECRET_ENCRYPTION_KEY;
  if (env.NODE_ENV !== "production") return env.JWT_REFRESH_SECRET;
  // A validação de ambiente impede este caminho; nunca use JWT como fallback
  // em produção, mesmo se este módulo for inicializado isoladamente.
  throw new Error("AI_SECRET_ENCRYPTION_KEY é obrigatória em produção");
}

const encryptionKey = scryptSync(
  encryptionKeyMaterial(),
  KEY_SALT,
  KEY_BYTES
);

export function parseAiProvider(
  value: string | null | undefined
): AiProvider | null {
  const normalized = value?.trim().toLowerCase();
  return normalized === "deepseek" || normalized === "openai"
    ? normalized
    : null;
}

/** Impede que nomes conhecidos de um fornecedor sejam enviados ao endpoint do outro. */
export function isAiModelCompatible(
  provider: AiProvider,
  model: string
): boolean {
  const normalized = model.trim().toLowerCase();
  if (provider === "deepseek") {
    return normalized === "deepseek-chat" || normalized === "deepseek-reasoner";
  }
  const baseModel = normalized.startsWith("ft:")
    ? normalized.slice(3)
    : normalized;
  return /^(?:gpt-|chatgpt-|o(?:1|3|4)(?:-|$))/.test(baseModel);
}

/** Criptografa novas credenciais no formato versionado AES-256-GCM. */
export function encryptAiSecret(value: string): string {
  const plaintext = value.trim();
  if (!plaintext) throw new Error("A credencial de IA não pode ser vazia");

  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  return [
    ENVELOPE_PREFIX,
    iv.toString("base64"),
    authTag.toString("base64"),
    ciphertext.toString("base64"),
  ].join(":");
}

/** Lê o envelope criptografado e mantém compatibilidade com texto puro legado. */
export function decryptAiSecret(
  value: string | null | undefined
): string | null {
  if (!value) return null;
  if (!value.startsWith(`${ENVELOPE_PREFIX}:`)) {
    return value.trim() || null;
  }

  const parts = value.slice(ENVELOPE_PREFIX.length + 1).split(":");
  if (parts.length !== 3) return null;

  try {
    const [ivEncoded, authTagEncoded, ciphertextEncoded] = parts;
    const iv = Buffer.from(ivEncoded, "base64");
    const authTag = Buffer.from(authTagEncoded, "base64");
    const ciphertext = Buffer.from(ciphertextEncoded, "base64");
    if (iv.length !== IV_BYTES || authTag.length !== 16) return null;

    const decipher = createDecipheriv("aes-256-gcm", encryptionKey, iv);
    decipher.setAuthTag(authTag);
    const plaintext = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]).toString("utf8");
    return plaintext || null;
  } catch {
    return null;
  }
}

export function resolveAiCredential(
  provider: AiProvider,
  storedValue: string | null | undefined,
  storedProvider: string | null | undefined
): { apiKey: string | null; source: AiKeySource } {
  const environmentValue =
    provider === "deepseek" ? env.DEEPSEEK_API_KEY : env.OPENAI_API_KEY;
  if (environmentValue) {
    return { apiKey: environmentValue, source: "environment" };
  }

  // Uma credencial persistida só pode sair do banco para o fornecedor ao qual
  // foi explicitamente vinculada. Provider ausente/inválido não é inferido.
  if (parseAiProvider(storedProvider) !== provider) {
    return { apiKey: null, source: null };
  }

  const databaseValue = decryptAiSecret(storedValue);
  return databaseValue
    ? { apiKey: databaseValue, source: "database" }
    : { apiKey: null, source: null };
}
