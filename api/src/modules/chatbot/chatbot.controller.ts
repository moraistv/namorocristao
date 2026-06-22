import { Request, Response } from "express";
import { randomUUID } from "crypto";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { ageFromBirthday } from "../../lib/age";
import { emitToUser } from "../../sockets";
import { pushOnly } from "../../lib/push";

const PERSONALITIES = ["ALL", "SHY", "FUNNY", "EXTROVERT"] as const;

// ───────────────────────── Regras do chatbot ─────────────────────────

const ruleSchema = z.object({
  category: z.string().min(1).max(60),
  personality: z.enum(PERSONALITIES).default("ALL"),
  priority: z.number().int().min(0).max(10).default(5),
  keywords: z.array(z.string().max(60)).default([]),
  responses: z.array(z.string().max(500)).default([]),
  active: z.boolean().default(true),
});

// GET /api/admin/chatbot/rules
export async function listRules(_req: Request, res: Response) {
  const rules = await prisma.chatbotRule.findMany({
    orderBy: [{ priority: "desc" }, { category: "asc" }],
  });
  res.json({ rules });
}

// POST /api/admin/chatbot/rules
export async function createRule(req: Request, res: Response) {
  const data = ruleSchema.parse(req.body);
  const rule = await prisma.chatbotRule.create({ data });
  res.status(201).json({ rule });
}

// PUT /api/admin/chatbot/rules/:id
export async function updateRule(req: Request, res: Response) {
  const data = ruleSchema.partial().parse(req.body);
  const rule = await prisma.chatbotRule.update({ where: { id: req.params.id }, data });
  res.json({ rule });
}

// DELETE /api/admin/chatbot/rules/:id
export async function deleteRule(req: Request, res: Response) {
  await prisma.chatbotRule.delete({ where: { id: req.params.id } });
  res.json({ ok: true });
}

// ───────────────────────── Analytics ─────────────────────────

// GET /api/admin/chatbot/analytics
export async function analytics(_req: Request, res: Response) {
  const [total, fallbacks, grouped, recentFallbacks] = await Promise.all([
    prisma.chatbotLog.count(),
    prisma.chatbotLog.count({ where: { matchedCategory: null } }),
    prisma.chatbotLog.groupBy({
      by: ["matchedCategory"],
      _count: { _all: true },
      where: { matchedCategory: { not: null } },
    }),
    prisma.chatbotLog.findMany({
      where: { matchedCategory: null },
      orderBy: { createdAt: "desc" },
      take: 20,
      select: { id: true, message: true, language: true, usedAi: true, createdAt: true },
    }),
  ]);

  const matched = total - fallbacks;
  const matchRate = total > 0 ? Math.round((matched / total) * 1000) / 10 : 0;
  const topCategories = grouped
    .map((g) => ({ category: g.matchedCategory as string, count: g._count._all }))
    .sort((a, b) => b.count - a.count);

  res.json({
    total,
    fallbacks,
    matched,
    matchRate,
    uniqueCategories: topCategories.length,
    topCategories,
    recentFallbacks,
  });
}

// ───────────────────────── Configuração de IA ─────────────────────────

const settingsSchema = z.object({
  aiEnabled: z.boolean().optional(),
  aiProvider: z.string().max(40).optional(),
  aiModel: z.string().max(60).optional(),
  aiApiKey: z.string().max(200).nullish(),
  aiSystemPrompt: z.string().max(1000).optional(),
  replyMinMs: z.number().int().min(0).max(60000).optional(),
  replyMaxMs: z.number().int().min(0).max(120000).optional(),
  fallbackText: z.string().max(500).optional(),
});

// GET /api/admin/chatbot/settings
export async function getSettings(_req: Request, res: Response) {
  const s = await prisma.botSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
  // Não expõe a chave inteira (só indica se há).
  res.json({ settings: { ...s, aiApiKey: undefined, hasApiKey: !!s.aiApiKey } });
}

// PUT /api/admin/chatbot/settings
export async function updateSettings(req: Request, res: Response) {
  const data = settingsSchema.parse(req.body);
  // String vazia na chave = manter a atual (não apaga sem querer).
  const clean: any = { ...data };
  if (clean.aiApiKey === "" || clean.aiApiKey === undefined) delete clean.aiApiKey;
  const s = await prisma.botSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...clean },
    update: clean,
  });
  res.json({ settings: { ...s, aiApiKey: undefined, hasApiKey: !!s.aiApiKey } });
}

// ───────────────────────── Bots / Modelos ─────────────────────────

