import { BotPersonality, MessageType } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { emitToUser } from "../../sockets";
import { pushOnly } from "../../lib/push";
import { ageFromBirthday } from "../../lib/age";

/** Remove acentos e baixa caixa (para casar palavras-chave). */
function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim();
}

function rand<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Encontra a melhor regra (maior prioridade) cujas palavras-chave batem. */
async function matchRule(message: string, personality: BotPersonality | null) {
  const norm = normalize(message);
  const allowed: BotPersonality[] = personality ? ["ALL", personality] : ["ALL"];
  const rules = await prisma.chatbotRule.findMany({
    where: { active: true, personality: { in: allowed } },
    orderBy: { priority: "desc" },
  });
  const matched = rules.filter((r) =>
    r.keywords.some((k) => k && norm.includes(normalize(k)))
  );
  if (matched.length === 0) return null;
  const topPriority = matched[0].priority;
  const best = matched.filter((r) => r.priority === topPriority);
  const rule = rand(best);
  if (rule.responses.length === 0) return null;
  return { category: rule.category, response: rand(rule.responses) };
}

/** Substitui {name} {age} {city} pelos dados de quem está conversando. */
function fillVars(
  text: string,
  p: { fullName: string; birthday: Date; city: string | null } | null
): string {
  if (!p) return text;
  const name = p.fullName.split(" ")[0];
  const age = ageFromBirthday(p.birthday);
  return text
    .replace(/\{name\}/gi, name)
    .replace(/\{age\}/gi, String(age))
    .replace(/\{city\}/gi, p.city ?? "");
}

/** Chama a IA (API compatível com OpenAI). Retorna null se falhar/sem chave. */
async function callAi(
  settings: { aiApiKey: string | null; aiModel: string; aiSystemPrompt: string },
  botProfile: { fullName: string; about: string | null } | null,
  matchId: string,
  botUserId: string
): Promise<string | null> {
  if (!settings.aiApiKey) return null;
  try {
    const history = await prisma.message.findMany({
      where: { matchId, type: "TEXT" },
      orderBy: { createdAt: "desc" },
      take: 8,
    });
    history.reverse();

    const persona = botProfile
      ? ` Voce esta interpretando ${botProfile.fullName}.${
          botProfile.about ? " Bio: " + botProfile.about : ""
        } Nunca diga que e um robo ou IA. Responda em 1-2 frases curtas.`
      : "";

    const messages = [
      { role: "system", content: settings.aiSystemPrompt + persona },
      ...history.map((m) => ({
        role: m.senderId === botUserId ? "assistant" : "user",
        content: m.content,
      })),
    ];

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${settings.aiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: settings.aiModel,
        messages,
        max_tokens: 120,
        temperature: 0.9,
      }),
    });
    if (!resp.ok) return null;
    const j: any = await resp.json();
    const text = j?.choices?.[0]?.message?.content;
    return typeof text === "string" && text.trim() ? text.trim() : null;
  } catch {
    return null;
  }
}

/** Verifica se um usuário é um bot. */
export async function isBotUser(userId: string): Promise<boolean> {
  const u = await prisma.user.findUnique({
    where: { id: userId },
    select: { isBot: true },
  });
  return !!u?.isBot;
}

/**
 * Dispara a resposta automática de um bot a uma mensagem recebida.
 * Fire-and-forget: gera o texto (regra → IA → fallback), espera um tempo
 * (parece humano, com "digitando...") e entrega via socket + push.
 */
export function triggerBotReply(params: {
  matchId: string;
  botUserId: string;
  fromUserId: string;
  content: string;
  type: MessageType;
}) {
  void handleIncoming(params).catch(() => {});
}

async function handleIncoming(params: {
  matchId: string;
  botUserId: string;
  fromUserId: string;
  content: string;
  type: MessageType;
}) {
  if (params.type !== "TEXT") return; // só responde a texto

  const bot = await prisma.user.findUnique({
    where: { id: params.botUserId },
    select: { isBot: true, botPersonality: true, botAiEnabled: true },
  });
  if (!bot?.isBot) return;

  const [fromProfile, botProfile, settings] = await Promise.all([
    prisma.profile.findUnique({ where: { userId: params.fromUserId } }),
    prisma.profile.findUnique({ where: { userId: params.botUserId } }),
    prisma.botSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} }),
  ]);

  let reply: string | null = null;
  let category: string | null = null;
  let usedAi = false;

  const ruleHit = await matchRule(params.content, bot.botPersonality);
  if (ruleHit) {
    reply = fillVars(ruleHit.response, fromProfile);
    category = ruleHit.category;
  } else if (bot.botAiEnabled && settings.aiEnabled && settings.aiApiKey) {
    reply = await callAi(settings, botProfile, params.matchId, params.botUserId);
    usedAi = !!reply;
  }
  if (!reply) reply = settings.fallbackText;

  // Log para analytics (matchedCategory null = fallback).
  await prisma.chatbotLog
    .create({
      data: {
        userId: params.fromUserId,
        botUserId: params.botUserId,
        message: params.content.slice(0, 500),
        matchedCategory: category,
        usedAi,
      },
    })
    .catch(() => {});

  // "digitando..." durante o atraso (mais humano).
  emitToUser(params.fromUserId, "typing", {
    matchId: params.matchId,
    userId: params.botUserId,
    isTyping: true,
  });

  const min = Math.max(300, settings.replyMinMs);
  const max = Math.max(min, settings.replyMaxMs);
  const delay = min + Math.floor(Math.random() * (max - min));
  await new Promise((r) => setTimeout(r, delay));

  const msg = await prisma.message.create({
    data: {
      matchId: params.matchId,
      senderId: params.botUserId,
      type: "TEXT",
      content: reply,
    },
  });

  emitToUser(params.fromUserId, "typing", {
    matchId: params.matchId,
    userId: params.botUserId,
    isTyping: false,
  });
  emitToUser(params.fromUserId, "message:new", msg);
  pushOnly(params.fromUserId, botProfile?.fullName ?? "Mensagem", reply.slice(0, 80), {
    matchId: params.matchId,
    type: "message",
  });
}
