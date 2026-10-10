import { Request, Response } from "express";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import {
  publicProfileInclude,
  publicVirtualFlags,
  sanitizePublicMedia,
} from "../../lib/publicProfile";
import { emitToUser } from "../../sockets";
import * as chat from "../chat/chat.service";

/** Helper: acha um usuário pelo e-mail (com perfil). */
async function findByEmail(email: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) throw new AppError(`Usuário ${email} não encontrado`, 404);
  const profile = await prisma.profile.findUnique({ where: { userId: user.id } });
  return { user, profile };
}

function order(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}

/**
 * POST /dev/live-match/:email
 * Reciproca uma curtida pendente recebida pelo alvo → cria match → emite
 * "match:new" em tempo real para o alvo (mostra a tela "É um Match!").
 */
export async function liveMatch(req: Request, res: Response) {
  const { user: target } = await findByEmail(req.params.email);

  // Curtidas recebidas que ainda não viraram match.
  const incoming = await prisma.interaction.findMany({
    where: { toUserId: target.id, type: { in: ["LIKE", "SUPERLIKE"] } },
    orderBy: { createdAt: "desc" },
  });

  let chosen: string | null = null;
  for (const interaction of incoming) {
    const [firstId, secondId] = order(target.id, interaction.fromUserId);
    const existing = await prisma.match.findUnique({
      where: {
        userAId_userBId: { userAId: firstId, userBId: secondId },
      },
    });
    if (!existing) {
      chosen = interaction.fromUserId;
      break;
    }
  }
  if (!chosen) {
    throw new AppError("Sem curtidas pendentes para virar match", 400);
  }

  await prisma.interaction.upsert({
    where: {
      fromUserId_toUserId: { fromUserId: target.id, toUserId: chosen },
    },
    create: {
      fromUserId: target.id,
      toUserId: chosen,
      type: "LIKE",
      superLikeUsedBonus: false,
    },
    update: { type: "LIKE", superLikeUsedBonus: false },
  });
  const [userAId, userBId] = order(target.id, chosen);
  const match = await prisma.match.upsert({
    where: { userAId_userBId: { userAId, userBId } },
    create: { userAId, userBId, isActive: true },
    update: { isActive: true },
  });

  const other = await prisma.profile.findUnique({
    where: { userId: chosen },
    include: publicProfileInclude,
  });
  const media = other
    ? sanitizePublicMedia(other)
    : { mediaFiles: [], profilePicture: null };

  const existing = await prisma.message.count({ where: { matchId: match.id } });
  if (existing === 0) {
    const systemMessage = await prisma.message.create({
      data: {
        matchId: match.id,
        senderId: chosen,
        type: "SYSTEM",
        content: "🎉 Vocês deram match! Que tal começar a conversa? 💛",
      },
    });
    emitToUser(target.id, "message:new", systemMessage);
    emitToUser(chosen, "message:new", systemMessage);
  }

  emitToUser(target.id, "match:new", {
    matchId: match.id,
    withUserId: chosen,
    name: other?.fullName ?? "Alguém",
    photo: media.profilePicture,
    ...publicVirtualFlags(other?.user.isBot ?? false),
  });

  res.json({
    ok: true,
    matchId: match.id,
    withUser: other?.fullName ?? "Alguém",
  });
}

/**
 * POST /dev/live-likes/:email  { count? }
 * Cria curtidas (LIKE) de outros usuários PARA o alvo, para aparecerem em
 * "Quem te curtiu" / admiradores. Não cria match (curtida pendente).
 */
export async function liveLikes(req: Request, res: Response) {
  const { user: target } = await findByEmail(req.params.email);
  const count = Math.min(Math.max(Number(req.body?.count) || 1, 1), 50);

  const already = await prisma.interaction.findMany({
    where: { toUserId: target.id },
    select: { fromUserId: true },
  });
  const excludeIds = new Set([
    target.id,
    ...already.map((interaction) => interaction.fromUserId),
  ]);

  const profiles = await prisma.profile.findMany({
    where: { userId: { notIn: Array.from(excludeIds) } },
    orderBy: { createdAt: "desc" },
    take: count,
  });
  if (profiles.length === 0) {
    throw new AppError("Sem usuários disponíveis para curtir o alvo", 400);
  }

  let created = 0;
  for (const profile of profiles) {
    await prisma.interaction.create({
      data: {
        fromUserId: profile.userId,
        toUserId: target.id,
        type: "LIKE",
        superLikeUsedBonus: false,
      },
    });
    created++;
  }

  res.json({ ok: true, likesSent: created });
}

export async function liveMessage(req: Request, res: Response) {
  const { user: target } = await findByEmail(req.params.email);
  const count = Math.min(Math.max(Number(req.body?.count) || 1, 1), 20);

  const matches = await prisma.match.findMany({
    where: {
      isActive: true,
      OR: [{ userAId: target.id }, { userBId: target.id }],
    },
    orderBy: { createdAt: "desc" },
  });
  if (matches.length === 0) {
    throw new AppError("O alvo não tem matches", 400);
  }

  const samples = [
    "Oi! Como foi seu dia? 😊",
    "Tô gostando muito de conversar com você 💛",
    "Você vai no culto domingo?",
    "Qual seu louvor preferido?",
    "Podemos marcar um café? ☕",
    "Que bom te conhecer aqui 🙏",
    "Bom dia! Que Deus abençoe seu dia ✨",
    "Adorei seu perfil!",
    "Você curte missões também?",
    "Tô com saudade da nossa conversa 😅",
  ];

  let sent = 0;
  for (let index = 0; index < count; index++) {
    const match = matches[index % matches.length];
    const senderId =
      match.userAId === target.id ? match.userBId : match.userAId;
    const text = (req.body?.text as string) || samples[index % samples.length];
    const { message } = await chat.sendMessage({
      senderId,
      matchId: match.id,
      content: text,
      type: "TEXT",
    });
    emitToUser(target.id, "message:new", message);
    sent++;
  }

  res.json({ ok: true, sent });
}
