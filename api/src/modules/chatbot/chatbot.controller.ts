import { BotSettings, Prisma } from "@prisma/client";
import { randomUUID } from "crypto";
import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { ageFromBirthday } from "../../lib/age";
import {
  AI_PROVIDERS,
  AiProvider,
  encryptAiSecret,
  isAiModelCompatible,
  parseAiProvider,
  resolveAiCredential,
} from "../../lib/aiSecrets";
import { AppError } from "../../lib/errors";
import {
  BROADCAST_AUDIENCES,
  listBotBroadcasts,
  runBotBroadcast,
  serializeBroadcast,
} from "./chatbot.broadcast.service";

const PERSONALITIES = ["ALL", "SHY", "FUNNY", "EXTROVERT"] as const;
const RESPONSE_SOURCES = ["AI", "RULE", "FALLBACK"] as const;
const DEFAULT_AI_MODELS: Record<AiProvider, string> = {
  deepseek: "deepseek-chat",
  openai: "gpt-4o-mini",
};
type ResponseSource = (typeof RESPONSE_SOURCES)[number];

const aiModelSchema = z
  .string()
  .trim()
  .min(1)
  .max(100)
  .regex(/^[A-Za-z0-9][A-Za-z0-9._:/-]*$/, "Modelo de IA inválido");

function isResponseSource(value: string): value is ResponseSource {
  return RESPONSE_SOURCES.some((source) => source === value);
}

// ───────────────────────── Regras do chatbot ─────────────────────────