const botSchema = z.object({
  fullName: z.string().min(2).max(80),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  age: z.number().int().min(18).max(99),
  about: z.string().max(1000).optional().nullable(),
  city: z.string().max(80).optional().nullable(),
  interests: z.array(z.string().max(40)).max(10).optional(),
  photos: z.array(z.string().url()).max(6).optional(),
  personality: z.enum(PERSONALITIES).default("ALL"),
  aiEnabled: z.boolean().default(false),
  latitude: z.number().optional().nullable(),
  longitude: z.number().optional().nullable(),
});

function birthdayForAge(age: number): Date {
  const d = new Date();
  d.setFullYear(d.getFullYear() - age);
  d.setMonth(0, 1);
  d.setHours(0, 0, 0, 0);
  return d;
}

// GET /api/admin/bots
export async function listBots(_req: Request, res: Response) {
  const bots = await prisma.user.findMany({
    where: { isBot: true },
    include: { profile: true },
    orderBy: { createdAt: "desc" },
  });
  const result = await Promise.all(
    bots.map(async (b) => {
      const matchCount = await prisma.match.count({
        where: { isActive: true, OR: [{ userAId: b.id }, { userBId: b.id }] },
      });
      return {
        userId: b.id,
        fullName: b.profile?.fullName ?? "(sem perfil)",
        gender: b.profile?.gender ?? null,
        age: b.profile?.birthday ? ageFromBirthday(b.profile.birthday) : null,
        about: b.profile?.about ?? null,
        city: b.profile?.city ?? null,
        interests: b.profile?.interests ?? [],
        photos: b.profile?.mediaFiles ?? [],
        profilePicture: b.profile?.profilePicture ?? null,
        personality: b.botPersonality ?? "ALL",
        aiEnabled: b.botAiEnabled,
        matchCount,
        createdAt: b.createdAt,
      };
    })
  );
  res.json({ bots: result });
}

// POST /api/admin/bots
export async function createBot(req: Request, res: Response) {
  const d = botSchema.parse(req.body);
  const user = await prisma.user.create({
    data: {
      email: `bot-${randomUUID()}@bots.local`,
      emailVerified: true,
      isBot: true,
      botPersonality: d.personality,
      botAiEnabled: d.aiEnabled,
      profile: {
        create: {
          fullName: d.fullName,
          gender: d.gender,
          birthday: birthdayForAge(d.age),
          about: d.about ?? null,
          city: d.city ?? null,
          interests: d.interests ?? [],
          mediaFiles: d.photos ?? [],
          profilePicture: d.photos?.[0] ?? null,
          latitude: d.latitude ?? null,
          longitude: d.longitude ?? null,
          isOnline: true,
          lastActiveAt: new Date(),
        },
      },
    },
  });
  res.status(201).json({ ok: true, userId: user.id });
}

// PUT /api/admin/bots/:userId
export async function updateBot(req: Request, res: Response) {
  const userId = req.params.userId;
  const d = botSchema.partial().parse(req.body);
  const target = await prisma.user.findUnique({ where: { id: userId } });
  if (!target || !target.isBot) throw new AppError("Bot não encontrado", 404);

  await prisma.user.update({
    where: { id: userId },
    data: {
      ...(d.personality !== undefined ? { botPersonality: d.personality } : {}),
      ...(d.aiEnabled !== undefined ? { botAiEnabled: d.aiEnabled } : {}),
    },
  });
  await prisma.profile.update({
    where: { userId },
    data: {
      ...(d.fullName !== undefined ? { fullName: d.fullName } : {}),
      ...(d.gender !== undefined ? { gender: d.gender } : {}),
      ...(d.age !== undefined ? { birthday: birthdayForAge(d.age) } : {}),
      ...(d.about !== undefined ? { about: d.about } : {}),
      ...(d.city !== undefined ? { city: d.city } : {}),
      ...(d.interests !== undefined ? { interests: d.interests } : {}),
      ...(d.photos !== undefined
        ? { mediaFiles: d.photos, profilePicture: d.photos[0] ?? null }
        : {}),
      ...(d.latitude !== undefined ? { latitude: d.latitude } : {}),
      ...(d.longitude !== undefined ? { longitude: d.longitude } : {}),
    },
  });
  res.json({ ok: true });
}

