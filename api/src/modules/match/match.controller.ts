import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { ageFromBirthday } from "../../lib/age";
import { distanceBetween } from "../../lib/geo";
import { isPremiumActive } from "../../lib/premium";
import * as service from "./match.service";

const swipeSchema = z.object({
  toUserId: z.string().uuid(),
  type: z.enum(["LIKE", "DISLIKE", "SUPERLIKE"]),
  note: z.string().max(300).optional(),
});

function cardFromProfile(p: any, userId: string, me?: any) {
  if (!p) {
    return { userId, name: "Usuário", age: null, profilePicture: null, city: null };
  }
  const distance = me ? distanceBetween(me, p) : null;
  return {
    userId,
    name: p.fullName,
    age: ageFromBirthday(p.birthday),
    profilePicture: p.profilePicture,
    city: p.city,
    distanceKm: distance,
    isOnline: p.isOnline,
    lastActiveAt: p.lastActiveAt,
  };
}

// GET /api/likes — quem deu match + quem te curtiu (gated por premium)
export async function likes(req: Request, res: Response) {
  const userId = req.userId!;
  const user = await prisma.user.findUnique({ where: { id: userId } });
  const isPremium = user ? isPremiumActive(user) : false;
  const me = await prisma.profile.findUnique({ where: { userId } });

  const matches = await prisma.match.findMany({
    where: { isActive: true, OR: [{ userAId: userId }, { userBId: userId }] },
    orderBy: { createdAt: "desc" },
  });
  const matchCards = await Promise.all(
    matches.map(async (m) => {
      const otherId = m.userAId === userId ? m.userBId : m.userAId;
      const p = await prisma.profile.findUnique({ where: { userId: otherId } });
      return { ...cardFromProfile(p, otherId, me), matchId: m.id };
    })
  );
  const matchedIds = new Set(matchCards.map((c) => c.userId));

  const incoming = await prisma.interaction.findMany({
    where: { toUserId: userId, type: { in: ["LIKE", "SUPERLIKE"] } },
    orderBy: { createdAt: "desc" },
  });
  const myOut = new Set(
    (
      await prisma.interaction.findMany({
        where: { fromUserId: userId },
        select: { toUserId: true },
      })
    ).map((i) => i.toUserId)
  );
  const pending = incoming.filter(
    (i) => !myOut.has(i.fromUserId) && !matchedIds.has(i.fromUserId)
  );
  let likedYou = await Promise.all(
    pending.map(async (i) => {
      const p = await prisma.profile.findUnique({ where: { userId: i.fromUserId } });
      return {
        ...cardFromProfile(p, i.fromUserId, me),
        superLike: i.type === "SUPERLIKE",
        note: i.note ?? null,
      };
    })
  );
  // Super likes têm prioridade (aparecem primeiro).
  likedYou = likedYou.sort(
    (a, b) => (b.superLike ? 1 : 0) - (a.superLike ? 1 : 0)
  );

  res.json({
    isPremium,
    matches: matchCards,
    likedYou,
    likedYouCount: likedYou.length,
  });
}

// GET /api/discovery
export async function discovery(req: Request, res: Response) {
  const minAge = req.query.minAge ? Number(req.query.minAge) : undefined;
  const maxAge = req.query.maxAge ? Number(req.query.maxAge) : undefined;
  const maxDistanceKm = req.query.maxDistanceKm
    ? Number(req.query.maxDistanceKm)
    : undefined;
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
  const intention = req.query.intention ? String(req.query.intention) : undefined;
  const churchFrequency = req.query.churchFrequency
    ? String(req.query.churchFrequency)
    : undefined;

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
  try {
    const result = await service.swipe(req.userId!, toUserId, type, note);
    res.json(result);
  } catch (e) {
    const err = e as Error & { code?: string };
    if (err.code === "SUPERLIKE_LIMIT") {
      return res.status(403).json({ error: err.message, code: "SUPERLIKE_LIMIT" });
    }
    throw new AppError(err.message, 400);
  }
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
        error: "O Rewind é um recurso VIP. Assine para desfazer swipes!",
        code: "PREMIUM_ONLY",
      });
    }
  }
  try {
    const result = await service.undoLastSwipe(userId);
    res.json(result);
  } catch (e) {
    throw new AppError((e as Error).message, 400);
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

// GET /api/users/:id/profile — card público de um usuário (para abrir pelo chat)
export async function userCard(req: Request, res: Response) {
  const targetId = req.params.id;
  const [me, other] = await Promise.all([
    prisma.profile.findUnique({ where: { userId: req.userId! } }),
    prisma.profile.findUnique({ where: { userId: targetId } }),
  ]);
  if (!other) throw new AppError("Perfil não encontrado", 404);
  const locked = new Set(other.lockedPhotos);
  const publicMedia = other.mediaFiles.filter((m) => !locked.has(m));
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
      mediaFiles: publicMedia,
      profilePicture: other.profilePicture,
      isVerified: other.isVerified,
      isOnline: other.isOnline,
      lastActiveAt: other.lastActiveAt,
      distanceKm: me ? distanceBetween(me, other) : null,
      matchPercent:
        me != null ? service.computeMatchPercent(me, other) : null,
    },
  });
}
