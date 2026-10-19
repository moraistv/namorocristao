import {
  Prisma,
  type AdReward,
  type AdRewardClaim,
  type AdSettings,
  type RewardKind,
} from "@prisma/client";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { isAdFree, isPermanentPremium, startOfToday } from "../../lib/premium";
import { retryBackoff } from "../../lib/retry";
import { emitToUser } from "../../sockets";

/** Tempo para o usuário assistir e a recompensa ser confirmada. */
export const CLAIM_TTL_MS = 10 * 60 * 1000;
/** Sem SSV, ignora confirmações do app mais rápidas que isso (anúncio real dura mais). */
const CLIENT_MIN_WATCH_MS = 5000;
/** Maior espera entre anúncios aceita no painel; define a janela de consulta. */
const COOLDOWN_LOOKBACK_MS = 60 * 60 * 1000;
/** Tentativas ao iniciar um resgate quando a transação Serializable colide. */
const START_CLAIM_ATTEMPTS = 5;
/** Resgates não concluídos mais antigos que isso são apagados. */
const STALE_CLAIM_MS = 7 * 24 * 60 * 60 * 1000;
const CLEANUP_EVERY_MS = 60 * 60 * 1000;

type ClaimStatus = "PENDING" | "GRANTED" | "EXPIRED";
type BlockReason = "LIMIT" | "DAILY_CAP" | "COOLDOWN";
/** Ofertas de VIP ficam bloqueadas para quem já tem VIP sem validade. */
type OfferBlock = BlockReason | "ALREADY_VIP";

function transactionErrorCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null || !("code" in error)) {
    return undefined;
  }
  return typeof error.code === "string" ? error.code : undefined;
}

type RewardAdSettings = Pick<
  AdSettings,
  | "enabled"
  | "rewardedEnabled"
  | "testMode"
  | "androidRewardedId"
  | "rewardsRequireSsv"
>;

/**
 * Recompensas só funcionam com anúncios ligados, formato Premiado ativo e um
 * bloco utilizável: o ID salvo ou, no Modo teste, o bloco de demonstração.
 * É a mesma regra que o app aplica (`AdsService.rewardedAvailable`).
 */
export function rewardsEnabled(ads: RewardAdSettings): boolean {
  return (
    ads.enabled &&
    ads.rewardedEnabled &&
    (ads.testMode || Boolean(ads.androidRewardedId?.trim()))
  );
}

/**
 * Se a concessão depende do callback do Google. No Modo teste o app usa o
 * bloco de demonstração, que nunca chama a nossa URL, então não há como exigir.
 */
export function requiresSsv(ads: RewardAdSettings): boolean {
  return ads.rewardsRequireSsv && !ads.testMode;
}

/**
 * Configuração de anúncios (linha única). Cria a linha se ainda não existir,
 * tolerando chamadas simultâneas na primeira vez (o upsert do Prisma pode
 * falhar com violação de unicidade nessa corrida).
 */
async function loadAdSettings(): Promise<AdSettings> {
  const existing = await prisma.adSettings.findUnique({ where: { id: 1 } });
  if (existing) return existing;
  try {
    return await prisma.adSettings.create({ data: { id: 1 } });
  } catch (error) {
    if (transactionErrorCode(error) !== "P2002") throw error;
    return prisma.adSettings.findUniqueOrThrow({ where: { id: 1 } });
  }
}

interface Usage {
  totalToday: number;
  byReward: Map<string, { usedToday: number; lastGrantedAt: number | null }>;
}

function buildUsage(
  grants: Array<{ rewardId: string; grantedAt: Date | null }>,
  dayStart: Date
): Usage {
  const byReward: Usage["byReward"] = new Map();
  let totalToday = 0;
  for (const grant of grants) {
    if (!grant.grantedAt) continue;
    const entry = byReward.get(grant.rewardId) ?? {
      usedToday: 0,
      lastGrantedAt: null,
    };
    if (grant.grantedAt >= dayStart) {
      entry.usedToday += 1;
      totalToday += 1;
    }
    const grantedMs = grant.grantedAt.getTime();
    if (entry.lastGrantedAt === null || grantedMs > entry.lastGrantedAt) {
      entry.lastGrantedAt = grantedMs;
    }
    byReward.set(grant.rewardId, entry);
  }
  return { totalToday, byReward };
}

