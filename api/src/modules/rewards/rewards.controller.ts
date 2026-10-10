import { Prisma } from "@prisma/client";
import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { lockAdSettings } from "../../lib/adSettingsLock";
import { AppError } from "../../lib/errors";
import { emitToAll } from "../../sockets";
import {
  completeRewardClaim,
  getRewardStats,
  getRewardsOverview,
  grantRewardClaim,
  startRewardClaim,
} from "./rewards.service";
import { SsvKeysUnavailableError, verifySsvQuery } from "./ssv";
import {
  clearSsvRejection,
  lastSsvRejection,
  noteSsvRejection,
} from "./ssvDiagnostics";

const idSchema = z.string().uuid();

// ───────────────────────── App (usuário autenticado) ─────────────────────────

// GET /api/me/rewards — ofertas ativas + uso do dia
export async function listMyRewards(req: Request, res: Response) {
  res.json(await getRewardsOverview(req.userId!));
}

// POST /api/me/rewards/:rewardId/claims — reserva a recompensa antes do anúncio
export async function startMyReward(req: Request, res: Response) {
  const rewardId = idSchema.parse(req.params.rewardId);
  res.status(201).json(await startRewardClaim(req.userId!, rewardId));
}

// POST /api/me/rewards/claims/:claimId/complete — anúncio terminou / consulta o andamento
export async function completeMyReward(req: Request, res: Response) {
  const claimId = idSchema.parse(req.params.claimId);
  res.json(await completeRewardClaim(req.userId!, claimId));
}

// ───────────────────────── Callback SSV (chamado pelo Google) ─────────────────────────

let warnWindowStart = 0;
let warnCount = 0;

/** Registra recusas do SSV sem deixar chamadas públicas inundarem o log. */
function warnSsv(message: string) {
  const now = Date.now();
  if (now - warnWindowStart > 60_000) {
    warnWindowStart = now;
    warnCount = 0;
  }
  warnCount += 1;
  if (warnCount <= 5) console.warn(`Callback SSV recusado: ${message}`);
  else if (warnCount === 6) console.warn("Callback SSV: mais recusas omitidas neste minuto");
}

/** Registra a recusa no log (limitado) e guarda a última para o painel mostrar. */
function rejectSsv(reason: string, adUnit: string) {
  noteSsvRejection(reason, adUnit);
  warnSsv(adUnit ? `${reason} (ad_unit "${adUnit}")` : reason);
}

/**
 * Marca este callback como o "último" mostrado ao admin, base para conferir o
 * ad_unit e liberar a exigência do SSV. A condição vai no próprio UPDATE: se o
 * ad_unit esperado foi salvo no meio do caminho, o callback de outro bloco não
 * passa. Falha ao registrar não derruba a resposta ao Google.
 */
async function recordLastSsvCallback(adUnit: string) {
  try {
    await prisma.adSettings.updateMany({
      where: {
        id: 1,
        OR: [{ rewardsSsvAdUnit: null }, { rewardsSsvAdUnit: adUnit }],
      },
      data: {
        rewardsSsvLastAt: new Date(),
        rewardsSsvLastAdUnit: adUnit || null,
      },
    });
  } catch (error) {
    console.error("Falha ao registrar o último callback SSV:", error);
  }
}

