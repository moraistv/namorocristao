import { Prisma, Profile } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ageFromBirthday } from "../../lib/age";
import { distanceBetween } from "../../lib/geo";
import { emitToUser } from "../../sockets";
import { ensureDailyReset, isPremiumActive, superLikesLeft } from "../../lib/premium";
import { notifyUser } from "../../lib/push";

export interface DiscoveryFilters {
  minAge?: number;
  maxAge?: number;
  maxDistanceKm?: number;
  gender?: "MALE" | "FEMALE" | "OTHER";
  denominations?: string[];
  interests?: string[];
  intention?: string;
  churchFrequency?: string;
}

/** Calcula a % de compatibilidade entre dois perfis (fé + interesses). */
export function computeMatchPercent(me: Profile, other: Profile): number {
  let score = 55;
  const myInterests = new Set(me.interests);
  const shared = other.interests.filter((i) => myInterests.has(i)).length;
  score += shared * 8;
  if (
    me.denomination &&
    other.denomination &&
    me.denomination === other.denomination
  ) {
    score += 14;
  }
  if (
    me.churchFrequency &&
    other.churchFrequency &&
    me.churchFrequency === other.churchFrequency
  ) {
    score += 8;
  }
  return Math.max(40, Math.min(99, score));
}

/** Monta o card público de um perfil para a descoberta. */
function toCard(me: Profile, other: Profile) {
  const distance = distanceBetween(me, other);
  const locked = new Set(other.lockedPhotos);
  const publicMedia = other.mediaFiles.filter((m) => !locked.has(m));
  return {
    id: other.userId,
    name: other.fullName,
    age: ageFromBirthday(other.birthday),
    gender: other.gender,
    about: other.about,
    intention: other.intention,
    denomination: other.denomination,
    churchFrequency: other.churchFrequency,
    city: other.city,
    interests: other.interests,
    mediaFiles: publicMedia,
    profilePicture: other.profilePicture,
    isVerified: other.isVerified,
    isOnline: other.isOnline,
    lastActiveAt: other.lastActiveAt,
    hasLockedPhotos: other.lockedPhotos.length > 0,
    lockedCount: other.lockedPhotos.length,
    distanceKm: distance,
    matchPercent: computeMatchPercent(me, other),
  };
}