function evaluateOffer(
  offer: Pick<AdReward, "id" | "dailyLimit" | "cooldownSecs">,
  ads: Pick<AdSettings, "rewardsMaxPerDay">,
  usage: Usage,
  nowMs: number
) {
  const entry = usage.byReward.get(offer.id);
  const usedToday = entry?.usedToday ?? 0;
  const remainingToday =
    offer.dailyLimit > 0 ? Math.max(0, offer.dailyLimit - usedToday) : null;
  const cooldownLeftSecs =
    entry?.lastGrantedAt != null && offer.cooldownSecs > 0
      ? Math.max(
          0,
          Math.ceil(
            (entry.lastGrantedAt + offer.cooldownSecs * 1000 - nowMs) / 1000
          )
        )
      : 0;
  const capReached =
    ads.rewardsMaxPerDay > 0 && usage.totalToday >= ads.rewardsMaxPerDay;

  let blockedBy: BlockReason | null = null;
  if (remainingToday === 0) blockedBy = "LIMIT";
  else if (capReached) blockedBy = "DAILY_CAP";
  else if (cooldownLeftSecs > 0) blockedBy = "COOLDOWN";

  return { usedToday, remainingToday, cooldownLeftSecs, blockedBy };
}

function usageWindowStart(dayStart: Date, nowMs: number): Date {
  return new Date(Math.min(dayStart.getTime(), nowMs - COOLDOWN_LOOKBACK_MS));
}

/** Ofertas ativas com o estado de uso do usuário (limite, espera, disponível). */
export async function getRewardsOverview(userId: string) {
  const nowMs = Date.now();
  const dayStart = startOfToday();
  const [ads, offers, grants, viewer] = await Promise.all([
    loadAdSettings(),
    prisma.adReward.findMany({
      where: { active: true },
      orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    }),
    prisma.adRewardClaim.findMany({
      where: {
        userId,
        status: "GRANTED",
        grantedAt: { gte: usageWindowStart(dayStart, nowMs) },
      },
      select: { rewardId: true, grantedAt: true },
    }),
    prisma.user.findUnique({
      where: { id: userId },
      select: { isPremium: true, premiumUntil: true },
    }),
  ]);

  const enabled = rewardsEnabled(ads);
  const usage = buildUsage(grants, dayStart);
  const permanentVip = viewer ? isPermanentPremium(viewer) : false;

  return {
    enabled,
    requireSsv: requiresSsv(ads),
    dailyCap: {
      limit: ads.rewardsMaxPerDay,
      used: usage.totalToday,
    },
    rewards: offers.map((offer) => {
      const evaluated = evaluateOffer(offer, ads, usage, nowMs);
      const blockedBy: OfferBlock | null =
        offer.kind === "VIP" && permanentVip
          ? "ALREADY_VIP"
          : evaluated.blockedBy;
      const state = { ...evaluated, blockedBy };
      return {
        id: offer.id,
        kind: offer.kind,
        title: offer.title,
        description: offer.description,
        amount: offer.amount,
        dailyLimit: offer.dailyLimit,
        usedToday: state.usedToday,
        remainingToday: state.remainingToday,
        cooldownSecs: offer.cooldownSecs,
        cooldownLeftSecs: state.cooldownLeftSecs,
        blockedBy: state.blockedBy,
        available: enabled && state.blockedBy === null,
      };
    }),
  };
}

function limitError(reason: BlockReason, cooldownLeftSecs: number): AppError {
  if (reason === "COOLDOWN") {
    return new AppError(
      `Aguarde ${cooldownLeftSecs}s para assistir outro anúncio desta recompensa.`,
      429,
      { retryAfterSecs: cooldownLeftSecs },
      "REWARD_COOLDOWN"
    );
  }
  if (reason === "DAILY_CAP") {
    return new AppError(
      "Você atingiu o limite diário de recompensas. Volte amanhã!",
      429,
      undefined,
      "REWARD_DAILY_CAP"
    );
  }
  return new AppError(
    "Você já usou todos os anúncios desta recompensa hoje. Volte amanhã!",
    429,
    undefined,
    "REWARD_LIMIT"
  );
}