const ruleSchema = z.object({
  category: z.string().trim().min(1).max(60),
  personality: z.enum(PERSONALITIES).default("ALL"),
  priority: z.number().int().min(0).max(10).default(5),
  keywords: z.array(z.string().trim().min(1).max(60)).default([]),
  responses: z.array(z.string().trim().min(1).max(500)).default([]),
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
  const rule = await prisma.chatbotRule.update({
    where: { id: req.params.id },
    data,
  });
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
  const [total, groupedSources, groupedCategories, recentFallbacks] =
    await Promise.all([
      prisma.chatbotLog.count(),
      prisma.chatbotLog.groupBy({
        by: ["responseSource"],
        _count: { _all: true },
      }),
      prisma.chatbotLog.groupBy({
        by: ["matchedCategory"],
        _count: { _all: true },
        where: {
          responseSource: "RULE",
          matchedCategory: { not: null },
        },
      }),
      prisma.chatbotLog.findMany({
        where: { responseSource: "FALLBACK" },
        orderBy: { createdAt: "desc" },
        take: 20,
        select: {
          id: true,
          message: true,
          language: true,
          usedAi: true,
          responseSource: true,
          latencyMs: true,
          createdAt: true,
        },
      }),
    ]);

  const bySource: Record<ResponseSource, number> = {
    AI: 0,
    RULE: 0,
    FALLBACK: 0,
  };
  for (const group of groupedSources) {
    if (isResponseSource(group.responseSource)) {
      bySource[group.responseSource] = group._count._all;
    }
  }

  const matched = bySource.AI + bySource.RULE;
  const matchRate = total > 0 ? Math.round((matched / total) * 1000) / 10 : 0;
  const topCategories = groupedCategories
    .flatMap((group) =>
      group.matchedCategory
        ? [{ category: group.matchedCategory, count: group._count._all }]
        : []
    )
    .sort((a, b) => b.count - a.count);

  res.json({
    total,
    ai: bySource.AI,
    rules: bySource.RULE,
    fallbacks: bySource.FALLBACK,
    bySource,
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
  aiProvider: z.enum(AI_PROVIDERS).optional(),
  aiModel: aiModelSchema.optional(),
  aiApiKey: z.string().max(1000).nullish(),
  aiSystemPrompt: z.string().trim().min(1).max(4000).optional(),
  replyMinMs: z.number().int().min(0).max(60000).optional(),
  replyMaxMs: z.number().int().min(0).max(120000).optional(),
  fallbackText: z.string().trim().min(1).max(500).optional(),
  memoryEnabled: z.boolean().optional(),
  memoryRefreshMessages: z.number().int().min(2).max(100).optional(),
  recentMessageLimit: z.number().int().min(4).max(100).optional(),
});

function serializeSettings(settings: BotSettings) {
  const provider = parseAiProvider(settings.aiProvider);
  const credential = provider
    ? resolveAiCredential(
        provider,
        settings.aiApiKey,
        settings.aiApiKeyProvider
      )
    : { apiKey: null, source: null };
  const { aiApiKey: _hiddenApiKey, ...safeSettings } = settings;

  return {
    ...safeSettings,
    hasApiKey: Boolean(credential.apiKey),
    apiKeySource: credential.source,
  };
}

async function ensureSettings(): Promise<BotSettings> {
  return prisma.botSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
}

// GET /api/admin/chatbot/settings
export async function getSettings(_req: Request, res: Response) {
  const settings = await ensureSettings();
  res.json({ settings: serializeSettings(settings) });
}

// PUT /api/admin/chatbot/settings
export async function updateSettings(req: Request, res: Response) {
  const data = settingsSchema.parse(req.body);
  const current = await ensureSettings();
  const replyMinMs = data.replyMinMs ?? current.replyMinMs;
  const replyMaxMs = data.replyMaxMs ?? current.replyMaxMs;
  if (replyMaxMs < replyMinMs) {
    throw new AppError(
      "replyMaxMs deve ser maior ou igual a replyMinMs",
      422
    );
  }

  const effectiveProvider = parseAiProvider(
    data.aiProvider ?? current.aiProvider
  );
  const effectiveModel =
    data.aiModel ??
    (data.aiProvider
      ? DEFAULT_AI_MODELS[data.aiProvider]
      : current.aiModel);
  if (!effectiveProvider || !isAiModelCompatible(effectiveProvider, effectiveModel)) {
    throw new AppError(
      "O modelo global não pertence ao provider selecionado",
      422,
      undefined,
      "AI_MODEL_PROVIDER_MISMATCH"
    );
  }

  const updateData: Prisma.BotSettingsUpdateInput = {
    ...(data.aiEnabled !== undefined ? { aiEnabled: data.aiEnabled } : {}),
    ...(data.aiProvider !== undefined ? { aiProvider: data.aiProvider } : {}),
    ...(data.aiModel !== undefined
      ? { aiModel: data.aiModel }
      : data.aiProvider !== undefined
        ? { aiModel: DEFAULT_AI_MODELS[data.aiProvider] }
        : {}),
    ...(data.aiSystemPrompt !== undefined
      ? { aiSystemPrompt: data.aiSystemPrompt }
      : {}),
    ...(data.replyMinMs !== undefined ? { replyMinMs: data.replyMinMs } : {}),
    ...(data.replyMaxMs !== undefined ? { replyMaxMs: data.replyMaxMs } : {}),
    ...(data.fallbackText !== undefined
      ? { fallbackText: data.fallbackText }
      : {}),
    ...(data.memoryEnabled !== undefined
      ? { memoryEnabled: data.memoryEnabled }
      : {}),
    ...(data.memoryRefreshMessages !== undefined
      ? { memoryRefreshMessages: data.memoryRefreshMessages }
      : {}),
    ...(data.recentMessageLimit !== undefined
      ? { recentMessageLimit: data.recentMessageLimit }
      : {}),
  };

  // Ausente/vazia preserva a chave e seu vínculo; null limpa ambos.
  // Uma chave nova é vinculada ao provider efetivo desta atualização.
  if (data.aiApiKey === null) {
    updateData.aiApiKey = null;
    updateData.aiApiKeyProvider = null;
  } else if (data.aiApiKey?.trim()) {
    const keyProvider = parseAiProvider(
      data.aiProvider ?? current.aiProvider
    );
    if (!keyProvider) {
      throw new AppError("Provider de IA inválido", 422);
    }
    updateData.aiApiKey = encryptAiSecret(data.aiApiKey);
    updateData.aiApiKeyProvider = keyProvider;
  }

  const settings = await prisma.botSettings.update({
    where: { id: 1 },
    data: updateData,
  });
  res.json({ settings: serializeSettings(settings) });
}

// ───────────────────────── Bots / Modelos ─────────────────────────

const botSchema = z.object({
  fullName: z.string().trim().min(2).max(80),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  age: z.number().int().min(18).max(99),
  about: z.string().trim().max(1000).optional().nullable(),
  city: z.string().trim().max(80).optional().nullable(),
  interests: z.array(z.string().trim().min(1).max(40)).max(10).optional(),
  photos: z.array(z.string().url()).max(6).optional(),
  personality: z.enum(PERSONALITIES).default("ALL"),
  aiEnabled: z.boolean().default(false),
  botSystemPrompt: z.string().trim().min(1).max(4000).optional().nullable(),
  botAiModel: aiModelSchema.optional().nullable(),
  botAiModelProvider: z.enum(AI_PROVIDERS).optional().nullable(),
  botTemperature: z.number().finite().min(0).max(2).default(0.75),
  botMemoryEnabled: z.boolean().default(true),
  latitude: z.number().finite().min(-90).max(90).optional().nullable(),
  longitude: z.number().finite().min(-180).max(180).optional().nullable(),
});

type BotModelOverrideInput = {
  botAiModel?: string | null;
  botAiModelProvider?: AiProvider | null;
};

function resolveBotModelOverride(
  input: BotModelOverrideInput,
  current: { botAiModel: string | null; botAiModelProvider: string | null } = {
    botAiModel: null,
    botAiModelProvider: null,
  }
): { botAiModel: string | null; botAiModelProvider: AiProvider | null } {
  const botAiModel =
    input.botAiModel !== undefined ? input.botAiModel : current.botAiModel;
  let botAiModelProvider =
    input.botAiModelProvider !== undefined
      ? input.botAiModelProvider
      : parseAiProvider(current.botAiModelProvider);

  // Limpar explicitamente o modelo sempre limpa seu vínculo, mesmo em updates parciais.
  if (input.botAiModel === null) botAiModelProvider = null;
  if (botAiModel && !botAiModelProvider) {
    throw new AppError(
      "O provider individual deve acompanhar o modelo individual",
      422,
      undefined,
      "BOT_MODEL_PROVIDER_REQUIRED"
    );
  }
  if (
    botAiModel &&
    botAiModelProvider &&
    !isAiModelCompatible(botAiModelProvider, botAiModel)
  ) {
    throw new AppError(
      "O modelo individual não pertence ao provider informado",
      422,
      undefined,
      "BOT_MODEL_PROVIDER_MISMATCH"
    );
  }
  if (!botAiModel && botAiModelProvider) {
    throw new AppError(
      "Um provider individual exige um modelo individual",
      422,
      undefined,
      "BOT_MODEL_REQUIRED"
    );
  }

  return { botAiModel, botAiModelProvider };
}

function birthdayForAge(age: number): Date {
  const birthday = new Date();
  birthday.setFullYear(birthday.getFullYear() - age);
  birthday.setMonth(0, 1);
  birthday.setHours(0, 0, 0, 0);
  return birthday;
}

async function requireBot(userId: string): Promise<void> {
  const target = await prisma.user.findUnique({
    where: { id: userId },
    select: { isBot: true },
  });
  if (!target?.isBot) throw new AppError("Bot não encontrado", 404);
}

// GET /api/admin/bots
export async function listBots(_req: Request, res: Response) {
  const [bots, memoryGroups, settings] = await Promise.all([
    prisma.user.findMany({
      where: { isBot: true },
      include: { profile: true },
      orderBy: { createdAt: "desc" },
    }),
    prisma.botConversationMemory.groupBy({
      by: ["botUserId"],
      _count: { _all: true },
    }),
    ensureSettings(),
  ]);
  const memoryCounts = new Map(
    memoryGroups.map((group) => [group.botUserId, group._count._all])
  );

  const result = await Promise.all(
    bots.map(async (bot) => {
      const matchCount = await prisma.match.count({
        where: {
          isActive: true,
          OR: [{ userAId: bot.id }, { userBId: bot.id }],
        },
      });
      return {
        userId: bot.id,
        fullName: bot.profile?.fullName ?? "(sem perfil)",
        gender: bot.profile?.gender ?? null,
        age: bot.profile?.birthday
          ? ageFromBirthday(bot.profile.birthday)
          : null,
        about: bot.profile?.about ?? null,
        city: bot.profile?.city ?? null,
        interests: bot.profile?.interests ?? [],
        photos: bot.profile?.mediaFiles ?? [],
        profilePicture: bot.profile?.profilePicture ?? null,
        personality: bot.botPersonality ?? "ALL",
        aiEnabled: bot.botAiEnabled,
        botSystemPrompt: bot.botSystemPrompt,
        botAiModel: bot.botAiModel,
        botAiModelProvider: bot.botAiModelProvider,
        botTemperature: bot.botTemperature,
        botMemoryEnabled: bot.botMemoryEnabled,
        matchCount,
        memoryCount: memoryCounts.get(bot.id) ?? 0,
        createdAt: bot.createdAt,
      };
    })
  );
  res.json({
    bots: result,
    globalAiProvider: parseAiProvider(settings.aiProvider),
  });
}

// POST /api/admin/bots
export async function createBot(req: Request, res: Response) {
  const data = botSchema.parse(req.body);
  const modelOverride = resolveBotModelOverride(data);
  const user = await prisma.user.create({
    data: {
      email: `bot-${randomUUID()}@bots.local`,
      emailVerified: true,
      isBot: true,
      botPersonality: data.personality,
      botAiEnabled: data.aiEnabled,
      botSystemPrompt: data.botSystemPrompt ?? null,
      botAiModel: modelOverride.botAiModel,
      botAiModelProvider: modelOverride.botAiModelProvider,
      botTemperature: data.botTemperature,
      botMemoryEnabled: data.botMemoryEnabled,
      profile: {
        create: {
          fullName: data.fullName,
          gender: data.gender,
          birthday: birthdayForAge(data.age),
          about: data.about ?? null,
          city: data.city ?? null,
          interests: data.interests ?? [],
          mediaFiles: data.photos ?? [],
          profilePicture: data.photos?.[0] ?? null,
          latitude: data.latitude ?? null,
          longitude: data.longitude ?? null,
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
  const data = botSchema.partial().parse(req.body);
  const current = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      isBot: true,
      botAiModel: true,
      botAiModelProvider: true,
    },
  });
  if (!current?.isBot) throw new AppError("Bot não encontrado", 404);
  const modelOverrideTouched =
    data.botAiModel !== undefined || data.botAiModelProvider !== undefined;
  const modelOverride = modelOverrideTouched
    ? resolveBotModelOverride(data, current)
    : null;

  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: {
        ...(data.personality !== undefined
          ? { botPersonality: data.personality }
          : {}),
        ...(data.aiEnabled !== undefined
          ? { botAiEnabled: data.aiEnabled }
          : {}),
        ...(data.botSystemPrompt !== undefined
          ? { botSystemPrompt: data.botSystemPrompt }
          : {}),
        ...(modelOverrideTouched
          ? {
              botAiModel: modelOverride!.botAiModel,
              botAiModelProvider: modelOverride!.botAiModelProvider,
            }
          : {}),
        ...(data.botTemperature !== undefined
          ? { botTemperature: data.botTemperature }
          : {}),
        ...(data.botMemoryEnabled !== undefined
          ? { botMemoryEnabled: data.botMemoryEnabled }
          : {}),
      },
    }),
    prisma.profile.update({
      where: { userId },
      data: {
        ...(data.fullName !== undefined ? { fullName: data.fullName } : {}),
        ...(data.gender !== undefined ? { gender: data.gender } : {}),
        ...(data.age !== undefined
          ? { birthday: birthdayForAge(data.age) }
          : {}),
        ...(data.about !== undefined ? { about: data.about } : {}),
        ...(data.city !== undefined ? { city: data.city } : {}),
        ...(data.interests !== undefined
          ? { interests: data.interests }
          : {}),
        ...(data.photos !== undefined
          ? {
              mediaFiles: data.photos,
              profilePicture: data.photos[0] ?? null,
            }
          : {}),
        ...(data.latitude !== undefined
          ? { latitude: data.latitude }
          : {}),
        ...(data.longitude !== undefined
          ? { longitude: data.longitude }
          : {}),
      },
    }),
  ]);
  res.json({ ok: true });
}

