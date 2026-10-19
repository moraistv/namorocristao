import { Prisma, Profile } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { ageFromBirthday } from "../../lib/age";
import { distanceBetween } from "../../lib/geo";
import {
  FREE_SUPERLIKES_PER_DAY,
  PREMIUM_SUPERLIKES_PER_DAY,
  isPremiumActive,
  premiumInactiveWhere,
  startOfToday,
} from "../../lib/premium";
import { isRecentlyOnline } from "../../lib/presence";
import {
  PublicProfileSource,
  publicProfileInclude,
  publicVirtualFlags,
  sanitizePublicMedia,
} from "../../lib/publicProfile";
import { notifyUser } from "../../lib/push";
import { retryBackoff } from "../../lib/retry";
import { emitToUser } from "../../sockets";

/** Tentativas ao registrar um swipe quando a transação Serializable colide. */
const SWIPE_ATTEMPTS = 4;

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
  const shared = other.interests.filter((interest) =>
    myInterests.has(interest)
  ).length;
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

/** Monta o card público sem expor mídia privada ou metadados internos do bot. */
function toCard(me: Profile, other: PublicProfileSource) {
  const media = sanitizePublicMedia(other);
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
    mediaFiles: media.mediaFiles,
    profilePicture: media.profilePicture,
    isVerified: other.isVerified,
    isOnline: isRecentlyOnline(other),
    lastActiveAt: other.lastActiveAt,
    hasLockedPhotos: other.lockedPhotos.length > 0,
    lockedCount: other.lockedPhotos.length,
    distanceKm: distanceBetween(me, other),
    matchPercent: computeMatchPercent(me, other),
    ...publicVirtualFlags(other.user.isBot),
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
  interactions.forEach((interaction) => excluded.add(interaction.toUserId));
  blocksFrom.forEach((block) => excluded.add(block.blockedId));
  blocksTo.forEach((block) => excluded.add(block.blockerId));
  banned.forEach((record) => excluded.add(record.userId));

  const now = new Date();
  const [settings, viewer] = await Promise.all([
    prisma.appSettings.findUnique({
      where: { id: 1 },
      select: { incognitoPremiumOnly: true },
    }),
    prisma.user.findUnique({
      where: { id: userId },
      select: { isPremium: true, premiumUntil: true },
    }),
  ]);
  // Com o incógnito restrito ao VIP (padrão), ele só esconde quem ainda é VIP:
  // quando o VIP (do painel ou por anúncio) acaba, a pessoa volta a aparecer.
  const incognitoPremiumOnly = settings?.incognitoPremiumOnly ?? true;
  const where: Prisma.ProfileWhereInput = {
    userId: { notIn: Array.from(excluded) },
    user: {
      isBanned: false,
      deletedAt: null,
      OR: [{ suspendedUntil: null }, { suspendedUntil: { lte: now } }],
    },
    OR: incognitoPremiumOnly
      ? [{ incognito: false }, { user: premiumInactiveWhere(now) }]
      : [{ incognito: false }],
    ...(filters.gender ? { gender: filters.gender } : {}),
  };

  const profiles = await prisma.profile.findMany({
    where,
    take: 80,
    orderBy: { lastActiveAt: "desc" },
    include: publicProfileInclude,
  });

  let cards = profiles.map((profile) => toCard(me, profile));

  if (filters.minAge != null) {
    cards = cards.filter((card) => card.age >= filters.minAge!);
  }
  if (filters.maxAge != null) {
    cards = cards.filter((card) => card.age <= filters.maxAge!);
  }
  if (filters.maxDistanceKm != null) {
    cards = cards.filter(
      (card) =>
        card.distanceKm == null || card.distanceKm <= filters.maxDistanceKm!
    );
  }
  if (filters.denominations && filters.denominations.length > 0) {
    cards = cards.filter(
      (card) =>
        card.denomination != null &&
        filters.denominations!.includes(card.denomination)
    );
  }
  if (filters.interests && filters.interests.length > 0) {
    cards = cards.filter((card) =>
      card.interests.some((interest) => filters.interests!.includes(interest))
    );
  }
  if (filters.intention) {
    cards = cards.filter((card) => card.intention === filters.intention);
  }
  if (filters.churchFrequency) {
    cards = cards.filter(
      (card) => card.churchFrequency === filters.churchFrequency
    );
  }

  const superIncoming = await prisma.interaction.findMany({
    where: { toUserId: userId, type: "SUPERLIKE" },
    select: { fromUserId: true },
  });
  const superLikers = new Set(
    superIncoming.map((interaction) => interaction.fromUserId)
  );

  const boostedIds = new Set(
    profiles
      .filter(
        (profile) => profile.boostUntil != null && profile.boostUntil > now
      )
      .map((profile) => profile.userId)
  );

  for (let index = cards.length - 1; index > 0; index--) {
    const randomIndex = Math.floor(Math.random() * (index + 1));
    [cards[index], cards[randomIndex]] = [cards[randomIndex], cards[index]];
  }

  const superCards = cards
    .filter((card) => superLikers.has(card.id))
    .sort((first, second) => second.matchPercent - first.matchPercent);
  const boostCards = cards.filter(
    (card) => !superLikers.has(card.id) && boostedIds.has(card.id)
  );
  const rest = cards.filter(
    (card) => !superLikers.has(card.id) && !boostedIds.has(card.id)
  );

  // Quem deu Super Like sempre entra entre os candidatos. Na frente do baralho
  // (e dos Top Picks) só para quem é VIP: para os outros a posição revelaria
  // quem curtiu, que é recurso VIP. Aí vão embaralhados com os demais.
  const viewerIsVip = viewer ? isPremiumActive(viewer) : false;
  let candidates: typeof cards;
  if (viewerIsVip) {
    candidates = [...superCards, ...boostCards, ...rest].slice(0, LIMIT);
  } else {
    const superKeep = superCards.slice(0, LIMIT);
    const boostKeep = boostCards.slice(0, LIMIT - superKeep.length);
    const room = LIMIT - superKeep.length - boostKeep.length;
    const mixed = shuffled([...superKeep, ...rest.slice(0, room)]);
    candidates = [...boostKeep, ...mixed];
  }

  return { needsProfile: false, candidates, now };
}