/** Retorna candidatos para a descoberta do usuário atual. */
export async function getDiscovery(userId: string, filters: DiscoveryFilters) {
  const me = await prisma.profile.findUnique({ where: { userId } });
  if (!me) {
    return { needsProfile: true, candidates: [] as ReturnType<typeof toCard>[] };
  }

  // IDs a excluir: já avaliados, bloqueados (2 sentidos), banidos, eu mesmo.
  const [interactions, blocksFrom, blocksTo, banned] = await Promise.all([
    prisma.interaction.findMany({
      where: { fromUserId: userId },
      select: { toUserId: true },
    }),
    prisma.block.findMany({
      where: { blockerId: userId },
      select: { blockedId: true },
    }),
    prisma.block.findMany({
      where: { blockedId: userId },
      select: { blockerId: true },
    }),
    prisma.bannedUser.findMany({ select: { userId: true } }),
  ]);

  const excluded = new Set<string>([userId]);
  interactions.forEach((i) => excluded.add(i.toUserId));
  blocksFrom.forEach((b) => excluded.add(b.blockedId));
  blocksTo.forEach((b) => excluded.add(b.blockerId));
  banned.forEach((b) => excluded.add(b.userId));

  const where: Prisma.ProfileWhereInput = {
    userId: { notIn: Array.from(excluded) },
    user: { isBanned: false, deletedAt: null },
    incognito: false, // perfis em modo incógnito não aparecem na descoberta
    ...(filters.gender ? { gender: filters.gender } : {}),
  };

  const profiles = await prisma.profile.findMany({
    where,
    take: 80,
    orderBy: { lastActiveAt: "desc" },
  });

  const now = new Date();
  let cards = profiles.map((p) => toCard(me, p));

  // Filtros de idade.
  if (filters.minAge != null) {
    cards = cards.filter((c) => c.age >= filters.minAge!);
  }
  if (filters.maxAge != null) {
    cards = cards.filter((c) => c.age <= filters.maxAge!);
  }
  // Filtro de distância (só quando há distância calculada).
  if (filters.maxDistanceKm != null) {
    cards = cards.filter(
      (c) => c.distanceKm == null || c.distanceKm <= filters.maxDistanceKm!
    );
  }
  // Filtro de denominação.
  if (filters.denominations && filters.denominations.length > 0) {
    cards = cards.filter(
      (c) => c.denomination != null && filters.denominations!.includes(c.denomination)
    );
  }
  // Filtro de interesses (compartilha ao menos 1).
  if (filters.interests && filters.interests.length > 0) {
    cards = cards.filter((c) =>
      c.interests.some((i) => filters.interests!.includes(i))
    );
  }
  // Filtro de intenção (namoro/amizade/casamento) — premium no app.
  if (filters.intention) {
    cards = cards.filter((c) => c.intention === filters.intention);
  }
  // Filtro de frequência à igreja — premium no app.
  if (filters.churchFrequency) {
    cards = cards.filter((c) => c.churchFrequency === filters.churchFrequency);
  }

  // Quem me deu SUPER LIKE tem PRIORIDADE (aparece no topo).
  const superIncoming = await prisma.interaction.findMany({
    where: { toUserId: userId, type: "SUPERLIKE" },
    select: { fromUserId: true },
  });
  const superLikers = new Set(superIncoming.map((i) => i.fromUserId));

  // Quem está com BOOST ativo (Turbo) também sobe (logo após os super likes).
  const boostedIds = new Set(
    profiles
      .filter((p) => p.boostUntil != null && p.boostUntil > now)
      .map((p) => p.userId)
  );

  // Embaralha os "normais" (gamificação: dificulta achar, mais tempo no app).
  for (let i = cards.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }

  // Ordem final: super likers (por compatibilidade) → boost ativo → resto embaralhado.
  const superCards = cards
    .filter((c) => superLikers.has(c.id))
    .sort((a, b) => b.matchPercent - a.matchPercent);
  const boostCards = cards.filter(
    (c) => !superLikers.has(c.id) && boostedIds.has(c.id)
  );
  const rest = cards.filter(
    (c) => !superLikers.has(c.id) && !boostedIds.has(c.id)
  );
  cards = [...superCards, ...boostCards, ...rest];

  return { needsProfile: false, candidates: cards.slice(0, 30), now };
}

/** Retorna os "Top Picks": melhores candidatos por compatibilidade. */
export async function getTopPicks(userId: string) {
  const { needsProfile, candidates } = await getDiscovery(userId, {});
  if (needsProfile) return { needsProfile: true, picks: [] };
  // Os de maior % de compatibilidade (já vêm ordenados desc).
  return { needsProfile: false, picks: candidates.slice(0, 12) };
}

export type SwipeType = "LIKE" | "DISLIKE" | "SUPERLIKE";

