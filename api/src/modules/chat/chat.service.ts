import { MessageType } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { pushOnly } from "../../lib/push";
import { triggerBotReply } from "../chatbot/chatbot.service";

/** Garante que o usuário faz parte do match e que ele está ativo. Retorna o id do outro. */
export async function assertMembership(userId: string, matchId: string) {
  const match = await prisma.match.findUnique({ where: { id: matchId } });
  if (!match || !match.isActive) {
    throw new AppError("Match não encontrado ou encerrado", 404);
  }
  if (match.userAId !== userId && match.userBId !== userId) {
    throw new AppError("Você não faz parte deste match", 403);
  }
  const otherId = match.userAId === userId ? match.userBId : match.userAId;

  // Bloqueio em qualquer sentido impede o chat.
  const block = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: userId, blockedId: otherId },
        { blockerId: otherId, blockedId: userId },
      ],
    },
  });
  if (block) throw new AppError("Conversa indisponível (bloqueio)", 403);

  return { match, otherId };
}

export async function sendMessage(params: {
  senderId: string;
  matchId: string;
  type?: MessageType;
  content: string;
}) {
  const { senderId, matchId } = params;
  const content = params.content?.trim();
  if (!content) throw new AppError("Mensagem vazia", 422);

  const { otherId } = await assertMembership(senderId, matchId);

  const message = await prisma.message.create({
    data: {
      matchId,
      senderId,
      type: params.type ?? "TEXT",
      content,
    },
  });

  // Push de background ao destinatário (se FCM configurado).
  const sender = await prisma.profile.findUnique({
    where: { userId: senderId },
    select: { fullName: true },
  });
  const preview =
    params.type === "IMAGE"
      ? "📷 Foto"
      : params.type === "AUDIO"
      ? "🎤 Áudio"
      : params.type === "GIFT"
      ? "🎁 Presente"
      : content.slice(0, 80);
  pushOnly(otherId, sender?.fullName ?? "Nova mensagem", preview, { matchId, type: "message" });

  // Se o destinatário for um BOT/Modelo, ele responde sozinho (regra → IA → fallback).
  triggerBotReply({
    matchId,
    botUserId: otherId,
    fromUserId: senderId,
    content,
    type: params.type ?? "TEXT",
  });

  return { message, otherId };
}

/** Envia um presente: valida créditos, debita do remetente e cria uma mensagem GIFT. */
export async function sendGift(params: { senderId: string; matchId: string; giftId: string }) {
  const { senderId, matchId, giftId } = params;
  const { otherId } = await assertMembership(senderId, matchId);

  const gift = await prisma.gift.findUnique({ where: { id: giftId } });
  if (!gift || !gift.active) throw new AppError("Presente indisponível", 404);

  const result = await prisma.$transaction(async (tx) => {
    const sender = await tx.user.findUnique({ where: { id: senderId } });
    if (!sender) throw new AppError("Usuário não encontrado", 404);
    if (sender.credits < gift.costCredits) {
      throw new AppError("Créditos insuficientes", 402);
    }
    const updated = await tx.user.update({
      where: { id: senderId },
      data: { credits: { decrement: gift.costCredits } },
    });
    const message = await tx.message.create({
      data: {
        matchId,
        senderId,
        type: "GIFT",
        content: JSON.stringify({
          giftId: gift.id,
          name: gift.name,
          imageUrl: gift.imageUrl,
          cost: gift.costCredits,
        }),
      },
    });
    return { message, credits: updated.credits };
  });

  return { message: result.message, otherId, credits: result.credits };
}

export async function getHistory(
  userId: string,
  matchId: string,
  opts: { limit?: number; before?: string }
) {
  await assertMembership(userId, matchId);

  const limit = Math.min(Math.max(opts.limit ?? 30, 1), 100);
  const messages = await prisma.message.findMany({
    where: {
      matchId,
      ...(opts.before ? { createdAt: { lt: new Date(opts.before) } } : {}),
    },
    orderBy: { createdAt: "desc" },
    take: limit,
  });

  // Devolve em ordem cronológica crescente.
  return messages.reverse();
}

export async function markRead(userId: string, matchId: string) {
  const { otherId } = await assertMembership(userId, matchId);
  const result = await prisma.message.updateMany({
    where: { matchId, senderId: otherId, readAt: null },
    data: { readAt: new Date() },
  });
  return result.count;
}
