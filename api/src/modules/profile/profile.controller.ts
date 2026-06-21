import { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { randomUUID } from "crypto";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { isAdult } from "../../lib/age";
import { UPLOADS_DIR } from "../../config/paths";
import { upsertProfileSchema, locationSchema } from "./profile.validators";
import {
  PREMIUM_PLANS,
  ensureDailyReset,
  premiumStats,
} from "../../lib/premium";

// GET /api/me/profile
export async function getMyProfile(req: Request, res: Response) {
  const profile = await prisma.profile.findUnique({
    where: { userId: req.userId },
  });
  res.json({ profile: profile ?? null });
}

// PUT /api/me/profile  (cria ou atualiza)
export async function upsertMyProfile(req: Request, res: Response) {
  const data = upsertProfileSchema.parse(req.body);

  if (!isAdult(data.birthday)) {
    throw new AppError("É necessário ter ao menos 18 anos", 422);
  }

  const profile = await prisma.profile.upsert({
    where: { userId: req.userId! },
    create: {
      userId: req.userId!,
      fullName: data.fullName,
      gender: data.gender,
      birthday: data.birthday,
      about: data.about,
      intention: data.intention,
      denomination: data.denomination,
      churchFrequency: data.churchFrequency,
      city: data.city,
      interests: data.interests ?? [],
      mediaFiles: data.mediaFiles ?? [],
      lockedPhotos: data.lockedPhotos ?? [],
      profilePicture: data.profilePicture,
      instagram: data.instagram,
      tiktok: data.tiktok,
      twitter: data.twitter,
      facebook: data.facebook,
      prompts: data.prompts ?? undefined,
    },
    update: {
      fullName: data.fullName,
      gender: data.gender,
      birthday: data.birthday,
      about: data.about,
      intention: data.intention,
      denomination: data.denomination,
      churchFrequency: data.churchFrequency,
      city: data.city,
      interests: data.interests,
      mediaFiles: data.mediaFiles,
      lockedPhotos: data.lockedPhotos,
      profilePicture: data.profilePicture,
      instagram: data.instagram,
      tiktok: data.tiktok,
      twitter: data.twitter,
      facebook: data.facebook,
      prompts: data.prompts ?? undefined,
    },
  });

  res.json({ profile });
}

// POST /api/me/boost — ativa o Turbo (consome 1 boost; destaque por X min)
export async function activateBoost(req: Request, res: Response) {
  const userId = req.userId!;
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError("Usuário não encontrado", 404);
  if (user.boostsRemaining <= 0) {
    return res.status(403).json({
      error: "Você não tem Boosts. Compre para se destacar!",
      code: "NO_BOOSTS",
    });
  }
  const settings = await prisma.appSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
  const until = new Date(Date.now() + settings.boostDurationMin * 60000);
  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: { boostsRemaining: { decrement: 1 } },
    }),
    prisma.profile.updateMany({
      where: { userId },
      data: { boostUntil: until },
    }),
  ]);
  res.json({ ok: true, boostUntil: until, minutes: settings.boostDurationMin });
}

// POST /api/me/incognito  { enabled }
export async function setIncognito(req: Request, res: Response) {
  const userId = req.userId!;
  const enabled = req.body?.enabled === true;
  if (enabled) {
    const settings = await prisma.appSettings.upsert({
      where: { id: 1 },
      create: { id: 1 },
      update: {},
    });
    if (settings.incognitoPremiumOnly) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      const { isPremiumActive } = await import("../../lib/premium");
      if (!user || !isPremiumActive(user)) {
        return res.status(403).json({
          error: "O modo incógnito é um recurso VIP.",
          code: "PREMIUM_ONLY",
        });
      }
    }
  }
  await prisma.profile.updateMany({
    where: { userId },
    data: { incognito: enabled },
  });
  res.json({ ok: true, incognito: enabled });
}

