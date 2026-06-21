import { prisma } from "../config/prisma";
import { emitToUser } from "../sockets";

/**
 * Envio de push. Funciona em dois níveis:
 *  1) SEMPRE: persiste a notificação (tabela notifications) e emite via socket
 *     ("notification:new") — aparece no app em tempo real / na lista.
 *  2) SE `FCM_SERVER_KEY` estiver no .env: envia push real via FCM (background).
 *
 * Assim o recurso já funciona em dev e fica 100% pronto pra produção: basta
 * adicionar a server key do Firebase Cloud Messaging.
 */

const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY || "";

async function sendFcm(tokens: string[], title: string, body: string, data?: Record<string, string>) {
  if (!FCM_SERVER_KEY || tokens.length === 0) return;
  try {
    // FCM legacy HTTP (simples; troque por HTTP v1 + service account quando quiser).
    await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        registration_ids: tokens,
        notification: { title, body },
        data: data ?? {},
        priority: "high",
      }),
    });
  } catch {
    // push não pode quebrar o fluxo
  }
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
    const tokens = await prisma.deviceToken.findMany({ where: { userId }, select: { token: true } });
    await sendFcm(tokens.map((t) => t.token), title, body, opts?.data);
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
  if (!FCM_SERVER_KEY) return;
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
