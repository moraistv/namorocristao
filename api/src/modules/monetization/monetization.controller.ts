import { Request, Response } from "express";
import { randomUUID } from "crypto";
import fs from "fs";
import path from "path";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { lockAdSettings } from "../../lib/adSettingsLock";
import { AppError } from "../../lib/errors";
import { UPLOADS_DIR } from "../../config/paths";
import { clearSsvRejection } from "../rewards/ssvDiagnostics";
import { emitToAll } from "../../sockets";

// ───────────────────────── Presentes (gifts) ─────────────────────────

const giftSchema = z.object({
  name: z.string().min(1),
  imageUrl: z.string().min(1),
  costCredits: z.number().int().min(0).default(1),
  active: z.boolean().default(true),
  sortOrder: z.number().int().default(0),
});

// Upload de imagem (gif/png/svg) em base64 → disco. POST /api/admin/gifts/upload
const uploadSchema = z.object({
  image: z.string().min(10),
  ext: z.string().max(5),
});
const ALLOWED_EXT = ["gif", "png", "svg", "jpg", "jpeg", "webp"];

export async function uploadGiftImage(req: Request, res: Response) {
  const { image, ext } = uploadSchema.parse(req.body);
  const clean = ext.toLowerCase().replace(".", "");
  if (!ALLOWED_EXT.includes(clean)) throw new AppError("Formato não permitido", 400);

  const base64 = image.includes(",") ? image.split(",")[1] : image;
  const buffer = Buffer.from(base64, "base64");
  if (buffer.length > 5 * 1024 * 1024) throw new AppError("Imagem muito grande (máx 5MB)", 400);

  if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  const fileName = `gift-${randomUUID()}.${clean}`;
  fs.writeFileSync(path.join(UPLOADS_DIR, fileName), buffer);
  // Caminho relativo: cada cliente (painel/app) resolve para o host correto.
  res.status(201).json({ url: `/uploads/${fileName}` });
}

// GET /api/admin/gifts
export async function listGifts(_req: Request, res: Response) {
  const gifts = await prisma.gift.findMany({ orderBy: [{ sortOrder: "asc" }, { createdAt: "desc" }] });
  res.json({ gifts });
}

// POST /api/admin/gifts
export async function createGift(req: Request, res: Response) {
  const data = giftSchema.parse(req.body);
  const gift = await prisma.gift.create({ data });
  emitToAll("config:store", { changed: true });
  res.status(201).json({ gift });
}

// PUT /api/admin/gifts/:id
export async function updateGift(req: Request, res: Response) {
  const data = giftSchema.partial().parse(req.body);
  const gift = await prisma.gift.update({ where: { id: req.params.id }, data });
  emitToAll("config:store", { changed: true });
  res.json({ gift });
}

// DELETE /api/admin/gifts/:id
export async function deleteGift(req: Request, res: Response) {
  await prisma.gift.delete({ where: { id: req.params.id } });
  emitToAll("config:store", { changed: true });
  res.json({ ok: true });
}

// ───────────────────────── Anúncios (AdMob / Ad Manager) ─────────────────────────

const adSchema = z.object({
  enabled: z.boolean(),
  testMode: z.boolean(),
  testDeviceIds: z.string().optional().nullable(),

  appOpenEnabled: z.boolean(),
  bannerEnabled: z.boolean(),
  interstitialEnabled: z.boolean(),
  rewardedEnabled: z.boolean(),
  rewardedInterstitialEnabled: z.boolean(),
  nativeEnabled: z.boolean(),

  // Espaços nas pontas (comuns ao colar) quebrariam o carregamento do bloco.
  androidAppOpenId: z.string().trim().optional().nullable(),
  androidBannerId: z.string().trim().optional().nullable(),
  androidInterstitialId: z.string().trim().optional().nullable(),
  androidRewardedId: z.string().trim().optional().nullable(),
  androidRewardedInterstitialId: z.string().trim().optional().nullable(),
  androidNativeId: z.string().trim().optional().nullable(),

  bannerPosition: z.enum(["top", "bottom"]),

  appOpenOnResume: z.boolean(),
  appOpenEverySecs: z.number().int().min(0).max(86400),

  interstitialEverySecs: z.number().int().min(0).max(3600),
  interstitialEveryClicks: z.number().int().min(0).max(1000),
  interstitialOnOpenChat: z.boolean(),
  interstitialOnOpenProfile: z.boolean(),
  interstitialOnSwipe: z.boolean(),

  maxAdsPerSession: z.number().int().min(0).max(1000),
  maxAdsPerDay: z.number().int().min(0).max(10000),
});