// GET /api/ads/ssv — público; a autenticidade vem da assinatura do Google.
export async function ssvCallback(req: Request, res: Response) {
  const queryStart = req.originalUrl.indexOf("?");
  const rawQuery =
    queryStart === -1 ? "" : req.originalUrl.slice(queryStart + 1);

  let params: URLSearchParams;
  try {
    params = await verifySsvQuery(rawQuery);
  } catch (error) {
    if (error instanceof SsvKeysUnavailableError) {
      // 5xx: o Google tenta de novo.
      throw new AppError(error.message, 503, undefined, "SSV_KEYS_UNAVAILABLE");
    }
    warnSsv(error instanceof Error ? error.message : "erro desconhecido");
    throw new AppError("Callback inválido", 400, undefined, "SSV_INVALID");
  }

  const adUnit = (params.get("ad_unit") ?? "").slice(0, 120);
  const customData = params.get("custom_data") ?? "";
  const transactionId = params.get("transaction_id") ?? "";
  const callbackUserId = params.get("user_id");

  // Assinatura válida, mas sem relação com um resgate nosso (ex.: teste do
  // Google ao salvar a URL). Responde 200 para o Google não repetir.
  if (!idSchema.safeParse(customData).success || !transactionId) {
    rejectSsv("sem custom_data de resgate ou sem transaction_id", adUnit);
    return res.json({ ok: true });
  }

  // O Google assina callbacks de qualquer publisher com as mesmas chaves: com o
  // ad_unit esperado configurado, só vale (e só é registrado) o que veio do NOSSO bloco.
  const settings = await prisma.adSettings.findUnique({
    where: { id: 1 },
    select: { rewardsSsvAdUnit: true },
  });
  if (settings?.rewardsSsvAdUnit && settings.rewardsSsvAdUnit !== adUnit) {
    rejectSsv("ad_unit diferente do esperado", adUnit);
    return res.json({ ok: true });
  }

  const claim = await prisma.adRewardClaim.findUnique({
    where: { id: customData },
    select: { id: true, userId: true, expiresAt: true },
  });
  if (!claim) {
    rejectSsv("resgate não encontrado", adUnit);
    return res.json({ ok: true });
  }
  if (callbackUserId && callbackUserId !== claim.userId) {
    rejectSsv("user_id diferente do dono do resgate", adUnit);
    return res.json({ ok: true });
  }

  const outcome = await grantRewardClaim(claim.id, {
    verifiedBy: "ssv",
    transactionId: transactionId.slice(0, 128),
  });
  switch (outcome.result) {
    case "granted":
      // Só um callback que de fato pertence a um resgate nosso (e que não é um
      // resgate vencido ou um transaction_id repetido) vira "último callback".
      await recordLastSsvCallback(adUnit);
      break;
    case "already_granted":
      // O app pode confirmar antes do Google: esse SSV tardio vale como último
      // callback. Uma URL assinada repetida muito depois não (sem crédito em
      // dobro de qualquer forma): só conta dentro do prazo do resgate.
      if (claim.expiresAt.getTime() > Date.now()) {
        await recordLastSsvCallback(adUnit);
      } else {
        warnSsv("callback repetido de um resgate antigo (não conta como último callback)");
      }
      break;
    // Rastro das perdas reais (callback tardio, resgate vencido, repetição de
    // transaction_id) para decidir, com dados, se o prazo de 10 min precisa mudar.
    case "expired":
      rejectSsv("resgate vencido ou substituído (sem crédito)", adUnit);
      break;
    case "duplicate_transaction":
      rejectSsv("transaction_id repetido em outro resgate", adUnit);
      break;
    case "not_found":
      rejectSsv("resgate não encontrado", adUnit);
      break;
  }
  res.json({ ok: true });
}

// ───────────────────────── Painel (super-admin) ─────────────────────────

const rewardSchema = z.object({
  kind: z.enum(["SUPERLIKES", "BOOSTS", "CREDITS"]),
  title: z.string().trim().min(1).max(80),
  description: z.string().trim().max(200).optional().nullable(),
  amount: z.number().int().min(1).max(100),
  dailyLimit: z.number().int().min(0).max(100),
  cooldownSecs: z.number().int().min(0).max(3600),
  active: z.boolean().default(true),
  sortOrder: z.number().int().min(-1000).max(1000).default(0),
});

const settingsSchema = z.object({
  rewardsRequireSsv: z.boolean(),
  rewardsMaxPerDay: z.number().int().min(0).max(1000),
  rewardsSsvAdUnit: z.string().trim().max(120).optional().nullable(),
});

function notifyStoreChanged() {
  // O app recarrega a tela de recompensas quando as ofertas mudam.
  emitToAll("config:store", { changed: true });
}

async function requireReward(id: string) {
  const reward = await prisma.adReward.findUnique({ where: { id } });
  if (!reward) throw new AppError("Recompensa não encontrada", 404);
  return reward;
}

function settingsView(ads: {
  rewardsRequireSsv: boolean;
  rewardsMaxPerDay: number;
  rewardsSsvAdUnit: string | null;
  rewardsSsvLastAt: Date | null;
  rewardsSsvLastAdUnit: string | null;
}) {
  return {
    rewardsRequireSsv: ads.rewardsRequireSsv,
    rewardsMaxPerDay: ads.rewardsMaxPerDay,
    rewardsSsvAdUnit: ads.rewardsSsvAdUnit,
    ssvLastAt: ads.rewardsSsvLastAt,
    ssvLastAdUnit: ads.rewardsSsvLastAdUnit,
    // Só em memória: vale desde o último reinício da API.
    ssvLastRejected: lastSsvRejection(),
  };
}

