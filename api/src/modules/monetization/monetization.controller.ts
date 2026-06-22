import { Request, Response } from "express";
import { randomUUID } from "crypto";
import fs from "fs";
import path from "path";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { UPLOADS_DIR } from "../../config/paths";
import { emitToAll } from "../../sockets";

// ───────────────────────── Produtos (planos / pacotes) ─────────────────────────

const productSchema = z.object({
  kind: z.enum(["PREMIUM", "CREDITS", "SUPERLIKES", "BOOSTS"]),
  title: z.string().min(1),
  description: z.string().optional().nullable(),
  googleProductId: z.string().optional().nullable(),
  priceCents: z.number().int().min(0).default(0),
  amount: z.number().int().min(0).default(0),
  durationDays: z.number().int().min(0).optional().nullable(),
  active: z.boolean().default(true),
  sortOrder: z.number().int().default(0),
});

// GET /api/admin/products
export async function listProducts(_req: Request, res: Response) {
  const products = await prisma.product.findMany({
    orderBy: [{ kind: "asc" }, { sortOrder: "asc" }, { priceCents: "asc" }],
  });
  res.json({ products });
}

// POST /api/admin/products
export async function createProduct(req: Request, res: Response) {
  const data = productSchema.parse(req.body);
  const product = await prisma.product.create({ data });
  emitToAll("config:store", { changed: true });
  res.status(201).json({ product });
}

// PUT /api/admin/products/:id
export async function updateProduct(req: Request, res: Response) {
  const data = productSchema.partial().parse(req.body);
  const product = await prisma.product.update({ where: { id: req.params.id }, data });
  emitToAll("config:store", { changed: true });
  res.json({ product });
}

// DELETE /api/admin/products/:id
export async function deleteProduct(req: Request, res: Response) {
  await prisma.product.delete({ where: { id: req.params.id } });
  emitToAll("config:store", { changed: true });
  res.json({ ok: true });
}

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

// ───────────────────────── Config de monetização (valor do crédito) ─────────────────────────

const monetizationSchema = z.object({
  creditPriceCents: z.number().int().min(1),
  currency: z.string().min(1).default("BRL"),
});

// GET /api/admin/monetization
export async function getMonetization(_req: Request, res: Response) {
  const settings = await prisma.monetizationSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
  res.json({ settings });
}

// PUT /api/admin/monetization
export async function updateMonetization(req: Request, res: Response) {
  const data = monetizationSchema.parse(req.body);
  const settings = await prisma.monetizationSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...data },
    update: data,
  });
  emitToAll("config:store", { changed: true });
  res.json({ settings });
}

// ───────────────────────── Anúncios (AdMob) ─────────────────────────

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

  androidAppOpenId: z.string().optional().nullable(),
  androidBannerId: z.string().optional().nullable(),
  androidInterstitialId: z.string().optional().nullable(),
  androidRewardedId: z.string().optional().nullable(),
  androidRewardedInterstitialId: z.string().optional().nullable(),
  androidNativeId: z.string().optional().nullable(),

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
  const ads = await prisma.adSettings.upsert({ where: { id: 1 }, create: { id: 1, ...data }, update: data });
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

// GET /api/config/store — planos, pacotes, presentes e valor do crédito (ativos)
export async function publicStore(_req: Request, res: Response) {
  const [products, gifts, monetization] = await Promise.all([
    prisma.product.findMany({ where: { active: true }, orderBy: [{ kind: "asc" }, { sortOrder: "asc" }] }),
    prisma.gift.findMany({ where: { active: true }, orderBy: { sortOrder: "asc" } }),
    prisma.monetizationSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} }),
  ]);
  res.json({ products, gifts, creditPriceCents: monetization.creditPriceCents, currency: monetization.currency });
}

// GET /api/config/ads — config de anúncios (app lê em tempo real)
export async function publicAds(_req: Request, res: Response) {
  const ads = await prisma.adSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
  const on = ads.enabled;
  res.json({
    enabled: on,
    testMode: ads.testMode,
    testDeviceIds: (ads.testDeviceIds || "").split(",").map((s) => s.trim()).filter(Boolean),
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