// GET /api/admin/ads
export async function getAds(_req: Request, res: Response) {
  const ads = await prisma.adSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
  res.json({ ads });
}

// PUT /api/admin/ads
export async function updateAds(req: Request, res: Response) {
  const data = adSchema.parse(req.body);

  // Lê, decide e grava com a linha travada: o PUT de Recompensas decide com
  // base nos mesmos campos e não pode gravar sobre um retrato desatualizado.
  const { ads, rewardedBlockChanged } = await prisma.$transaction(async (tx) => {
    const current = await lockAdSettings(tx);

    // Campo ausente no corpo = não muda (o Prisma também o ignora).
    const before = current.androidRewardedId?.trim() || null;
    const after =
      data.androidRewardedId === undefined
        ? before
        : data.androidRewardedId?.trim() || null;
    const rewardedBlockChanged = before !== after;

    // Com a confirmação do Google exigida, o ad_unit esperado pertence ao bloco
    // Premiado atual: trocar o ID por trás da exigência faria todo resgate
    // ficar pendente (ou aceitaria o bloco errado).
    if (current.rewardsRequireSsv && rewardedBlockChanged) {
      throw new AppError(
        "A confirmação do Google está exigida para o bloco Premiado atual. Desligue a exigência em Recompensas antes de trocar o ID do bloco.",
        409,
        undefined,
        "SSV_UNIT_LOCKED"
      );
    }

    const saved = await tx.adSettings.update({
      where: { id: 1 },
      // A prova do SSV (último callback e ad_unit esperado) é do bloco antigo:
      // com outro bloco ela precisa ser refeita, senão a exigência poderia ser
      // religada com um ad_unit que o bloco novo nunca vai enviar.
      data: rewardedBlockChanged
        ? {
            ...data,
            rewardsSsvAdUnit: null,
            rewardsSsvLastAt: null,
            rewardsSsvLastAdUnit: null,
          }
        : data,
    });
    return { ads: saved, rewardedBlockChanged };
  });
  // A recusa guardada em memória era do bloco antigo.
  if (rewardedBlockChanged) clearSsvRejection();
  // Avisa todos os apps conectados para recarregarem a config de anúncios na hora.
  emitToAll("config:ads", { changed: true });
  res.json({ ads });
}

// ───────────────────────── Verso do dia ─────────────────────────

const verseSchema = z.object({
  reference: z.string().min(1).max(120),
  text: z.string().min(1).max(600),
  active: z.boolean().default(true),
  sortOrder: z.number().int().default(0),
});

// GET /api/admin/verses
export async function listVerses(_req: Request, res: Response) {
  const verses = await prisma.dailyVerse.findMany({
    orderBy: [{ sortOrder: "asc" }, { createdAt: "desc" }],
  });
  res.json({ verses });
}

// POST /api/admin/verses
export async function createVerse(req: Request, res: Response) {
  const data = verseSchema.parse(req.body);
  const verse = await prisma.dailyVerse.create({ data });
  res.status(201).json({ verse });
}

// PUT /api/admin/verses/:id
export async function updateVerse(req: Request, res: Response) {
  const data = verseSchema.partial().parse(req.body);
  const verse = await prisma.dailyVerse.update({ where: { id: req.params.id }, data });
  res.json({ verse });
}

// DELETE /api/admin/verses/:id
export async function deleteVerse(req: Request, res: Response) {
  await prisma.dailyVerse.delete({ where: { id: req.params.id } });
  res.json({ ok: true });
}

// GET /api/config/verse — verso do dia (app, público). Rotaciona por dia.
export async function publicDailyVerse(_req: Request, res: Response) {
  const list = await getVerseList();
  if (list === null) return res.json({ verse: null });

  // Índice do dia do ano → rotaciona o verso diariamente.
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now.getTime() - start.getTime()) / 86400000);
  const verse = list[dayOfYear % list.length];
  res.json({ verse: { reference: verse.reference, text: verse.text } });
}

