import { Profile } from "@prisma/client";
import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { ageFromBirthday } from "../../lib/age";
import { AppError } from "../../lib/errors";
import { distanceBetween } from "../../lib/geo";
import { isPremiumActive } from "../../lib/premium";
import { isRecentlyOnline } from "../../lib/presence";
import {
  PublicProfileSource,
  publicProfileInclude,
  publicVirtualFlags,
  sanitizePublicMedia,
} from "../../lib/publicProfile";
import * as service from "./match.service";

const swipeSchema = z.object({
  toUserId: z.string().uuid(),
  type: z.enum(["LIKE", "DISLIKE", "SUPERLIKE"]),
  note: z.string().max(300).optional(),
});

function numericQueryValue(value: unknown): unknown {
  if (value === undefined) return undefined;
  if (typeof value === "number") return value;
  if (typeof value !== "string" || value.trim() === "") return Number.NaN;
  return Number(value);
}

const discoveryQuerySchema = z
  .object({
    minAge: z.preprocess(
      numericQueryValue,
      z.number().finite().int().min(18).max(99).optional()
    ),
    maxAge: z.preprocess(
      numericQueryValue,
      z.number().finite().int().min(18).max(99).optional()
    ),
    maxDistanceKm: z.preprocess(
      numericQueryValue,
      z.number().finite().positive().optional()
    ),
  })
  .superRefine((value, ctx) => {
    if (
      value.minAge !== undefined &&
      value.maxAge !== undefined &&
      value.minAge > value.maxAge
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["maxAge"],
        message: "maxAge deve ser maior ou igual a minAge",
      });
    }
  });

const premiumFilterSchema = z.string().trim().min(1).max(60);

function cardFromProfile(
  profile: PublicProfileSource | undefined,
  userId: string,
  me?: Profile | null
) {
  if (!profile) {
    return {
      userId,
      name: "Usuário",
      age: null,
      profilePicture: null,
      city: null,
      distanceKm: null,
      isOnline: false,
      lastActiveAt: null,
      ...publicVirtualFlags(false),
    };
  }
  const media = sanitizePublicMedia(profile);
  return {
    userId,
    name: profile.fullName,
    age: ageFromBirthday(profile.birthday),
    profilePicture: media.profilePicture,
    city: profile.city,
    distanceKm: me ? distanceBetween(me, profile) : null,
    isOnline: isRecentlyOnline(profile),
    lastActiveAt: profile.lastActiveAt,
    ...publicVirtualFlags(profile.user.isBot),
  };
}

// GET /api/likes — matches e curtidas recebidas.
export async function likes(req: Request, res: Response) {
  const userId = req.userId!;
  const [user, me, matches, incoming, outgoing] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.profile.findUnique({ where: { userId } }),
    prisma.match.findMany({
      where: {
        isActive: true,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      orderBy: { createdAt: "desc" },
    }),
    prisma.interaction.findMany({
      where: { toUserId: userId, type: { in: ["LIKE", "SUPERLIKE"] } },
      orderBy: { createdAt: "desc" },
    }),
    prisma.interaction.findMany({
      where: { fromUserId: userId },
      select: { toUserId: true },
    }),
  ]);

  const matchedIds = new Set(
    matches.map((match) =>
      match.userAId === userId ? match.userBId : match.userAId
    )
  );
  const outgoingIds = new Set(
    outgoing.map((interaction) => interaction.toUserId)
  );
  const pending = incoming.filter(
    (interaction) =>
      !outgoingIds.has(interaction.fromUserId) &&
      !matchedIds.has(interaction.fromUserId)
  );
  // Ver quem te curtiu é VIP (pelo painel ou por anúncio). A trava fica aqui:
  // sem VIP a resposta não leva nada que identifique quem curtiu.
  const canSeeLikes = user ? isPremiumActive(user) : false;
  const profileIds = Array.from(
    new Set([
      ...matchedIds,
      ...(canSeeLikes
        ? pending.map((interaction) => interaction.fromUserId)
        : []),
    ])
  );
  const profiles = profileIds.length
    ? await prisma.profile.findMany({
        where: {
          userId: { in: profileIds },
          user: { isBanned: false, deletedAt: null },
        },
        include: publicProfileInclude,
      })
    : [];
  const profileById = new Map(
    profiles.map((profile) => [profile.userId, profile])
  );

  const matchCards = matches.map((match) => {
    const otherId =
      match.userAId === userId ? match.userBId : match.userAId;
    return {
      ...cardFromProfile(profileById.get(otherId), otherId, me),
      matchId: match.id,
    };
  });
  const bySuperLikeFirst = (
    first: { superLike: boolean },
    second: { superLike: boolean }
  ) => Number(second.superLike) - Number(first.superLike);
  const likedYou = canSeeLikes
    ? pending
        .map((interaction) => ({
          ...cardFromProfile(
            profileById.get(interaction.fromUserId),
            interaction.fromUserId,
            me
          ),
          superLike: interaction.type === "SUPERLIKE",
          note: interaction.note ?? null,
        }))
        .sort(bySuperLikeFirst)
    : pending
        .map((interaction) => ({
          locked: true as const,
          superLike: interaction.type === "SUPERLIKE",
        }))
        .sort(bySuperLikeFirst);

  res.json({
    isPremium: canSeeLikes,
    likedYouLocked: !canSeeLikes,
    matches: matchCards,
    likedYou,
    likedYouCount: likedYou.length,
  });
}