// POST /api/me/purchase  { productId }
// Concede o produto comprado. (Integração com a Google Play Billing: a verificação
// do token de compra deve ser adicionada antes de produção — por ora concede direto.)
export async function redeemProduct(req: Request, res: Response) {
  const userId = req.userId!;
  const productId = String(req.body?.productId ?? "");
  if (!productId) throw new AppError("productId é obrigatório", 422);

  const product = await prisma.product.findUnique({ where: { id: productId } });
  if (!product || !product.active) throw new AppError("Produto indisponível", 404);

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError("Usuário não encontrado", 404);

  const data: Record<string, unknown> = {};
  if (product.kind === "PREMIUM") {
    const days = product.durationDays ?? 30;
    const base =
      user.premiumUntil && user.premiumUntil > new Date()
        ? user.premiumUntil
        : new Date();
    data.isPremium = true;
    data.premiumPlan = product.googleProductId ?? "plan";
    data.premiumUntil = new Date(base.getTime() + days * 86400000);
  } else if (product.kind === "CREDITS") {
    data.credits = { increment: product.amount };
  } else if (product.kind === "BOOSTS") {
    data.boostsRemaining = { increment: product.amount };
  } else if (product.kind === "SUPERLIKES") {
    // libera super likes extras hoje (reduz o contador de uso)
    data.superLikesUsedToday = user.superLikesUsedToday - product.amount;
  }

  const updated = await prisma.user.update({ where: { id: userId }, data });
  res.json({
    ok: true,
    kind: product.kind,
    credits: updated.credits,
    boostsRemaining: updated.boostsRemaining,
    isPremium: updated.isPremium,
  });
}

// PUT /api/me/location
export async function updateLocation(req: Request, res: Response) {
  const { latitude, longitude, addressText } = locationSchema.parse(req.body);
  const profile = await prisma.profile.update({
    where: { userId: req.userId! },
    data: { latitude, longitude, addressText },
  });
  res.json({ profile });
}

// POST /api/me/online  (atualiza presença/last active)
export async function setOnline(req: Request, res: Response) {
  const isOnline = req.body?.isOnline !== false;
  const profile = await prisma.profile.update({
    where: { userId: req.userId! },
    data: { isOnline, lastActiveAt: new Date() },
  });
  res.json({ isOnline: profile.isOnline });
}

// POST /api/me/premium  { plan? , active? }
// Ativa um plano VIP (monthly/quarterly/yearly) ou liga/desliga em modo dev.
export async function setPremium(req: Request, res: Response) {
  const plan = req.body?.plan ? String(req.body.plan) : undefined;

  // Desativar explicitamente.
  if (req.body?.active === false) {
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { isPremium: false, premiumPlan: null, premiumUntil: null },
    });
    return res.json(premiumStats(user));
  }

  // Assinar um plano com validade.
  if (plan && PREMIUM_PLANS[plan]) {
    const { days } = PREMIUM_PLANS[plan];
    const base = new Date();
    const until = new Date(base.getTime() + days * 24 * 60 * 60 * 1000);
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { isPremium: true, premiumPlan: plan, premiumUntil: until },
    });
    return res.json(premiumStats(user));
  }

  // Compat dev: { active: true } sem plano → premium "infinito" de teste.
  const user = await prisma.user.update({
    where: { id: req.userId! },
    data: { isPremium: true, premiumPlan: "dev", premiumUntil: null },
  });
  res.json(premiumStats(user));
}

// GET /api/me/stats — estado premium + limites de super like + planos
export async function getStats(req: Request, res: Response) {
  const user = await ensureDailyReset(req.userId!);
  res.json({
    ...premiumStats(user),
    plans: Object.entries(PREMIUM_PLANS).map(([id, p]) => ({ id, ...p })),
  });
}

const ALLOWED_EXT = ["jpg", "jpeg", "png", "webp", "m4a", "aac", "mp3", "wav", "ogg"];

// POST /api/me/photos  { image: base64, ext }
// Recebe a mídia (imagem OU áudio) em base64, salva no disco (dev) e retorna a URL.
export async function uploadPhoto(req: Request, res: Response) {
  const image = (req.body?.image ?? "").toString();
  let ext = (req.body?.ext ?? "jpg").toString().toLowerCase().replace(".", "");
  if (!ALLOWED_EXT.includes(ext)) ext = "jpg";

  // Aceita "data:image/...;base64,XXXX" ou só o base64.
  const base64 = image.includes(",") ? image.split(",").pop()! : image;
  if (!base64 || base64.length < 24) {
    throw new AppError("Imagem inválida", 422);
  }

  let buffer: Buffer;
  try {
    buffer = Buffer.from(base64, "base64");
  } catch {
    throw new AppError("Falha ao decodificar a imagem", 422);
  }
  if (buffer.length > 8 * 1024 * 1024) {
    throw new AppError("Imagem muito grande (máx. 8MB)", 413);
  }

  if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  const fileName = `${req.userId}-${randomUUID()}.${ext}`;
  fs.writeFileSync(path.join(UPLOADS_DIR, fileName), buffer);

  const url = `${req.protocol}://${req.get("host")}/uploads/${fileName}`;
  res.status(201).json({ url });
}