/** Quantos candidatos a descoberta devolve por vez. */
const LIMIT = 30;

/** Cópia embaralhada (Fisher-Yates). */
function shuffled<T>(items: T[]): T[] {
  const copy = [...items];
  for (let index = copy.length - 1; index > 0; index--) {
    const randomIndex = Math.floor(Math.random() * (index + 1));
    [copy[index], copy[randomIndex]] = [copy[randomIndex], copy[index]];
  }
  return copy;
}

/** Retorna os "Top Picks": melhores candidatos por compatibilidade. */
export async function getTopPicks(userId: string) {
  const { needsProfile, candidates } = await getDiscovery(userId, {});
  if (needsProfile) return { needsProfile: true, picks: [] };
  return { needsProfile: false, picks: candidates.slice(0, 12) };
}

export type SwipeType = "LIKE" | "DISLIKE" | "SUPERLIKE";

function transactionErrorCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null || !("code" in error)) {
    return undefined;
  }
  return typeof error.code === "string" ? error.code : undefined;
}

function swipeRetryError(): Error & { code: string } {
  const error = new Error("Conflito ao registrar swipe") as Error & {
    code: string;
  };
  error.code = "SWIPE_RETRY";
  return error;
}

type SuperLikeRefundSource = {
  superLikeUsedBonus: boolean | null;
  createdAt: Date;
};