/** Registra um swipe e cria match se houver reciprocidade. */
export async function swipe(
  fromUserId: string,
  toUserId: string,
  type: SwipeType,
  note?: string
) {
  if (fromUserId === toUserId) {
    throw new Error("Não é possível interagir consigo mesmo");
  }

  // Super Like: respeita o limite diário (grátis x premium).
  if (type === "SUPERLIKE") {
    const user = await ensureDailyReset(fromUserId);
    if (superLikesLeft(user) <= 0) {
      const err = new Error(
        isPremiumActive(user)
          ? "Você usou todos os seus Super Likes de hoje."
          : "Seus Super Likes acabaram. Assine o VIP para ter mais!"
      );
      (err as any).code = "SUPERLIKE_LIMIT";
      throw err;
    }
    await prisma.user.update({
      where: { id: fromUserId },
      data: { superLikesUsedToday: { increment: 1 } },
    });
  }

  await prisma.interaction.upsert({
    where: { fromUserId_toUserId: { fromUserId, toUserId } },
    create: { fromUserId, toUserId, type, note: note?.trim() || null },
    update: { type, note: note?.trim() || null },
  });

  if (type === "DISLIKE") {
    return { matched: false as const };
  }

  // Bots/Modelos curtem de volta automaticamente → match na hora.
  const targetUser = await prisma.user.findUnique({
    where: { id: toUserId },
    select: { isBot: true },
  });
  if (targetUser?.isBot) {
    await prisma.interaction.upsert({
      where: { fromUserId_toUserId: { fromUserId: toUserId, toUserId: fromUserId } },
      create: { fromUserId: toUserId, toUserId: fromUserId, type: "LIKE" },
      update: {},
    });
  }

  // Verifica se o outro já curtiu/super curtiu o usuário atual.
  const reciprocal = await prisma.interaction.findUnique({
    where: { fromUserId_toUserId: { fromUserId: toUserId, toUserId: fromUserId } },
  });

  if (reciprocal && (reciprocal.type === "LIKE" || reciprocal.type === "SUPERLIKE")) {
    // Ordena o par para a unique constraint (userAId < userBId).
    const [userAId, userBId] =
      fromUserId < toUserId ? [fromUserId, toUserId] : [toUserId, fromUserId];

    const match = await prisma.match.upsert({
      where: { userAId_userBId: { userAId, userBId } },
      create: { userAId, userBId, isActive: true },
      update: { isActive: true },
    });

    // Notifica o outro usuário (passivo) em tempo real — quem arrastou já vê pela resposta.
    const [pFrom, pTo] = await Promise.all([
      prisma.profile.findUnique({ where: { userId: fromUserId } }),
      prisma.profile.findUnique({ where: { userId: toUserId } }),
    ]);
    emitToUser(toUserId, "match:new", {
      matchId: match.id,
      withUserId: fromUserId,
      name: pFrom?.fullName ?? "Alguém",
      photo: pFrom?.profilePicture ?? null,
    });
    // Push/notificação (background + persistente).
    notifyUser(
      toUserId,
      "Você tem um novo match! 💛",
      `${pFrom?.fullName ?? "Alguém"} também curtiu você. Diga oi!`,
      { type: "match", data: { matchId: match.id } }
    );

    // Mensagem automática de boas-vindas (tipo SYSTEM) — só na 1ª vez.
    const existingMsgs = await prisma.message.count({ where: { matchId: match.id } });
    if (existingMsgs === 0) {
      const sysMsg = await prisma.message.create({
        data: {
          matchId: match.id,
          senderId: fromUserId,
          type: "SYSTEM",
          content: "🎉 Vocês deram match! Que tal começar a conversa? 💛",
        },
      });
      emitToUser(fromUserId, "message:new", sysMsg);
      emitToUser(toUserId, "message:new", sysMsg);
    }

    return {
      matched: true as const,
      matchId: match.id,
      withUser: {
        userId: toUserId,
        name: pTo?.fullName ?? "Alguém",
        photo: pTo?.profilePicture ?? null,
      },
    };
  }

  // Curtida/super like sem reciprocidade → notifica quem recebeu.
  if (type === "LIKE") {
    notifyUser(toUserId, "Alguém curtiu você! 💛",
        "Você recebeu uma nova curtida. Veja quem foi!",
        { type: "like" });
  } else if (type === "SUPERLIKE") {
    notifyUser(toUserId, "Você recebeu um Super Like! ⭐",
        "Alguém te super curtiu. Abra para ver!",
        { type: "superlike" });
  }

  return { matched: false as const };
}

/**
 * Desfaz o último swipe do usuário (Rewind). Remove a última interação e, se ela
 * tiver criado um match sem mensagens, desfaz o match também. Retorna o card de
 * volta para reaparecer na descoberta.
 */