// GET /api/config/verses — lista completa de versos ativos (app rotaciona localmente)
export async function publicVerses(_req: Request, res: Response) {
  const list = await getVerseList();
  if (list === null) return res.json({ verses: [] });
  res.json({ verses: list.map((v) => ({ reference: v.reference, text: v.text })) });
}

// Lista de versos ativos (ou fallback embutido). null = recurso desativado.
async function getVerseList(): Promise<{ reference: string; text: string }[] | null> {
  const settings = await prisma.appSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
  if (!settings.dailyVerseEnabled) return null;

  const verses = await prisma.dailyVerse.findMany({
    where: { active: true },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
  });

  // Lista padrão embutida (usada enquanto o admin não cadastra versos próprios).
  const fallback = [
    { reference: "Provérbios 3:5", text: "Confie no Senhor de todo o seu coração e não se apoie em seu próprio entendimento." },
    { reference: "1 Coríntios 13:4", text: "O amor é paciente, o amor é bondoso. Não inveja, não se vangloria, não se orgulha." },
    { reference: "Jeremias 29:11", text: "Porque eu bem sei os planos que tenho para vocês, planos de paz e não de mal, para lhes dar esperança e um futuro." },
    { reference: "Salmos 37:4", text: "Deleite-se no Senhor, e ele atenderá aos desejos do seu coração." },
    { reference: "Filipenses 4:13", text: "Tudo posso naquele que me fortalece." },
    { reference: "Eclesiastes 4:9", text: "É melhor ter companhia do que estar sozinho, porque maior é a recompensa do trabalho de duas pessoas." },
    { reference: "Colossenses 3:14", text: "Acima de tudo, porém, revistam-se do amor, que é o elo perfeito." },
  ];
  return verses.length > 0 ? verses.map((v) => ({ reference: v.reference, text: v.text })) : fallback;
}

// GET /api/config/store — presentes ativos (o app não vende mais planos nem pacotes)
export async function publicStore(_req: Request, res: Response) {
  const gifts = await prisma.gift.findMany({
    where: { active: true },
    orderBy: { sortOrder: "asc" },
  });
  res.json({ gifts });
}

// GET /api/config/ads — config de anúncios (app lê em tempo real)
export async function publicAds(_req: Request, res: Response) {
  const ads = await prisma.adSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
  const on = ads.enabled;
  res.json({
    enabled: on,
    testMode: ads.testMode,
    testDeviceIds: (ads.testDeviceIds || "").split(",").map((s) => s.trim()).filter(Boolean),
    // Quais formatos estão ligados (independe de haver ID preenchido).
    formats: {
      appOpen: on && ads.appOpenEnabled,
      banner: on && ads.bannerEnabled,
      interstitial: on && ads.interstitialEnabled,
      rewarded: on && ads.rewardedEnabled,
      rewardedInterstitial: on && ads.rewardedInterstitialEnabled,
      native: on && ads.nativeEnabled,
    },
    units: {
      appOpen: on && ads.appOpenEnabled ? ads.androidAppOpenId : null,
      banner: on && ads.bannerEnabled ? ads.androidBannerId : null,
      interstitial: on && ads.interstitialEnabled ? ads.androidInterstitialId : null,
      rewarded: on && ads.rewardedEnabled ? ads.androidRewardedId : null,
      rewardedInterstitial: on && ads.rewardedInterstitialEnabled ? ads.androidRewardedInterstitialId : null,
      native: on && ads.nativeEnabled ? ads.androidNativeId : null,
    },
    banner: { position: ads.bannerPosition },
    appOpen: { onResume: ads.appOpenOnResume, everySecs: ads.appOpenEverySecs },
    interstitial: {
      everySecs: ads.interstitialEverySecs,
      everyClicks: ads.interstitialEveryClicks,
      onOpenChat: ads.interstitialOnOpenChat,
      onOpenProfile: ads.interstitialOnOpenProfile,
      onSwipe: ads.interstitialOnSwipe,
    },
    caps: { maxPerSession: ads.maxAdsPerSession, maxPerDay: ads.maxAdsPerDay },
  });
}