/**
 * Reserva uma recompensa antes de o anúncio ser exibido. Um usuário só tem um
 * resgate em andamento: iniciar outro expira o anterior. Só resgates já
 * concedidos contam para os limites.
 */
export async function startRewardClaim(userId: string, rewardId: string) {
  const conflict = () =>
    new AppError(
      "Não foi possível iniciar o anúncio agora. Tente novamente.",
      409,
      undefined,
      "REWARD_CONFLICT"
    );

  for (let attempt = 0; attempt < START_CLAIM_ATTEMPTS; attempt += 1) {
    try {
      const result = await prisma.$transaction(
        async (tx) => {
          const ads = await tx.adSettings.findUnique({ where: { id: 1 } });
          if (!ads || !rewardsEnabled(ads)) {
            throw new AppError(
              "As recompensas por anúncio estão indisponíveis no momento.",
              403,
              undefined,
              "REWARDS_UNAVAILABLE"
            );
          }

          const offer = await tx.adReward.findUnique({
            where: { id: rewardId },
          });
          if (!offer || !offer.active) {
            throw new AppError(
              "Recompensa indisponível.",
              404,
              undefined,
              "REWARD_NOT_FOUND"
            );
          }
          if (offer.kind === "VIP") {
            const viewer = await tx.user.findUnique({
              where: { id: userId },
              select: { isPremium: true, premiumUntil: true },
            });
            // VIP sem validade não tem horas a somar: o anúncio seria em vão.
            if (viewer && isPermanentPremium(viewer)) {
              throw new AppError(
                "Você já é VIP sem prazo de validade.",
                409,
                undefined,
                "ALREADY_VIP"
              );
            }
          }

          const now = new Date();
          const dayStart = startOfToday();
          const grants = await tx.adRewardClaim.findMany({
            where: {
              userId,
              status: "GRANTED",
              grantedAt: {
                gte: usageWindowStart(dayStart, now.getTime()),
              },
            },
            select: { rewardId: true, grantedAt: true },
          });
          const state = evaluateOffer(
            offer,
            ads,
            buildUsage(grants, dayStart),
            now.getTime()
          );
          if (state.blockedBy) {
            throw limitError(state.blockedBy, state.cooldownLeftSecs);
          }

          await tx.adRewardClaim.updateMany({
            where: { userId, status: "PENDING" },
            data: { status: "EXPIRED" },
          });
          const claim = await tx.adRewardClaim.create({
            data: {
              userId,
              rewardId: offer.id,
              kind: offer.kind,
              amount: offer.amount,
              expiresAt: new Date(now.getTime() + CLAIM_TTL_MS),
            },
          });

          return {
            claimId: claim.id,
            expiresAt: claim.expiresAt,
            reward: {
              id: offer.id,
              kind: offer.kind,
              title: offer.title,
              amount: offer.amount,
            },
            // Repassados ao SDK de anúncios para voltarem no callback SSV.
            ssv: { userId, customData: claim.id },
          };
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
      );
      cleanupStaleClaims();
      return result;
    } catch (error) {
      if (transactionErrorCode(error) !== "P2034") throw error;
      if (attempt === START_CLAIM_ATTEMPTS - 1) {
        // O conflito é esperado em picos; o esgotamento precisa deixar rastro.
        console.warn(
          `Resgate: ${START_CLAIM_ATTEMPTS} tentativas esgotadas por conflito de transação (usuário ${userId})`
        );
        throw conflict();
      }
      await retryBackoff(attempt);
    }
  }
  throw conflict();
}

const HOUR_MS = 60 * 60 * 1000;

/** Efeito visível da recompensa, para avisar o app na hora. */
interface RewardEffect {
  vip?: { premiumUntil: Date | null; premiumPlan: string | null };
}

/**
 * Soma horas de VIP: parte do fim do VIP atual (se ainda vale) ou de agora.
 * VIP sem validade (flag sem data) fica como está. A gravação só acontece se a
 * validade lida não mudou no meio do caminho (ex.: VIP dado pelo painel).
 */
async function extendVip(
  tx: Prisma.TransactionClient,
  userId: string,
  hours: number,
  now: Date
): Promise<RewardEffect> {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const user = await tx.user.findUniqueOrThrow({
      where: { id: userId },
      select: { isPremium: true, premiumUntil: true, premiumPlan: true },
    });
    if (isPermanentPremium(user)) {
      return { vip: { premiumUntil: null, premiumPlan: user.premiumPlan } };
    }
    const active =
      user.premiumUntil !== null && user.premiumUntil.getTime() > now.getTime();
    const base = active ? user.premiumUntil!.getTime() : now.getTime();
    const premiumUntil = new Date(base + hours * HOUR_MS);
    // "ad" marca no painel que o VIP veio de anúncio (sem apagar o plano dado pela equipe).
    const premiumPlan = active ? user.premiumPlan : "ad";
    const updated = await tx.user.updateMany({
      where: { id: userId, premiumUntil: user.premiumUntil },
      data: { premiumUntil, premiumPlan },
    });
    if (updated.count === 1) return { vip: { premiumUntil, premiumPlan } };
  }
  throw new Error("Não foi possível somar as horas de VIP");
}