export async function undoLastSwipe(userId: string) {
  const last = await prisma.interaction.findFirst({
    where: { fromUserId: userId },
    orderBy: { createdAt: "desc" },
  });
  if (!last) throw new Error("Nada para desfazer");

  const toUserId = last.toUserId;

  // Se virou match e ainda não há mensagens, desfaz o match.
  const [a, b] = userId < toUserId ? [userId, toUserId] : [toUserId, userId];
  const match = await prisma.match.findUnique({
    where: { userAId_userBId: { userAId: a, userBId: b } },
  });
  if (match) {
    const msgs = await prisma.message.count({ where: { matchId: match.id } });
    if (msgs === 0) {
      await prisma.match.delete({ where: { id: match.id } });
    }
  }

  await prisma.interaction.delete({ where: { id: last.id } });

  const me = await prisma.profile.findUnique({ where: { userId } });
  const other = await prisma.profile.findUnique({ where: { userId: toUserId } });
  return {
    ok: true,
    undoneType: last.type,
    card: me && other ? toCard(me, other) : null,
  };
}

/** Lista os matches ativos do usuário com dados do outro + última mensagem. */
export async function getMatches(userId: string) {
  const matches = await prisma.match.findMany({
    where: {
      isActive: true,
      OR: [{ userAId: userId }, { userBId: userId }],
    },
    orderBy: { createdAt: "desc" },
  });
  if (matches.length === 0) return [];

  const matchIds = matches.map((m) => m.id);
  const otherIds = matches.map((m) => (m.userAId === userId ? m.userBId : m.userAId));

  // 3 queries no total (antes era 3 por match):
  const [profiles, lastMessages, unreadGroups] = await Promise.all([
    // Perfis dos outros usuários.
    prisma.profile.findMany({
      where: { userId: { in: otherIds } },
      select: { userId: true, fullName: true, profilePicture: true, isOnline: true },
    }),
    // Última mensagem (não-SYSTEM) de cada match — DISTINCT ON (matchId).
    prisma.message.findMany({
      where: { matchId: { in: matchIds }, type: { not: "SYSTEM" } },
      orderBy: [{ matchId: "asc" }, { createdAt: "desc" }],
      distinct: ["matchId"],
      select: { matchId: true, content: true, type: true, senderId: true, createdAt: true, readAt: true },
    }),
    // Não lidas (mensagens do outro lado) por match.
    prisma.message.groupBy({
      by: ["matchId"],
      where: { matchId: { in: matchIds }, senderId: { not: userId }, readAt: null, type: { not: "SYSTEM" } },
      _count: { _all: true },
    }),
  ]);

  const profileByUser = new Map(profiles.map((p) => [p.userId, p]));
  const lastByMatch = new Map(lastMessages.map((m) => [m.matchId, m]));
  const unreadByMatch = new Map(unreadGroups.map((g) => [g.matchId, g._count._all]));

  return matches.map((m) => {
    const otherId = m.userAId === userId ? m.userBId : m.userAId;
    const otherProfile = profileByUser.get(otherId);
    const lastMessage = lastByMatch.get(m.id);
    return {
      matchId: m.id,
      createdAt: m.createdAt,
      otherUser: otherProfile
        ? {
            id: otherProfile.userId,
            name: otherProfile.fullName,
            profilePicture: otherProfile.profilePicture,
            isOnline: otherProfile.isOnline,
          }
        : { id: otherId, name: "Usuário", profilePicture: null, isOnline: false },
      lastMessage: lastMessage
        ? {
            content: lastMessage.content,
            type: lastMessage.type,
            senderId: lastMessage.senderId,
            createdAt: lastMessage.createdAt,
            readAt: lastMessage.readAt,
          }
        : null,
      unreadCount: unreadByMatch.get(m.id) ?? 0,
    };
  });
}