// GET /api/admin/rewards — ofertas, configuração, estado dos anúncios e números
export async function adminOverview(_req: Request, res: Response) {
  const [ads, rewards, stats] = await Promise.all([
    prisma.adSettings.upsert({
      where: { id: 1 },
      create: { id: 1 },
      update: {},
    }),
    prisma.adReward.findMany({
      orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    }),
    getRewardStats(),
  ]);
  res.json({
    rewards,
    settings: settingsView(ads),
    ads: {
      enabled: ads.enabled,
      rewardedEnabled: ads.rewardedEnabled,
      testMode: ads.testMode,
      hasRewardedUnit: Boolean(ads.androidRewardedId?.trim()),
    },
    stats,
  });
}

// POST /api/admin/rewards
export async function createReward(req: Request, res: Response) {
  const data = rewardSchema.parse(req.body);
  const reward = await prisma.adReward.create({ data });
  notifyStoreChanged();
  res.status(201).json({ reward });
}

// PUT /api/admin/rewards/:id
export async function updateReward(req: Request, res: Response) {
  const id = idSchema.parse(req.params.id);
  const data = rewardSchema.partial().parse(req.body);
  await requireReward(id);
  const reward = await prisma.adReward.update({ where: { id }, data });
  notifyStoreChanged();
  res.json({ reward });
}

// DELETE /api/admin/rewards/:id — só ofertas sem resgates; as demais devem ser desativadas
export async function deleteReward(req: Request, res: Response) {
  const id = idSchema.parse(req.params.id);
  await requireReward(id);
  const hasClaims = new AppError(
    "Esta recompensa já tem resgates registrados. Desative-a em vez de excluir.",
    409,
    undefined,
    "REWARD_HAS_CLAIMS"
  );
  if ((await prisma.adRewardClaim.count({ where: { rewardId: id } })) > 0) {
    throw hasClaims;
  }
  try {
    await prisma.adReward.delete({ where: { id } });
  } catch (error) {
    // Um resgate pode ter sido criado entre a checagem e a exclusão.
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2003"
    ) {
      throw hasClaims;
    }
    throw error;
  }
  notifyStoreChanged();
  res.json({ ok: true });
}

// PUT /api/admin/reward-settings
export async function updateRewardSettings(req: Request, res: Response) {
  const input = settingsSchema.parse(req.body);

  // Lê, decide e grava com a linha travada: o PUT de Anúncios decide com base
  // nos mesmos campos (bloco Premiado) e não pode correr junto com este.
  const { ads, expectedChanged } = await prisma.$transaction(async (tx) => {
    const current = await lockAdSettings(tx);

    const adUnit =
      input.rewardsSsvAdUnit === undefined
        ? current.rewardsSsvAdUnit
        : input.rewardsSsvAdUnit || null;

    // Exigir o Google com o SSV mal configurado zera (ou abre) as recompensas de
    // todos, então a exigência só vale com um ad_unit esperado que já foi visto
    // num callback aceito de um resgate nosso.
    if (input.rewardsRequireSsv) {
      const enabling = !current.rewardsRequireSsv;
      const missing: string[] = [];
      if (enabling) {
        if (current.testMode) missing.push("desligue o Modo teste em Anúncios");
        if (!current.enabled || !current.rewardedEnabled) {
          missing.push("ligue os anúncios e o formato Premiado em Anúncios");
        }
        if (!current.androidRewardedId?.trim()) {
          missing.push("informe o ID do bloco Premiado em Anúncios");
        }
        if (!current.rewardsSsvLastAt) {
          missing.push(
            "receba um callback do Google (assista a um anúncio premiado no app com a URL configurada)"
          );
        }
      }
      if (!adUnit) {
        missing.push("informe o ad_unit esperado");
      } else if (
        (enabling || adUnit !== current.rewardsSsvAdUnit) &&
        adUnit !== current.rewardsSsvLastAdUnit
      ) {
        // Ligando, ou trocando o esperado com a exigência já ligada: precisa
        // ser exatamente o ad_unit do último callback recebido (evita erro de digitação).
        missing.push(
          "o ad_unit esperado precisa ser igual ao do último callback recebido do Google"
        );
      }
      if (missing.length > 0) {
        throw new AppError(
          `Não dá para exigir a confirmação do Google: ${missing.join("; ")}.`,
          409,
          { missing },
          "SSV_NOT_READY"
        );
      }
    }

    const saved = await tx.adSettings.update({
      where: { id: 1 },
      data: {
        rewardsRequireSsv: input.rewardsRequireSsv,
        rewardsMaxPerDay: input.rewardsMaxPerDay,
        rewardsSsvAdUnit: adUnit,
      },
    });
    return {
      ads: saved,
      expectedChanged: adUnit !== current.rewardsSsvAdUnit,
    };
  });
  // Trocar o ad_unit esperado muda o que conta como recusa: a anterior já não vale.
  if (expectedChanged) clearSsvRejection();
  res.json({ settings: settingsView(ads) });
}
