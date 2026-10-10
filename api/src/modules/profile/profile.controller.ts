import { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { randomUUID } from "crypto";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { isAdult } from "../../lib/age";
import { UPLOADS_DIR } from "../../config/paths";
import { upsertProfileSchema, locationSchema } from "./profile.validators";
import { ensureDailyReset, premiumStats } from "../../lib/premium";

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
      latitude: data.latitude,
      longitude: data.longitude,
      addressText: data.addressText,
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
      latitude: data.latitude,
      longitude: data.longitude,
      addressText: data.addressText,
      prompts: data.prompts ?? undefined,
    },
  });

  res.json({ profile });
}

/** Aborta (e reverte) a transação do Boost quando não há saldo. */
class NoBoostsSignal extends Error {}

// POST /api/me/boost — ativa o Turbo (consome 1 boost; destaque por X min)
export async function activateBoost(req: Request, res: Response) {
  const userId = req.userId!;
  // Só leitura (sem upsert): ativações simultâneas não disputam a criação da linha.
  const settings = await prisma.appSettings.findUnique({ where: { id: 1 } });
  const boostMinutes = settings?.boostDurationMin ?? 30;
  const until = new Date(Date.now() + boostMinutes * 60000);

  const outcome = await prisma
    .$transaction(async (tx) => {
      const profile = await tx.profile.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (!profile) return "NO_PROFILE" as const;

      // Porta atômica: só um pedido consegue abrir a janela do Boost; os
      // simultâneos esperam o primeiro e encontram o Boost já ativo.
      const opened = await tx.profile.updateMany({
        where: {
          userId,
          OR: [{ boostUntil: null }, { boostUntil: { lte: new Date() } }],
        },
        data: { boostUntil: until },
      });
      if (opened.count !== 1) return "ACTIVE" as const;

      // Decremento condicionado: nunca passa do saldo. Sem saldo, desfaz a
      // janela aberta acima (a transação inteira é revertida).
      const consumed = await tx.user.updateMany({
        where: { id: userId, boostsRemaining: { gt: 0 } },
        data: { boostsRemaining: { decrement: 1 } },
      });
      if (consumed.count !== 1) throw new NoBoostsSignal();
      return "OK" as const;
    })
    .catch((error: unknown) => {
      if (error instanceof NoBoostsSignal) return "NO_BOOSTS" as const;
      throw error;
    });

  if (outcome === "NO_PROFILE") {
    throw new AppError("Crie seu perfil antes de usar um Boost", 404);
  }
  if (outcome === "ACTIVE") {
    throw new AppError(
      "Você já tem um Boost ativo.",
      409,
      undefined,
      "BOOST_ACTIVE"
    );
  }
  if (outcome === "NO_BOOSTS") {
    return res.status(403).json({
      error: "Você não tem Boosts. Assista a um anúncio para ganhar um!",
      code: "NO_BOOSTS",
    });
  }
  res.json({ ok: true, boostUntil: until, minutes: boostMinutes });
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

// GET /api/me/stats — estado VIP, limites de Super Like e saldos (boosts/créditos)
export async function getStats(req: Request, res: Response) {
  const user = await ensureDailyReset(req.userId!);
  res.json(premiumStats(user));
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
