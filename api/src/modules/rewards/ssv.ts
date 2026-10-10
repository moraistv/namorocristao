import { createPublicKey, verify, type KeyObject } from "crypto";

/**
 * Verificação do callback SSV (server-side verification) de anúncios premiados.
 *
 * O Google chama a URL configurada no bloco Premiado com os parâmetros em ordem
 * alfabética e, no fim, `signature` e `key_id`. O conteúdo assinado é toda a
 * query string antes de `&signature=`. A assinatura é ECDSA/SHA-256 (DER) em
 * base64 "web-safe" e as chaves públicas vêm do servidor de chaves do Google.
 * Este módulo é puro (sem banco/env) para poder ser testado isoladamente.
 */

const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
/** O Google pede cache de no máximo 24h; renovamos antes disso. */
const KEY_CACHE_MS = 6 * 60 * 60 * 1000;
/**
 * Intervalo mínimo entre buscas ao servidor de chaves (rotação/erros). Curto o
 * bastante para uma chave nova valer nas repetições do Google (5 tentativas em
 * ~5s) e longo o bastante para um `key_id` falso não martelar o servidor.
 */
const MIN_REFETCH_MS = 10 * 1000;
const FETCH_TIMEOUT_MS = 5000;

/** Callback malformado, com chave desconhecida ou assinatura inválida. */
export class SsvInvalidError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SsvInvalidError";
  }
}

/** Não foi possível obter as chaves públicas do Google agora. */
export class SsvKeysUnavailableError extends Error {
  constructor() {
    super("Chaves de verificação do Google indisponíveis");
    this.name = "SsvKeysUnavailableError";
  }
}

type KeyMap = Map<number, KeyObject>;
export type SsvKeyResolver = (keyId: number) => Promise<KeyObject | null>;

let cache: { keys: KeyMap; fetchedAt: number } | null = null;
let lastAttemptAt = 0;
let inflight: Promise<KeyMap> | null = null;

async function downloadKeys(): Promise<KeyMap> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(KEYS_URL, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = (await response.json()) as {
      keys?: Array<{ keyId?: number | string; base64?: string }>;
    };
    const keys: KeyMap = new Map();
    for (const item of body.keys ?? []) {
      const keyId = Number(item.keyId);
      if (!Number.isSafeInteger(keyId) || typeof item.base64 !== "string") {
        continue;
      }
      keys.set(
        keyId,
        createPublicKey({
          key: Buffer.from(item.base64, "base64"),
          format: "der",
          type: "spki",
        })
      );
    }
    if (keys.size === 0) throw new Error("nenhuma chave publicada");
    return keys;
  } finally {
    clearTimeout(timer);
  }
}

function refreshKeys(): Promise<KeyMap> {
  if (inflight) return inflight;
  lastAttemptAt = Date.now();
  inflight = downloadKeys()
    .then((keys) => {
      cache = { keys, fetchedAt: Date.now() };
      return keys;
    })
    .finally(() => {
      inflight = null;
    });
  return inflight;
}

/** Chave pública do Google para o `key_id` informado (com cache e rotação). */
export const getVerifierKey: SsvKeyResolver = async (keyId) => {
  const now = Date.now();
  const cached = cache?.keys.get(keyId) ?? null;
  const fresh = cache !== null && now - cache.fetchedAt < KEY_CACHE_MS;
  if (fresh && cached) return cached;

  // Cache vencido ou chave desconhecida (possível rotação): busca de novo,
  // respeitando o intervalo mínimo entre tentativas.
  if (inflight !== null || now - lastAttemptAt >= MIN_REFETCH_MS) {
    try {
      const keys = await refreshKeys();
      return keys.get(keyId) ?? null;
    } catch {
      // Cai para o cache antigo, se houver.
    }
  }
  if (cached) return cached;
  if (cache) return null;
  throw new SsvKeysUnavailableError();
};

/**
 * Valida a assinatura da query string recebida (sem o "?") e devolve os
 * parâmetros já decodificados. Lança SsvInvalidError se algo não bater.
 */
export async function verifySsvQuery(
  rawQuery: string,
  resolveKey: SsvKeyResolver = getVerifierKey
): Promise<URLSearchParams> {
  const marker = "&signature=";
  const signatureIndex = rawQuery.indexOf(marker);
  if (signatureIndex <= 0) throw new SsvInvalidError("assinatura ausente");

  const signedContent = rawQuery.slice(0, signatureIndex);
  const tail = rawQuery.slice(signatureIndex + 1);
  const match = /^signature=([A-Za-z0-9_\-%=]+)&key_id=(\d{1,15})$/.exec(tail);
  if (!match) throw new SsvInvalidError("assinatura em formato inválido");

  let signature: Buffer;
  try {
    signature = Buffer.from(decodeURIComponent(match[1]), "base64url");
  } catch {
    throw new SsvInvalidError("assinatura em formato inválido");
  }
  if (signature.length === 0) {
    throw new SsvInvalidError("assinatura em formato inválido");
  }

  const key = await resolveKey(Number(match[2]));
  if (!key) throw new SsvInvalidError("chave desconhecida");

  let valid = false;
  try {
    valid = verify(
      "sha256",
      Buffer.from(signedContent, "utf8"),
      { key, dsaEncoding: "der" },
      signature
    );
  } catch {
    valid = false;
  }
  if (!valid) throw new SsvInvalidError("assinatura inválida");

  return new URLSearchParams(signedContent);
}
