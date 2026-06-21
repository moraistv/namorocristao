import { prisma } from "../config/prisma";
import { emitToUser } from "../sockets";
import { JWT } from "google-auth-library";

/**
 * Envio de push. Funciona em dois níveis:
 *  1) SEMPRE: persiste a notificação (tabela notifications) e emite via socket
 *     ("notification:new") — aparece no app em tempo real / na lista.
 *  2) SE o Firebase estiver configurado (service account no .env): envia push
 *     real via FCM HTTP v1 (funciona com o app fechado/background).
 *
 * Usa o FCM HTTP v1 (a API legada com "server key" foi desativada pelo Google).
 * Variáveis necessárias no .env:
 *   FIREBASE_PROJECT_ID
 *   FIREBASE_CLIENT_EMAIL
 *   FIREBASE_PRIVATE_KEY   (com \n escapados; trocamos por quebras reais)
 */

const FB_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "";
const FB_CLIENT_EMAIL = process.env.FIREBASE_CLIENT_EMAIL || "";
const FB_PRIVATE_KEY = (process.env.FIREBASE_PRIVATE_KEY || "").replace(/\\n/g, "\n");

const fcmEnabled = Boolean(FB_PROJECT_ID && FB_CLIENT_EMAIL && FB_PRIVATE_KEY);

let jwtClient: JWT | null = null;
function getJwt(): JWT {
  if (!jwtClient) {
    jwtClient = new JWT({
      email: FB_CLIENT_EMAIL,
      key: FB_PRIVATE_KEY,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
  }
  return jwtClient;
}

/** Token de acesso OAuth (cacheado até ~1min antes de expirar). */
let cachedToken: { value: string; exp: number } | null = null;
async function getAccessToken(): Promise<string | null> {
  if (!fcmEnabled) return null;
  const now = Date.now();
  if (cachedToken && cachedToken.exp - 60000 > now) return cachedToken.value;
  try {
    const res = await getJwt().authorize();
    if (!res.access_token) return null;
    cachedToken = {
      value: res.access_token,
      exp: res.expiry_date ?? now + 50 * 60000,
    };
    return cachedToken.value;
  } catch {
    return null;
  }
}

/** Envia uma mensagem FCM v1 para um token. Remove o token se for inválido. */
async function sendToToken(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    const resp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FB_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: data ?? {},
            android: { priority: "high" },
          },
        }),
      }
    );
    if (resp.status === 404 || resp.status === 400) {
      // Token expirado/inválido → limpa do banco.
      await prisma.deviceToken.deleteMany({ where: { token } }).catch(() => {});
    }
  } catch {
    // push nunca pode quebrar o fluxo
  }
}

/** Dispara push FCM v1 para todos os tokens informados. */
async function sendFcm(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
) {
  if (!fcmEnabled || tokens.length === 0) return;
  const accessToken = await getAccessToken();
  if (!accessToken) return;
  await Promise.all(
    tokens.map((t) => sendToToken(accessToken, t, title, body, data))
  );
}

/** Notifica um usuário: persiste + socket + push (se configurado). */
export async function notifyUser(
  userId: string,
  title: string,
  body: string,
  opts?: { type?: string; data?: Record<string, string> }
) {
  try {
    const notif = await prisma.notification.create({
      data: { userId, title, body, type: opts?.type, data: opts?.data ?? undefined },
    });
    emitToUser(userId, "notification:new", {
      id: notif.id,
      title,
      body,
      type: opts?.type ?? null,
      data: opts?.data ?? null,
      createdAt: notif.createdAt,
    });
    const tokens = await prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    // O FCM exige data como strings; injeta o type pra navegação no app.
    const data: Record<string, string> = { ...(opts?.data ?? {}) };
    if (opts?.type) data.type = opts.type;
    await sendFcm(tokens.map((t) => t.token), title, body, data);
  } catch {
    // ignora falhas de notificação
  }
}

/** Envia para vários usuários (broadcast). Retorna quantos receberam. */
export async function notifyUsers(
  userIds: string[],
  title: string,
  body: string,
  opts?: { type?: string; data?: Record<string, string> }
) {
  let count = 0;
  for (const id of userIds) {
    await notifyUser(id, title, body, opts);
    count++;
  }
  return count;
}

/** Push de background apenas (FCM), sem persistir notificação — ex.: novas mensagens. */
export async function pushOnly(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  if (!fcmEnabled) return;
  try {
    const tokens = await prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    await sendFcm(tokens.map((t) => t.token), title, body, data);
  } catch {
    // ignora
  }
}
