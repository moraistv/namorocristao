import { Prisma, User } from "@prisma/client";
import { prisma } from "../config/prisma";

/** Limites de Super Like por dia. */
export const FREE_SUPERLIKES_PER_DAY = 1;
export const PREMIUM_SUPERLIKES_PER_DAY = 5;

/**
 * Durações do VIP concedido manualmente pelo painel (não há venda no app).
 * Os rótulos são exibidos no detalhe do usuário.
 */
export const PREMIUM_PLANS = {
  monthly: { days: 30, label: "Mensal" },
  quarterly: { days: 90, label: "Trimestral" },
  yearly: { days: 365, label: "Anual" },
} as const;

export type PremiumPlanId = keyof typeof PREMIUM_PLANS;

export function isPremiumPlanId(value: string): value is PremiumPlanId {
  return Object.prototype.hasOwnProperty.call(PREMIUM_PLANS, value);
}

/** True se o usuário tem premium ativo (flag e/ou dentro da validade). */
export function isPremiumActive(user: Pick<User, "isPremium" | "premiumUntil">): boolean {
  if (user.premiumUntil && user.premiumUntil.getTime() > Date.now()) return true;
  // Se tem flag mas sem data (modo dev), considera ativo.
  if (user.isPremium && !user.premiumUntil) return true;
  return false;
}

/**
 * Filtro de banco equivalente a `isPremiumActive`. A flag `isPremium` sozinha
 * não basta: ela continua ligada depois que a validade passa.
 */
export function premiumActiveWhere(now: Date = new Date()): Prisma.UserWhereInput {
  return {
    OR: [
      { premiumUntil: { gt: now } },
      { isPremium: true, premiumUntil: null },
    ],
  };
}

/**
 * Complemento exato de `premiumActiveWhere`. Não use `NOT premiumActiveWhere`:
 * no SQL, `premiumUntil > now` é NULL quando a data é nula e a linha some do
 * resultado (perderia todo mundo que nunca foi VIP).
 */
export function premiumInactiveWhere(now: Date = new Date()): Prisma.UserWhereInput {
  return {
    OR: [
      { premiumUntil: { lte: now } },
      { isPremium: false, premiumUntil: null },
    ],
  };
}

/** VIP sem validade (flag ligada sem data): não há horas a somar. */
export function isPermanentPremium(user: Pick<User, "isPremium" | "premiumUntil">): boolean {
  return user.isPremium && !user.premiumUntil;
}

/**
 * Se o usuário fica sem banner e intersticial. O VIP dado pela equipe sempre
 * fica; o ganho por anúncio (`premiumPlan = "ad"`) só quando o painel liga isso.
 */
export function isAdFree(
  user: Pick<User, "isPremium" | "premiumUntil" | "premiumPlan">,
  vipByAdHidesAds: boolean
): boolean {
  if (!isPremiumActive(user)) return false;
  return user.premiumPlan !== "ad" || vipByAdHidesAds;
}

/** Fuso dos limites diários: Brasília (UTC-3; sem horário de verão desde 2019). */
const DAY_OFFSET_MS = -3 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Início do "dia" dos limites diários (Super Like e recompensas): meia-noite de
 * Brasília, independente do fuso do servidor (o container roda em UTC).
 */
export function startOfToday(now: Date = new Date()): Date {
  const local = now.getTime() + DAY_OFFSET_MS;
  return new Date(Math.floor(local / DAY_MS) * DAY_MS - DAY_OFFSET_MS);
}

/**
 * Garante o reset diário do contador de super likes e devolve o usuário atualizado.
 */
export async function ensureDailyReset(userId: string): Promise<User> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new Error("Usuário não encontrado");
  const today = startOfToday();
  if (!user.superLikesResetAt || user.superLikesResetAt < today) {
    return prisma.user.update({
      where: { id: userId },
      data: { superLikesUsedToday: 0, superLikesResetAt: new Date() },
    });
  }
  return user;
}

/** Quantos Super Likes diários e extras (ganhos por anúncio) o usuário ainda possui. */
export function superLikesLeft(user: User): number {
  const perDay = isPremiumActive(user)
    ? PREMIUM_SUPERLIKES_PER_DAY
    : FREE_SUPERLIKES_PER_DAY;
  const dailyLeft = Math.max(0, perDay - user.superLikesUsedToday);
  return dailyLeft + Math.max(0, user.bonusSuperLikes);
}

/** Resumo do estado premium/limites do usuário (para o app). */
export function premiumStats(user: User) {
  const premium = isPremiumActive(user);
  const superLikesPerDay = premium
    ? PREMIUM_SUPERLIKES_PER_DAY
    : FREE_SUPERLIKES_PER_DAY;
  const dailySuperLikesLeft = Math.max(
    0,
    superLikesPerDay - user.superLikesUsedToday
  );
  return {
    isPremium: premium,
    premiumPlan: user.premiumPlan,
    premiumUntil: user.premiumUntil,
    superLikesPerDay,
    superLikesUsedToday: user.superLikesUsedToday,
    dailySuperLikesLeft,
    bonusSuperLikes: Math.max(0, user.bonusSuperLikes),
    superLikesLeft: dailySuperLikesLeft + Math.max(0, user.bonusSuperLikes),
    boostsRemaining: user.boostsRemaining,
    credits: user.credits,
  };
}