// DELETE /api/admin/bots/:userId/memories
export async function resetBotMemories(req: Request, res: Response) {
  const userId = req.params.userId;
  const result = await prisma.$transaction(
    async (tx) => {
      const incremented = await tx.user.updateMany({
        where: { id: userId, isBot: true },
        data: { botMemoryEpoch: { increment: 1 } },
      });
      if (incremented.count !== 1) {
        throw new AppError("Bot não encontrado", 404);
      }
      const deleted = await tx.botConversationMemory.deleteMany({
        where: { botUserId: userId },
      });
      const bot = await tx.user.findUnique({
        where: { id: userId },
        select: { botMemoryEpoch: true },
      });
      return {
        deletedCount: deleted.count,
        botMemoryEpoch: bot?.botMemoryEpoch ?? 0,
      };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
  );
  res.json({ ok: true, ...result });
}

// DELETE /api/admin/bots/:userId
export async function deleteBot(req: Request, res: Response) {
  const userId = req.params.userId;
  await requireBot(userId);

  // Matches não têm FK para users; a memória é removida pelo cascade do Match.
  const matches = await prisma.match.findMany({
    where: { OR: [{ userAId: userId }, { userBId: userId }] },
    select: { id: true },
  });
  const matchIds = matches.map((match) => match.id);
  await prisma.$transaction([
    prisma.message.deleteMany({ where: { matchId: { in: matchIds } } }),
    prisma.match.deleteMany({ where: { id: { in: matchIds } } }),
    prisma.interaction.deleteMany({
      where: { OR: [{ fromUserId: userId }, { toUserId: userId }] },
    }),
    prisma.user.delete({ where: { id: userId } }),
  ]);
  res.json({ ok: true });
}

// ───────────────────────── Disparo de Modelos (broadcast) ─────────────────────────

const broadcastSchema = z.object({
  text: z.string().trim().min(1).max(500).optional(),
  imageUrl: z.string().trim().url().optional(),
  audience: z.enum(BROADCAST_AUDIENCES).default("all"),
  limit: z.number().int().min(1).max(2000).optional(),
  idempotencyKey: z
    .string()
    .trim()
    .min(1)
    .max(128)
    .regex(/^[A-Za-z0-9._:-]+$/, "Idempotency key inválida"),
});

// POST /api/admin/bots/:userId/broadcast — o Modelo manda uma mensagem para vários usuários
export async function broadcastFromBot(req: Request, res: Response) {
  const botId = req.params.userId;
  const bot = await prisma.user.findUnique({
    where: { id: botId },
    include: { profile: { select: { fullName: true } } },
  });
  if (!bot?.isBot) throw new AppError("Modelo não encontrado", 404);

  const { text, imageUrl, audience, limit, idempotencyKey: requestedKey } =
    broadcastSchema.parse(req.body);
  if (!text && !imageUrl) throw new AppError("Informe texto ou imagem", 400);

  const result = await runBotBroadcast({
    botId,
    botName: bot.profile?.fullName ?? "Mensagem",
    audience,
    text,
    imageUrl,
    limit,
    idempotencyKey: requestedKey,
  });
  return res.json(
    await serializeBroadcast(result.broadcast, result.duplicate)
  );
}

// GET /api/admin/bots/:userId/broadcasts — histórico de disparos
export async function getBroadcasts(req: Request, res: Response) {
  const history = await listBotBroadcasts(req.params.userId);
  res.json({ history });
}