/** Credita a recompensa ao usuário, dentro da transação da concessão. */
async function applyReward(
  tx: Prisma.TransactionClient,
  claim: Pick<AdRewardClaim, "userId" | "kind" | "amount">,
  now: Date
): Promise<RewardEffect> {
  const where = { id: claim.userId };
  switch (claim.kind) {
    case "SUPERLIKES":
      await tx.user.update({
        where,
        data: { bonusSuperLikes: { increment: claim.amount } },
      });
      return {};
    case "BOOSTS":
      await tx.user.update({
        where,
        data: { boostsRemaining: { increment: claim.amount } },
      });
      return {};
    case "CREDITS":
      await tx.user.update({
        where,
        data: { credits: { increment: claim.amount } },
      });
      return {};
    case "VIP":
      return extendVip(tx, claim.userId, claim.amount, now);
  }
}

export type GrantOutcome =
  | { result: "granted"; claim: AdRewardClaim }
  | { result: "already_granted"; claim: AdRewardClaim }
  | { result: "expired"; claim: AdRewardClaim }
  | { result: "duplicate_transaction" }
  | { result: "not_found" };

/**
 * Credita o resgate uma única vez. A troca PENDING→GRANTED é atômica e o saldo
 * só é alterado se essa troca acontecer, então SSV e confirmação do app podem
 * chegar juntos, repetidos ou fora de ordem sem conceder em dobro.
 */
export async function grantRewardClaim(
  claimId: string,
  options: { verifiedBy: "ssv" | "client"; transactionId?: string }
): Promise<GrantOutcome> {
  const now = new Date();
  try {
    const granted = await prisma.$transaction(async (tx) => {
      const updated = await tx.adRewardClaim.updateMany({
        where: { id: claimId, status: "PENDING", expiresAt: { gt: now } },
        data: {
          status: "GRANTED",
          grantedAt: now,
          verifiedBy: options.verifiedBy,
          transactionId: options.transactionId ?? null,
        },
      });
      if (updated.count !== 1) return null;

      const claim = await tx.adRewardClaim.findUniqueOrThrow({
        where: { id: claimId },
      });
      const effect = await applyReward(tx, claim, now);
      return { claim, effect };
    });

    if (granted) {
      const { claim, effect } = granted;
      let vipState = {};
      if (effect.vip) {
        // VIP muda na hora as travas do app e, conforme o painel, os anúncios.
        const ads = await loadAdSettings();
        vipState = {
          isPremium: true,
          premiumUntil: effect.vip.premiumUntil,
          adFree: isAdFree(
            {
              isPremium: true,
              premiumUntil: effect.vip.premiumUntil,
              premiumPlan: effect.vip.premiumPlan,
            },
            ads.rewardsVipHidesAds
          ),
        };
      }
      emitToUser(claim.userId, "config:me", {
        rewardGranted: { kind: claim.kind, amount: claim.amount },
        ...vipState,
      });
      return { result: "granted", claim };
    }
  } catch (error) {
    // transaction_id já usado em outro resgate: replay do callback.
    if (transactionErrorCode(error) === "P2002") {
      return { result: "duplicate_transaction" };
    }
    throw error;
  }

  const current = await prisma.adRewardClaim.findUnique({
    where: { id: claimId },
  });
  if (!current) return { result: "not_found" };
  if (current.status === "GRANTED") {
    return { result: "already_granted", claim: current };
  }
  return { result: "expired", claim: current };
}