/** Devolve um Super Like dentro da transação que remove sua Interaction. */
async function refundSuperLike(
  tx: Prisma.TransactionClient,
  userId: string,
  source: SuperLikeRefundSource
): Promise<void> {
  if (
    source.superLikeUsedBonus === true ||
    source.superLikeUsedBonus === null
  ) {
    await tx.user.update({
      where: { id: userId },
      data: { bonusSuperLikes: { increment: 1 } },
    });
    return;
  }

  if (source.createdAt < startOfToday()) return;

  const refundedDaily = await tx.user.updateMany({
    where: { id: userId, superLikesUsedToday: { gt: 0 } },
    data: { superLikesUsedToday: { decrement: 1 } },
  });
  if (refundedDaily.count === 0) {
    // Inconsistência atual: diária comprovada sem débito restaurável vira bônus.
    await tx.user.update({
      where: { id: userId },
      data: { bonusSuperLikes: { increment: 1 } },
    });
  }
}

async function persistSwipe(
  fromUserId: string,
  toUserId: string,
  type: SwipeType,
  note?: string
) {
  return prisma.$transaction(
    async (tx) => {
      const now = new Date();
      const [target, banned, block] = await Promise.all([
        tx.user.findUnique({
          where: { id: toUserId },
          select: {
            id: true,
            isBot: true,
            isBanned: true,
            suspendedUntil: true,
            deletedAt: true,
            profile: { select: { id: true } },
          },
        }),
        tx.bannedUser.findUnique({ where: { userId: toUserId } }),
        tx.block.findFirst({
          where: {
            OR: [
              { blockerId: fromUserId, blockedId: toUserId },
              { blockerId: toUserId, blockedId: fromUserId },
            ],
          },
          select: { id: true },
        }),
      ]);
      if (
        !target ||
        !target.profile ||
        target.isBanned ||
        target.deletedAt ||
        (target.suspendedUntil && target.suspendedUntil > now) ||
        banned ||
        block
      ) {
        throw new AppError(
          "Perfil alvo indisponível para swipe",
          422,
          undefined,
          "SWIPE_TARGET_UNAVAILABLE"
        );
      }

      const existingInteraction = await tx.interaction.findUnique({
        where: { fromUserId_toUserId: { fromUserId, toUserId } },
      });

      let superLikeUsedBonus = false;

      if (
        existingInteraction?.type === "SUPERLIKE" &&
        type !== "SUPERLIKE"
      ) {
        await refundSuperLike(tx, fromUserId, existingInteraction);
      }

      if (type === "SUPERLIKE" && existingInteraction?.type !== "SUPERLIKE") {
        let sender = await tx.user.findUnique({ where: { id: fromUserId } });
        if (!sender) throw new AppError("Usuário não encontrado", 404);

        const today = startOfToday();
        if (!sender.superLikesResetAt || sender.superLikesResetAt < today) {
          sender = await tx.user.update({
            where: { id: fromUserId },
            data: {
              superLikesUsedToday: 0,
              superLikesResetAt: now,
            },
          });
        }

        const premium = isPremiumActive(sender);
        const dailyLimit = premium
          ? PREMIUM_SUPERLIKES_PER_DAY
          : FREE_SUPERLIKES_PER_DAY;
        if (sender.superLikesUsedToday < dailyLimit) {
          // CAS evita duas requisições consumirem a mesma vaga diária.
          const consumedDaily = await tx.user.updateMany({
            where: {
              id: fromUserId,
              superLikesUsedToday: sender.superLikesUsedToday,
            },
            data: { superLikesUsedToday: { increment: 1 } },
          });
          if (consumedDaily.count !== 1) throw swipeRetryError();
          superLikeUsedBonus = false;
        } else {
          if (sender.bonusSuperLikes <= 0) {
            throw new AppError(
              premium
                ? "Você usou todos os seus Super Likes de hoje."
                : "Seus Super Likes acabaram. Assista a um anúncio para ganhar mais!",
              403,
              undefined,
              "SUPERLIKE_LIMIT"
            );
          }

          // A diária sempre é consumida primeiro; o bônus usa CAS somente
          // quando a quota diária já se esgotou.
          const consumedBonus = await tx.user.updateMany({
            where: {
              id: fromUserId,
              bonusSuperLikes: sender.bonusSuperLikes,
            },
            data: { bonusSuperLikes: { decrement: 1 } },
          });
          if (consumedBonus.count !== 1) throw swipeRetryError();
          superLikeUsedBonus = true;
        }
      }

      const preserveSuperLikeTimestamp =
        type === "SUPERLIKE" && existingInteraction?.type === "SUPERLIKE";
      await tx.interaction.upsert({
        where: { fromUserId_toUserId: { fromUserId, toUserId } },
        create: {
          fromUserId,
          toUserId,
          type,
          note: note?.trim() || null,
          superLikeUsedBonus,
          createdAt: now,
        },
        update: {
          type,
          note: note?.trim() || null,
          ...(preserveSuperLikeTimestamp
            ? {}
            : {
                superLikeUsedBonus:
                  type === "SUPERLIKE" ? superLikeUsedBonus : false,
              }),
          createdAt: preserveSuperLikeTimestamp
            ? existingInteraction.createdAt
            : now,
        },
      });

      if (type === "DISLIKE") {
        return {
          response: { matched: false as const },
          matchEvent: null,
          matchNotificationBody: null,
          systemMessage: null,
          notificationKind: null,
        };
      }

      if (target.isBot) {
        await tx.interaction.upsert({
          where: {
            fromUserId_toUserId: {
              fromUserId: toUserId,
              toUserId: fromUserId,
            },
          },
          create: {
            fromUserId: toUserId,
            toUserId: fromUserId,
            type: "LIKE",
            superLikeUsedBonus: false,
            createdAt: now,
          },
          update: {
            type: "LIKE",
            superLikeUsedBonus: false,
            createdAt: now,
          },
        });
      }

      const reciprocal = await tx.interaction.findUnique({
        where: {
          fromUserId_toUserId: {
            fromUserId: toUserId,
            toUserId: fromUserId,
          },
        },
      });
      if (
        !reciprocal ||
        (reciprocal.type !== "LIKE" && reciprocal.type !== "SUPERLIKE")
      ) {
        return {
          response: { matched: false as const },
          matchEvent: null,
          matchNotificationBody: null,
          systemMessage: null,
          notificationKind: type === "LIKE" ? "like" : "superlike",
        };
      }

      const [userAId, userBId] =
        fromUserId < toUserId
          ? [fromUserId, toUserId]
          : [toUserId, fromUserId];
      const match = await tx.match.upsert({
        where: { userAId_userBId: { userAId, userBId } },
        create: { userAId, userBId, isActive: true },
        update: { isActive: true },
      });

      const matchProfiles = await tx.profile.findMany({
        where: { userId: { in: [fromUserId, toUserId] } },
        include: publicProfileInclude,
      });
      const profileById = new Map(
        matchProfiles.map((profile) => [profile.userId, profile])
      );
      const fromProfile = profileById.get(fromUserId);
      const toProfile = profileById.get(toUserId);
      const fromMedia = fromProfile
        ? sanitizePublicMedia(fromProfile)
        : { mediaFiles: [], profilePicture: null };
      const toMedia = toProfile
        ? sanitizePublicMedia(toProfile)
        : { mediaFiles: [], profilePicture: null };

      const existingMessages = await tx.message.count({
        where: { matchId: match.id },
      });
      const systemMessage =
        existingMessages === 0
          ? await tx.message.create({
              data: {
                matchId: match.id,
                senderId: fromUserId,
                type: "SYSTEM",
                content:
                  "🎉 Vocês deram match! Que tal começar a conversa? 💛",
              },
            })
          : null;

      return {
        response: {
          matched: true as const,
          matchId: match.id,
          withUser: {
            userId: toUserId,
            name: toProfile?.fullName ?? "Alguém",
            photo: toMedia.profilePicture,
            ...publicVirtualFlags(toProfile?.user.isBot ?? false),
          },
        },
        matchEvent: {
          matchId: match.id,
          withUserId: fromUserId,
          name: fromProfile?.fullName ?? "Alguém",
          photo: fromMedia.profilePicture,
          ...publicVirtualFlags(fromProfile?.user.isBot ?? false),
        },
        matchNotificationBody: `${
          fromProfile?.fullName ?? "Alguém"
        } também curtiu você. Diga oi!`,
        systemMessage,
        notificationKind: null,
      };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
  );
}

/** Registra um swipe e cria match se houver reciprocidade. */
export async function swipe(
  fromUserId: string,
  toUserId: string,
  type: SwipeType,
  note?: string
) {
  if (fromUserId === toUserId) {
    throw new AppError("Não é possível interagir consigo mesmo", 422);
  }

  let result: Awaited<ReturnType<typeof persistSwipe>> | undefined;
  for (let attempt = 0; attempt < SWIPE_ATTEMPTS; attempt += 1) {
    try {
      result = await persistSwipe(fromUserId, toUserId, type, note);
      break;
    } catch (error) {
      const code = transactionErrorCode(error);
      if (code === "P2034" || code === "SWIPE_RETRY") {
        if (attempt < SWIPE_ATTEMPTS - 1) {
          await retryBackoff(attempt);
          continue;
        }
        // O conflito é esperado em picos; o esgotamento precisa deixar rastro.
        console.warn(
          `Swipe: ${SWIPE_ATTEMPTS} tentativas esgotadas por conflito de transação (usuário ${fromUserId})`
        );
        throw new AppError(
          "Não foi possível registrar o swipe; tente novamente",
          409,
          undefined,
          "SWIPE_CONFLICT"
        );
      }
      throw error;
    }
  }
  if (!result) {
    throw new AppError(
      "Não foi possível registrar o swipe; tente novamente",
      409,
      undefined,
      "SWIPE_CONFLICT"
    );
  }

  if (result.matchEvent && result.matchNotificationBody) {
    emitToUser(toUserId, "match:new", result.matchEvent);
    void notifyUser(
      toUserId,
      "Você tem um novo match! 💛",
      result.matchNotificationBody,
      { type: "match", data: { matchId: result.matchEvent.matchId } }
    );
  }
  if (result.systemMessage) {
    emitToUser(fromUserId, "message:new", result.systemMessage);
    emitToUser(toUserId, "message:new", result.systemMessage);
  }
  if (result.notificationKind === "like") {
    void notifyUser(
      toUserId,
      "Alguém curtiu você! 💛",
      "Você recebeu uma nova curtida. Veja quem foi!",
      { type: "like" }
    );
  } else if (result.notificationKind === "superlike") {
    void notifyUser(
      toUserId,
      "Você recebeu um Super Like! ⭐",
      "Alguém te super curtiu. Abra para ver!",
      { type: "superlike" }
    );
  }

  return result.response;
}

/** Desfaz o último swipe e devolve o card sanitizado para a descoberta. */
export async function undoLastSwipe(userId: string) {
  const now = new Date();
  const undone = await prisma.$transaction(async (tx) => {
    const last = await tx.interaction.findFirst({
      where: { fromUserId: userId },
      orderBy: { createdAt: "desc" },
    });
    if (!last) throw new AppError("Nada para desfazer", 400);

    const toUserId = last.toUserId;
    const [userAId, userBId] =
      userId < toUserId ? [userId, toUserId] : [toUserId, userId];
    const match = await tx.match.findUnique({
      where: { userAId_userBId: { userAId, userBId } },
    });
    if (match) {
      const nonSystemMessages = await tx.message.count({
        where: { matchId: match.id, type: { not: "SYSTEM" } },
      });
      if (nonSystemMessages === 0) {
        // A mensagem automática SYSTEM não impede remover um match recém-criado.
        await tx.match.delete({ where: { id: match.id } });
      } else if (match.isActive) {
        // Se já houve conversa, preserva o histórico, mas nunca deixa um match
        // ativo sem a interação que o originou.
        await tx.match.update({
          where: { id: match.id },
          data: { isActive: false },
        });
      }
    }

    await tx.interaction.delete({ where: { id: last.id } });
    if (last.type === "SUPERLIKE") {
      await refundSuperLike(tx, userId, last);
    }

    return { toUserId, type: last.type };
  });

  const [me, other, banned] = await Promise.all([
    prisma.profile.findUnique({ where: { userId } }),
    prisma.profile.findFirst({
      where: {
        userId: undone.toUserId,
        user: {
          isBanned: false,
          deletedAt: null,
          OR: [{ suspendedUntil: null }, { suspendedUntil: { lte: now } }],
        },
      },
      include: publicProfileInclude,
    }),
    prisma.bannedUser.findUnique({ where: { userId: undone.toUserId } }),
  ]);
  return {
    ok: true,
    undoneType: undone.type,
    card: me && other && !banned ? toCard(me, other) : null,
  };
}

/** Lista matches ativos com perfis públicos e mensagens agregadas em lote. */
export async function getMatches(userId: string) {
  const matches = await prisma.match.findMany({
    where: {
      isActive: true,
      OR: [{ userAId: userId }, { userBId: userId }],
    },
    orderBy: { createdAt: "desc" },
  });
  if (matches.length === 0) return [];

  const matchIds = matches.map((match) => match.id);
  const otherIds = matches.map((match) =>
    match.userAId === userId ? match.userBId : match.userAId
  );

  const [profiles, lastMessages, unreadGroups] = await Promise.all([
    prisma.profile.findMany({
      where: {
        userId: { in: otherIds },
        user: { isBanned: false, deletedAt: null },
      },
      include: publicProfileInclude,
    }),
    prisma.message.findMany({
      where: { matchId: { in: matchIds }, type: { not: "SYSTEM" } },
      orderBy: [{ matchId: "asc" }, { createdAt: "desc" }],
      distinct: ["matchId"],
      select: {
        matchId: true,
        content: true,
        type: true,
        senderId: true,
        createdAt: true,
        readAt: true,
      },
    }),
    prisma.message.groupBy({
      by: ["matchId"],
      where: {
        matchId: { in: matchIds },
        senderId: { not: userId },
        readAt: null,
        type: { not: "SYSTEM" },
      },
      _count: { _all: true },
    }),
  ]);

  const profileByUser = new Map(
    profiles.map((profile) => [profile.userId, profile])
  );
  const lastByMatch = new Map(
    lastMessages.map((message) => [message.matchId, message])
  );
  const unreadByMatch = new Map(
    unreadGroups.map((group) => [group.matchId, group._count._all])
  );

  return matches.map((match) => {
    const otherId =
      match.userAId === userId ? match.userBId : match.userAId;
    const otherProfile = profileByUser.get(otherId);
    const lastMessage = lastByMatch.get(match.id);
    const publicMedia = otherProfile
      ? sanitizePublicMedia(otherProfile)
      : { mediaFiles: [], profilePicture: null };

    return {
      matchId: match.id,
      createdAt: match.createdAt,
      otherUser: otherProfile
        ? {
            id: otherProfile.userId,
            name: otherProfile.fullName,
            profilePicture: publicMedia.profilePicture,
            isOnline: isRecentlyOnline(otherProfile),
            ...publicVirtualFlags(otherProfile.user.isBot),
          }
        : {
            id: otherId,
            name: "Usuário",
            profilePicture: null,
            isOnline: false,
            ...publicVirtualFlags(false),
          },
      lastMessage: lastMessage
        ? {
            content: lastMessage.content,
            type: lastMessage.type,
            senderId: lastMessage.senderId,
            createdAt: lastMessage.createdAt,
            readAt: lastMessage.readAt,
          }
        : null,
      unreadCount: unreadByMatch.get(match.id) ?? 0,
    };
  });
}