// GET /api/discovery
export async function discovery(req: Request, res: Response) {
  const { minAge, maxAge, maxDistanceKm } = discoveryQuerySchema.parse({
    minAge: req.query.minAge,
    maxAge: req.query.maxAge,
    maxDistanceKm: req.query.maxDistanceKm,
  });
  const genderRaw = req.query.gender ? String(req.query.gender) : undefined;
  const gender =
    genderRaw === "MALE" || genderRaw === "FEMALE" || genderRaw === "OTHER"
      ? genderRaw
      : undefined;
  const denominations = req.query.denominations
    ? String(req.query.denominations).split(",").filter(Boolean)
    : undefined;
  const interests = req.query.interests
    ? String(req.query.interests).split(",").filter(Boolean)
    : undefined;
  const intention = premiumFilterSchema.optional().parse(req.query.intention);
  const churchFrequency = premiumFilterSchema
    .optional()
    .parse(req.query.churchFrequency);

  if (intention !== undefined || churchFrequency !== undefined) {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      select: { isPremium: true, premiumUntil: true },
    });
    if (!user || !isPremiumActive(user)) {
      throw new AppError(
        "Os filtros de intenção e frequência à igreja são recursos VIP.",
        403,
        undefined,
        "PREMIUM_ONLY"
      );
    }
  }

  const result = await service.getDiscovery(req.userId!, {
    minAge,
    maxAge,
    maxDistanceKm,
    gender,
    denominations,
    interests,
    intention,
    churchFrequency,
  });
  res.json(result);
}

// POST /api/swipe
export async function swipe(req: Request, res: Response) {
  const { toUserId, type, note } = swipeSchema.parse(req.body);
  const result = await service.swipe(req.userId!, toUserId, type, note);
  res.json(result);
}

// POST /api/swipe/undo — desfaz o último swipe (Rewind)
export async function undoSwipe(req: Request, res: Response) {
  const userId = req.userId!;
  const settings = await prisma.appSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
  if (settings.rewindPremiumOnly) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !isPremiumActive(user)) {
      return res.status(403).json({
        error: "O Rewind para desfazer swipes é um recurso exclusivo VIP.",
        code: "PREMIUM_ONLY",
      });
    }
  }
  try {
    const result = await service.undoLastSwipe(userId);
    res.json(result);
  } catch (error) {
    throw new AppError((error as Error).message, 400);
  }
}

// GET /api/matches
export async function matches(req: Request, res: Response) {
  const list = await service.getMatches(req.userId!);
  res.json({ matches: list });
}

// GET /api/top-picks — melhores perfis por compatibilidade
export async function topPicks(req: Request, res: Response) {
  const result = await service.getTopPicks(req.userId!);
  res.json(result);
}

// GET /api/users/:id/profile — card público aberto a partir do chat.
export async function userCard(req: Request, res: Response) {
  const targetId = req.params.id;
  const [me, other] = await Promise.all([
    prisma.profile.findUnique({ where: { userId: req.userId! } }),
    prisma.profile.findFirst({
      where: {
        userId: targetId,
        user: { isBanned: false, deletedAt: null },
      },
      include: publicProfileInclude,
    }),
  ]);
  if (!other) throw new AppError("Perfil não encontrado", 404);

  const media = sanitizePublicMedia(other);
  res.json({
    user: {
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
      distanceKm: me ? distanceBetween(me, other) : null,
      matchPercent: me ? service.computeMatchPercent(me, other) : null,
      ...publicVirtualFlags(other.user.isBot),
    },
  });
}