// DELETE /api/admin/bots/:userId
export async function deleteBot(req: Request, res: Response) {
  const userId = req.params.userId;
  const target = await prisma.user.findUnique({ where: { id: userId } });
  if (!target || !target.isBot) throw new AppError("Bot não encontrado", 404);

  // Limpa matches/mensagens/interações do bot (sem FK p/ userId em interactions/matches).
  const matches = await prisma.match.findMany({
    where: { OR: [{ userAId: userId }, { userBId: userId }] },
    select: { id: true },
  });
  const matchIds = matches.map((m) => m.id);
  await prisma.$transaction([
    prisma.message.deleteMany({ where: { matchId: { in: matchIds } } }),
    prisma.match.deleteMany({ where: { id: { in: matchIds } } }),
    prisma.interaction.deleteMany({
      where: { OR: [{ fromUserId: userId }, { toUserId: userId }] },
    }),
    prisma.user.delete({ where: { id: userId } }), // cascade apaga o profile
  ]);
  res.json({ ok: true });
}

// ───────────────────────── Disparo de Modelos (broadcast) ─────────────────────────

const broadcastSchema = z.object({
  text: z.string().max(500).optional(),
  imageUrl: z.string().url().optional(),
  audience: z.enum(["all", "free", "premium", "online"]).default("all"),
  limit: z.number().int().min(1).max(2000).optional(),
});

// POST /api/admin/bots/:userId/broadcast — o Modelo manda uma mensagem para vários usuários
export async function broadcastFromBot(req: Request, res: Response) {
  const botId = req.params.userId;
  const bot = await prisma.user.findUnique({
    where: { id: botId },
    include: { profile: { select: { fullName: true } } },
  });
  if (!bot || !bot.isBot) throw new AppError("Modelo não encontrado", 404);

  const { text, imageUrl, audience, limit } = broadcastSchema.parse(req.body);
  if (!text && !imageUrl) throw new AppError("Informe texto ou imagem", 400);
  
  const cap = limit ?? 500;
  const now = new Date();

  // Seleciona os usuários-alvo (reais, não banidos, não excluídos).
  let targetIds: string[] = [];
  if (audience === "online") {
    const profs = await prisma.profile.findMany({
      where: { isOnline: true, user: { isBot: false, isBanned: false, deletedAt: null } },
      select: { userId: true },
      take: cap,
    });
    targetIds = profs.map((p) => p.userId);
  } else {
    const where: any = { isBot: false, isBanned: false, deletedAt: null };
    if (audience === "premium") where.OR = [{ isPremium: true }, { premiumUntil: { gt: now } }];
    if (audience === "free") {
      where.isPremium = false;
      where.AND = [{ OR: [{ premiumUntil: null }, { premiumUntil: { lte: now } }] }];
    }
    const us = await prisma.user.findMany({ where, select: { id: true }, take: cap });
    targetIds = us.map((u) => u.id);
  }

  // Registra o broadcast no histórico
  const broadcast = await prisma.botBroadcast.create({
    data: {
      botUserId: botId,
      audience,
      messageType: imageUrl ? "image" : "text",
      text: text || null,
      imageUrl: imageUrl || null,
      targetedCount: targetIds.length,
      sentCount: 0,
      sentAt: now,
    },
  });

  const botName = bot.profile?.fullName ?? "Mensagem";
  let sent = 0;
  for (const uid of targetIds) {
    if (uid === botId) continue;
    const [a, b] = uid < botId ? [uid, botId] : [botId, uid];
    const match = await prisma.match.upsert({
      where: { userAId_userBId: { userAId: a, userBId: b } },
      create: { userAId: a, userBId: b, isActive: true },
      update: { isActive: true },
    });
    await prisma.interaction.upsert({
      where: { fromUserId_toUserId: { fromUserId: botId, toUserId: uid } },
      create: { fromUserId: botId, toUserId: uid, type: "LIKE" },
      update: {},
    });
    const msgType = imageUrl ? "IMAGE" : "TEXT";
    const msgContent = imageUrl || text || "";
    const msg = await prisma.message.create({
      data: { matchId: match.id, senderId: botId, type: msgType, content: msgContent },
    });
    emitToUser(uid, "message:new", msg);
    const pushText = text || "📷 Foto";
    pushOnly(uid, botName, pushText.slice(0, 80), { matchId: match.id, type: "message" });
    sent++;
  }

  // Atualiza o contador de enviados
  await prisma.botBroadcast.update({
    where: { id: broadcast.id },
    data: { sentCount: sent, deliveredCount: sent },
  });

  res.json({ ok: true, sent, broadcastId: broadcast.id });
}

// GET /api/admin/bots/:userId/broadcasts — histórico de disparos
export async function getBroadcasts(req: Request, res: Response) {
  const botId = req.params.userId;
  const history = await prisma.botBroadcast.findMany({
    where: { botUserId: botId },
    orderBy: { sentAt: "desc" },
    take: 20,
  });
  res.json({ history: history.map((h) => ({ id: h.id, text: h.text || "📷 Imagem", audience: h.audience, sent: h.sentCount, sentAt: h.sentAt })) });
}