function claimResult(
  claim: Pick<AdRewardClaim, "kind" | "amount">,
  status: ClaimStatus
) {
  return { status, kind: claim.kind, amount: claim.amount };
}

/**
 * O app avisa que o anúncio terminou. Com SSV obrigatório apenas informa o
 * estado atual (o crédito vem do Google); sem SSV o app é a confirmação.
 * Chamar de novo é seguro e serve para consultar o andamento.
 */
export async function completeRewardClaim(userId: string, claimId: string) {
  const claim = await prisma.adRewardClaim.findFirst({
    where: { id: claimId, userId },
  });
  if (!claim) {
    throw new AppError(
      "Recompensa não encontrada.",
      404,
      undefined,
      "REWARD_CLAIM_NOT_FOUND"
    );
  }
  if (claim.status === "GRANTED") return claimResult(claim, "GRANTED");

  const nowMs = Date.now();
  if (claim.status === "EXPIRED" || claim.expiresAt.getTime() <= nowMs) {
    if (claim.status === "PENDING") {
      await prisma.adRewardClaim.updateMany({
        where: { id: claim.id, status: "PENDING" },
        data: { status: "EXPIRED" },
      });
    }
    return claimResult(claim, "EXPIRED");
  }

  const ads = await loadAdSettings();
  if (requiresSsv(ads)) return claimResult(claim, "PENDING");
  if (nowMs - claim.createdAt.getTime() < CLIENT_MIN_WATCH_MS) {
    return claimResult(claim, "PENDING");
  }

  const outcome = await grantRewardClaim(claim.id, { verifiedBy: "client" });
  switch (outcome.result) {
    case "granted":
    case "already_granted":
      return claimResult(outcome.claim, "GRANTED");
    case "expired":
      return claimResult(outcome.claim, "EXPIRED");
    default:
      return claimResult(claim, "EXPIRED");
  }
}

let lastCleanupAt = 0;

/** Apaga, no máximo 1x por hora, resgates antigos que nunca foram concedidos. */
function cleanupStaleClaims(): void {
  const nowMs = Date.now();
  if (nowMs - lastCleanupAt < CLEANUP_EVERY_MS) return;
  lastCleanupAt = nowMs;
  void prisma.adRewardClaim
    .deleteMany({
      where: {
        status: { in: ["PENDING", "EXPIRED"] },
        createdAt: { lt: new Date(nowMs - STALE_CLAIM_MS) },
      },
    })
    .catch((error) => {
      console.error("Falha ao limpar resgates antigos:", error);
    });
}

/** Números para o painel: concedidos hoje (por tipo), na semana e no total. */
export async function getRewardStats() {
  const nowMs = Date.now();
  const dayStart = startOfToday();
  const weekStart = new Date(nowMs - 7 * 24 * 60 * 60 * 1000);

  const [today, week, total, inProgress] = await Promise.all([
    prisma.adRewardClaim.groupBy({
      by: ["kind"],
      where: { status: "GRANTED", grantedAt: { gte: dayStart } },
      _count: { _all: true },
      _sum: { amount: true },
    }),
    prisma.adRewardClaim.count({
      where: { status: "GRANTED", grantedAt: { gte: weekStart } },
    }),
    prisma.adRewardClaim.count({ where: { status: "GRANTED" } }),
    prisma.adRewardClaim.count({
      where: { status: "PENDING", expiresAt: { gt: new Date(nowMs) } },
    }),
  ]);

  const byKind = (kind: RewardKind) => {
    const row = today.find((item) => item.kind === kind);
    return { count: row?._count._all ?? 0, units: row?._sum.amount ?? 0 };
  };

  return {
    grantedToday: {
      SUPERLIKES: byKind("SUPERLIKES"),
      BOOSTS: byKind("BOOSTS"),
      CREDITS: byKind("CREDITS"),
      VIP: byKind("VIP"),
    },
    grantedWeek: week,
    grantedTotal: total,
    inProgress,
  };
}
