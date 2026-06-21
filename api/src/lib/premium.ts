import { User } from "@prisma/client";
import { prisma } from "../config/prisma";

/** Limites de Super Like por dia. */
export const FREE_SUPERLIKES_PER_DAY = 1;
export const PREMIUM_SUPERLIKES_PER_DAY = 5;

/** Planos VIP disponíveis (duração em dias + rótulos/preços de exibição). */
export const PREMIUM_PLANS: Record<
  string,
  { days: number; label: string; price: string; monthly: string }
> = {
  monthly: { days: 30, label: "1 mês", price: "R$ 39,90", monthly: "R$ 39,90/mês" },
  quarterly: {
    days: 90,
    label: "3 meses",
    price: "R$ 89,90",
    monthly: "R$ 29,97/mês",
  },
  yearly: {
    days: 365,
    label: "12 meses",
    price: "R$ 239,90",
    monthly: "R$ 19,99/mês",
  },
};

/** True se o usuário tem premium ativo (flag e/ou dentro da validade). */
export function isPremiumActive(user: Pick<User, "isPremium" | "premiumUntil">): boolean {
  if (user.premiumUntil && user.premiumUntil.getTime() > Date.now()) return true;
  // Se tem flag mas sem data (modo dev), considera ativo.
  if (user.isPremium && !user.premiumUntil) return true;
  return false;
}

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
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

/** Quantos super likes o usuário ainda tem hoje. */
export function superLikesLeft(user: User): number {
  const perDay = isPremiumActive(user)
    ? PREMIUM_SUPERLIKES_PER_DAY
    : FREE_SUPERLIKES_PER_DAY;
  return Math.max(0, perDay - user.superLikesUsedToday);
}

/** Resumo do estado premium/limites do usuário (para o app). */
export function premiumStats(user: User) {
  const premium = isPremiumActive(user);
  return {
    isPremium: premium,
    premiumPlan: user.premiumPlan,
    premiumUntil: user.premiumUntil,
    superLikesPerDay: premium
      ? PREMIUM_SUPERLIKES_PER_DAY
      : FREE_SUPERLIKES_PER_DAY,
    superLikesUsedToday: user.superLikesUsedToday,
    superLikesLeft: superLikesLeft(user),
    boostsRemaining: user.boostsRemaining,
    credits: user.credits,
  };
}
