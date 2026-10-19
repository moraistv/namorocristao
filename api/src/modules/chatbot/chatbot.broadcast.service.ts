import {
  BotBroadcast,
  BotBroadcastRecipientStatus,
  BotBroadcastStatus,
  Prisma,
} from "@prisma/client";
import { createHash, randomUUID } from "crypto";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { premiumInactiveWhere } from "../../lib/premium";
import { onlineCutoff } from "../../lib/presence";
import { pushOnly } from "../../lib/push";
import { emitToUser } from "../../sockets";

export const BROADCAST_AUDIENCES = ["all", "free", "premium", "online"] as const;
export type BroadcastAudience = (typeof BROADCAST_AUDIENCES)[number];

export interface BroadcastInput {
  botId: string;
  botName: string;
  audience: BroadcastAudience;
  text?: string;
  imageUrl?: string;
  limit?: number;
  idempotencyKey: string;
}

interface ClaimedBroadcast {
  broadcast: BotBroadcast;
  leaseToken: string;
}

interface RecipientProgress {
  targeted: number;
  sent: number;
  skipped: number;
  failed: number;
  pending: number;
  processing: number;
}

const BROADCAST_LEASE_MS = 30_000;
const RECIPIENT_LEASE_MS = 30_000;
const PROGRESS_RECONCILE_INTERVAL = 10;
const IDEMPOTENCY_CONFLICT_CODE = "BOT_BROADCAST_IDEMPOTENCY_CONFLICT";

function leaseDeadline(durationMs: number): Date {
  return new Date(Date.now() + durationMs);
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message) return error.message.slice(0, 1000);
  return "Falha inesperada durante o broadcast";
}

function leaseLostError(): Error & { code: string } {
  const error = new Error("Lease do broadcast não pertence mais a esta execução") as Error & {
    code: string;
  };
  error.code = "BOT_BROADCAST_LEASE_LOST";
  return error;
}

function canonicalRequest(input: BroadcastInput, limit: number): string {
  return JSON.stringify([
    input.botId,
    input.audience,
    input.text ?? null,
    input.imageUrl ?? null,
    limit,
  ]);
}

function requestHash(input: BroadcastInput, limit: number): string {
  return createHash("sha256").update(canonicalRequest(input, limit), "utf8").digest("hex");
}

function assertMatchingRequest(broadcast: BotBroadcast, hash: string): void {
  if (broadcast.requestHash === hash) return;
  throw new AppError(
    "A chave de idempotência já foi usada com outro payload",
    409,
    { idempotencyKey: broadcast.idempotencyKey },
    IDEMPOTENCY_CONFLICT_CODE
  );
}

function activeSuspension(now: Date): Prisma.UserWhereInput {
  return { OR: [{ suspendedUntil: null }, { suspendedUntil: { lte: now } }] };
}

function premiumAudience(now: Date): Prisma.UserWhereInput {
  return {
    OR: [
      { premiumUntil: { gt: now } },
      { isPremium: true, premiumUntil: null },
    ],
  };
}

function audienceFilter(
  audience: BroadcastAudience,
  now: Date
): Prisma.UserWhereInput | undefined {
  if (audience === "premium") return premiumAudience(now);
  // Complemento explícito: `NOT premiumAudience` perderia quem nunca foi VIP
  // (premiumUntil nulo vira NULL no SQL e a linha some).
  if (audience === "free") return premiumInactiveWhere(now);
  return undefined;
}

async function createOrLoadBroadcast(
  input: BroadcastInput,
  limit: number,
  hash: string
): Promise<{ broadcast: BotBroadcast; duplicate: boolean }> {
  const idempotencyKey = input.idempotencyKey;
  const existing = await prisma.botBroadcast.findUnique({
    where: { idempotencyKey },
  });
  if (existing) {
    assertMatchingRequest(existing, hash);
    return { broadcast: existing, duplicate: true };
  }

  try {
    const broadcast = await prisma.botBroadcast.create({
      data: {
        idempotencyKey,
        requestHash: hash,
        botUserId: input.botId,
        audience: input.audience,
        recipientLimit: limit,
        messageType: input.imageUrl ? "image" : "text",
        text: input.text ?? null,
        imageUrl: input.imageUrl ?? null,
        status: BotBroadcastStatus.PENDING,
      },
    });
    return { broadcast, duplicate: false };
  } catch (error) {
    const raced = await prisma.botBroadcast.findUnique({
      where: { idempotencyKey },
    });
    if (!raced) throw error;
    assertMatchingRequest(raced, hash);
    return { broadcast: raced, duplicate: true };
  }
}

async function claimBroadcast(
  broadcast: BotBroadcast
): Promise<ClaimedBroadcast | null> {
  if (broadcast.status === BotBroadcastStatus.COMPLETED) return null;

  const now = new Date();
  if (
    broadcast.status === BotBroadcastStatus.PROCESSING &&
    broadcast.leaseUntil &&
    broadcast.leaseUntil > now
  ) {
    return null;
  }

  const leaseToken = randomUUID();
  const claimed = await prisma.botBroadcast.updateMany({
    where: {
      id: broadcast.id,
      requestHash: broadcast.requestHash,
      OR: [
        { status: { in: [BotBroadcastStatus.PENDING, BotBroadcastStatus.FAILED] } },
        { status: BotBroadcastStatus.PROCESSING, leaseUntil: null },
        { status: BotBroadcastStatus.PROCESSING, leaseUntil: { lte: now } },
      ],
    },
    data: {
      status: BotBroadcastStatus.PROCESSING,
      leaseToken,
      leaseUntil: leaseDeadline(BROADCAST_LEASE_MS),
      lastError: null,
      startedAt: broadcast.startedAt ?? now,
      sentAt: null,
    },
  });
  if (claimed.count !== 1) return null;

  const current = await prisma.botBroadcast.findUnique({
    where: { id: broadcast.id },
  });
  if (!current) throw new AppError("Broadcast não encontrado", 404);
  return { broadcast: current, leaseToken };
}

async function selectRecipientIds(
  tx: Prisma.TransactionClient,
  broadcast: BotBroadcast
): Promise<string[]> {
  const now = new Date();
  const [bannedRecords, botBlocks] = await Promise.all([
    tx.bannedUser.findMany({ select: { userId: true } }),
    tx.block.findMany({
      where: {
        OR: [
          { blockerId: broadcast.botUserId },
          { blockedId: broadcast.botUserId },
        ],
      },
      select: { blockerId: true, blockedId: true },
    }),
  ]);
  const excludedIds = new Set<string>([broadcast.botUserId]);
  for (const record of bannedRecords) excludedIds.add(record.userId);
  for (const block of botBlocks) {
    excludedIds.add(
      block.blockerId === broadcast.botUserId
        ? block.blockedId
        : block.blockerId
    );
  }

  const filter = audienceFilter(broadcast.audience as BroadcastAudience, now);
  const recipientWhere: Prisma.UserWhereInput = {
    id: { notIn: Array.from(excludedIds) },
    isBot: false,
    isBanned: false,
    deletedAt: null,
    AND: [activeSuspension(now), ...(filter ? [filter] : [])],
  };

  if (broadcast.audience === "online") {
    const profiles = await tx.profile.findMany({
      where: {
        isOnline: true,
        lastActiveAt: { gte: onlineCutoff(now) },
        user: recipientWhere,
      },
      select: { userId: true },
      orderBy: { lastActiveAt: "desc" },
      take: broadcast.recipientLimit,
    });
    return profiles.map((profile) => profile.userId);
  }

  const users = await tx.user.findMany({
    where: recipientWhere,
    select: { id: true },
    orderBy: { createdAt: "desc" },
    take: broadcast.recipientLimit,
  });
  return users.map((user) => user.id);
}

async function ensureRecipientSnapshot(claim: ClaimedBroadcast): Promise<void> {
  if (claim.broadcast.snapshotAt) return;

  await prisma.$transaction(
    async (tx) => {
      const ownershipCheckedAt = new Date();
      const owned = await tx.botBroadcast.findFirst({
        where: {
          id: claim.broadcast.id,
          status: BotBroadcastStatus.PROCESSING,
          leaseToken: claim.leaseToken,
          leaseUntil: { gt: ownershipCheckedAt },
        },
      });
      if (!owned) throw leaseLostError();
      if (owned.snapshotAt) return;

      const bot = await tx.user.findFirst({
        where: { id: owned.botUserId, isBot: true, deletedAt: null },
        select: { id: true },
      });
      if (!bot) throw new AppError("Modelo não encontrado", 404);

      const userIds = await selectRecipientIds(tx, owned);
      const now = new Date();
      if (userIds.length > 0) {
        await tx.botBroadcastRecipient.createMany({
          data: userIds.map((userId) => ({
            id: randomUUID(),
            broadcastId: owned.id,
            userId,
            status: BotBroadcastRecipientStatus.PENDING,
            createdAt: now,
            updatedAt: now,
          })),
          skipDuplicates: true,
        });
      }

      const targetedCount = await tx.botBroadcastRecipient.count({
        where: { broadcastId: owned.id },
      });
      const snapshotCommittedAt = new Date();
      const snapshotted = await tx.botBroadcast.updateMany({
        where: {
          id: owned.id,
          leaseToken: claim.leaseToken,
          leaseUntil: { gt: snapshotCommittedAt },
          snapshotAt: null,
        },
        data: {
          snapshotAt: snapshotCommittedAt,
          targetedCount,
          leaseUntil: new Date(
            snapshotCommittedAt.getTime() + BROADCAST_LEASE_MS
          ),
        },
      });
      if (snapshotted.count !== 1) throw leaseLostError();
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
  );
}

async function recipientProgress(broadcastId: string): Promise<RecipientProgress> {
  const groups = await prisma.botBroadcastRecipient.groupBy({
    by: ["status"],
    where: { broadcastId },
    _count: { _all: true },
  });
  const progress: RecipientProgress = {
    targeted: 0,
    sent: 0,
    skipped: 0,
    failed: 0,
    pending: 0,
    processing: 0,
  };
  for (const group of groups) {
    const count = group._count._all;
    progress.targeted += count;
    if (group.status === BotBroadcastRecipientStatus.SENT) progress.sent = count;
    else if (group.status === BotBroadcastRecipientStatus.SKIPPED) progress.skipped = count;
    else if (group.status === BotBroadcastRecipientStatus.FAILED) progress.failed = count;
    else if (group.status === BotBroadcastRecipientStatus.PENDING) progress.pending = count;
    else if (group.status === BotBroadcastRecipientStatus.PROCESSING) progress.processing = count;
  }
  return progress;
}

async function renewBroadcastLease(
  broadcastId: string,
  leaseToken: string,
  progress?: RecipientProgress
): Promise<void> {
  const now = new Date();
  const renewed = await prisma.botBroadcast.updateMany({
    where: {
      id: broadcastId,
      status: BotBroadcastStatus.PROCESSING,
      leaseToken,
      leaseUntil: { gt: now },
    },
    data: {
      leaseUntil: leaseDeadline(BROADCAST_LEASE_MS),
      ...(progress
        ? { sentCount: progress.sent, targetedCount: progress.targeted }
        : {}),
    },
  });
  if (renewed.count !== 1) throw leaseLostError();
}

async function claimRecipient(recipientId: string): Promise<string | null> {
  const now = new Date();
  const leaseToken = randomUUID();
  const claimed = await prisma.botBroadcastRecipient.updateMany({
    where: {
      id: recipientId,
      OR: [
        {
          status: {
            in: [
              BotBroadcastRecipientStatus.PENDING,
              BotBroadcastRecipientStatus.FAILED,
            ],
          },
        },
        {
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseUntil: null,
        },
        {
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseUntil: { lte: now },
        },
      ],
    },
    data: {
      status: BotBroadcastRecipientStatus.PROCESSING,
      leaseToken,
      leaseUntil: leaseDeadline(RECIPIENT_LEASE_MS),
      error: null,
    },
  });
  return claimed.count === 1 ? leaseToken : null;
}

async function markRecipientFailed(
  recipientId: string,
  leaseToken: string,
  error: unknown
): Promise<void> {
  await prisma.botBroadcastRecipient.updateMany({
    where: {
      id: recipientId,
      status: BotBroadcastRecipientStatus.PROCESSING,
      leaseToken,
    },
    data: {
      status: BotBroadcastRecipientStatus.FAILED,
      leaseUntil: null,
      leaseToken: null,
      error: errorMessage(error),
    },
  });
}

async function persistRecipient(params: {
  broadcast: BotBroadcast;
  broadcastLeaseToken: string;
  recipientId: string;
  recipientLeaseToken: string;
  botName: string;
}): Promise<{ userId: string; matchId: string; message: unknown } | null> {
  const result = await prisma.$transaction(
    async (tx) => {
      const ownershipCheckedAt = new Date();
      const broadcastOwned = await tx.botBroadcast.updateMany({
        where: {
          id: params.broadcast.id,
          status: BotBroadcastStatus.PROCESSING,
          leaseToken: params.broadcastLeaseToken,
          leaseUntil: { gt: ownershipCheckedAt },
        },
        data: {
          leaseUntil: new Date(
            ownershipCheckedAt.getTime() + BROADCAST_LEASE_MS
          ),
        },
      });
      if (broadcastOwned.count !== 1) throw leaseLostError();

      const recipientOwned = await tx.botBroadcastRecipient.updateMany({
        where: {
          id: params.recipientId,
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseToken: params.recipientLeaseToken,
          leaseUntil: { gt: ownershipCheckedAt },
        },
        data: {
          leaseUntil: new Date(
            ownershipCheckedAt.getTime() + RECIPIENT_LEASE_MS
          ),
        },
      });
      if (recipientOwned.count !== 1) throw leaseLostError();

      const [recipient, bot] = await Promise.all([
        tx.botBroadcastRecipient.findFirst({
          where: {
            id: params.recipientId,
            status: BotBroadcastRecipientStatus.PROCESSING,
            leaseToken: params.recipientLeaseToken,
          },
        }),
        tx.user.findFirst({
          where: {
            id: params.broadcast.botUserId,
            isBot: true,
            deletedAt: null,
          },
          select: { id: true },
        }),
      ]);
      if (!recipient) throw leaseLostError();
      if (!bot) throw new AppError("Modelo não encontrado", 404);

      const now = new Date();
      const filter = audienceFilter(
        params.broadcast.audience as BroadcastAudience,
        now
      );
      const eligibleUser = await tx.user.findFirst({
        where: {
          id: recipient.userId,
          isBot: false,
          isBanned: false,
          deletedAt: null,
          AND: [activeSuspension(now), ...(filter ? [filter] : [])],
        },
        select: { id: true },
      });
      const [banned, blocked, onlineProfile] = eligibleUser
        ? await Promise.all([
            tx.bannedUser.findUnique({ where: { userId: recipient.userId } }),
            tx.block.findFirst({
              where: {
                OR: [
                  {
                    blockerId: params.broadcast.botUserId,
                    blockedId: recipient.userId,
                  },
                  {
                    blockerId: recipient.userId,
                    blockedId: params.broadcast.botUserId,
                  },
                ],
              },
              select: { id: true },
            }),
            params.broadcast.audience === "online"
              ? tx.profile.findFirst({
                  where: {
                    userId: recipient.userId,
                    isOnline: true,
                    lastActiveAt: { gte: onlineCutoff(now) },
                  },
                  select: { id: true },
                })
              : Promise.resolve({ id: "not-required" }),
          ])
        : [null, null, null];

      if (!eligibleUser || banned || blocked || !onlineProfile) {
        const skipped = await tx.botBroadcastRecipient.updateMany({
          where: {
            id: recipient.id,
            status: BotBroadcastRecipientStatus.PROCESSING,
            leaseToken: params.recipientLeaseToken,
          },
          data: {
            status: BotBroadcastRecipientStatus.SKIPPED,
            leaseUntil: null,
            leaseToken: null,
            error: "Destinatário não elegível no momento do envio",
          },
        });
        if (skipped.count !== 1) throw leaseLostError();
        return null;
      }

      const [userAId, userBId] =
        recipient.userId < params.broadcast.botUserId
          ? [recipient.userId, params.broadcast.botUserId]
          : [params.broadcast.botUserId, recipient.userId];
      const match = await tx.match.upsert({
        where: { userAId_userBId: { userAId, userBId } },
        create: { userAId, userBId, isActive: true },
        update: { isActive: true },
      });
      await tx.interaction.upsert({
        where: {
          fromUserId_toUserId: {
            fromUserId: params.broadcast.botUserId,
            toUserId: recipient.userId,
          },
        },
        create: {
          fromUserId: params.broadcast.botUserId,
          toUserId: recipient.userId,
          type: "LIKE",
          superLikeUsedBonus: false,
        },
        update: { type: "LIKE", superLikeUsedBonus: false },
      });
      const message = await tx.message.create({
        data: {
          matchId: match.id,
          senderId: params.broadcast.botUserId,
          type: params.broadcast.imageUrl ? "IMAGE" : "TEXT",
          content: params.broadcast.imageUrl || params.broadcast.text || "",
        },
      });
      const commitCheckedAt = new Date();
      const broadcastStillOwned = await tx.botBroadcast.updateMany({
        where: {
          id: params.broadcast.id,
          status: BotBroadcastStatus.PROCESSING,
          leaseToken: params.broadcastLeaseToken,
        },
        data: {
          leaseUntil: new Date(
            commitCheckedAt.getTime() + BROADCAST_LEASE_MS
          ),
        },
      });
      if (broadcastStillOwned.count !== 1) throw leaseLostError();

      const sent = await tx.botBroadcastRecipient.updateMany({
        where: {
          id: recipient.id,
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseToken: params.recipientLeaseToken,
        },
        data: {
          status: BotBroadcastRecipientStatus.SENT,
          leaseUntil: null,
          leaseToken: null,
          messageId: message.id,
          error: null,
          sentAt: now,
        },
      });
      if (sent.count !== 1) throw leaseLostError();
      return { userId: recipient.userId, matchId: match.id, message };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
  );

  if (!result) return null;
  emitToUser(result.userId, "message:new", result.message);
  void pushOnly(
    result.userId,
    params.botName,
    (params.broadcast.text || "📷 Foto").slice(0, 80),
    {
      matchId: result.matchId,
      type: "message",
      broadcastId: params.broadcast.id,
    }
  );
  return result;
}

async function processRecipients(claim: ClaimedBroadcast, botName: string): Promise<void> {
  const now = new Date();
  const recipients = await prisma.botBroadcastRecipient.findMany({
    where: {
      broadcastId: claim.broadcast.id,
      OR: [
        {
          status: {
            in: [
              BotBroadcastRecipientStatus.PENDING,
              BotBroadcastRecipientStatus.FAILED,
            ],
          },
        },
        {
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseUntil: null,
        },
        {
          status: BotBroadcastRecipientStatus.PROCESSING,
          leaseUntil: { lte: now },
        },
      ],
    },
    orderBy: { createdAt: "asc" },
    select: { id: true },
  });

  for (let index = 0; index < recipients.length; index += 1) {
    await renewBroadcastLease(claim.broadcast.id, claim.leaseToken);
    const recipientLeaseToken = await claimRecipient(recipients[index].id);
    if (!recipientLeaseToken) continue;

    try {
      await persistRecipient({
        broadcast: claim.broadcast,
        broadcastLeaseToken: claim.leaseToken,
        recipientId: recipients[index].id,
        recipientLeaseToken,
        botName,
      });
    } catch (error) {
      await markRecipientFailed(
        recipients[index].id,
        recipientLeaseToken,
        error
      );
    }

    if ((index + 1) % PROGRESS_RECONCILE_INTERVAL === 0) {
      const progress = await recipientProgress(claim.broadcast.id);
      await renewBroadcastLease(
        claim.broadcast.id,
        claim.leaseToken,
        progress
      );
    }
  }
}

async function finalizeBroadcast(claim: ClaimedBroadcast): Promise<BotBroadcast> {
  const progress = await recipientProgress(claim.broadcast.id);
  const hasRemaining = progress.pending > 0 || progress.processing > 0;
  const failed = progress.failed > 0 || hasRemaining;
  const status = failed
    ? BotBroadcastStatus.FAILED
    : BotBroadcastStatus.COMPLETED;
  const now = new Date();
  const finalized = await prisma.botBroadcast.updateMany({
    where: {
      id: claim.broadcast.id,
      status: BotBroadcastStatus.PROCESSING,
      leaseToken: claim.leaseToken,
      leaseUntil: { gt: now },
    },
    data: {
      status,
      targetedCount: progress.targeted,
      sentCount: progress.sent,
      leaseUntil: null,
      leaseToken: null,
      lastError: failed
        ? `${progress.failed + progress.pending + progress.processing} destinatário(s) aguardam nova tentativa`
        : null,
      sentAt: failed ? null : now,
    },
  });
  if (finalized.count !== 1) throw leaseLostError();

  const current = await prisma.botBroadcast.findUnique({
    where: { id: claim.broadcast.id },
  });
  if (!current) throw new AppError("Broadcast não encontrado", 404);
  return current;
}

async function failGlobalExecution(
  claim: ClaimedBroadcast,
  error: unknown
): Promise<void> {
  const progress = await recipientProgress(claim.broadcast.id).catch(() => null);
  let cleanupError: unknown;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await prisma.botBroadcast.updateMany({
        where: {
          id: claim.broadcast.id,
          status: BotBroadcastStatus.PROCESSING,
          leaseToken: claim.leaseToken,
        },
        data: {
          status: BotBroadcastStatus.FAILED,
          leaseUntil: null,
          leaseToken: null,
          lastError: errorMessage(error),
          ...(progress
            ? { sentCount: progress.sent, targetedCount: progress.targeted }
            : {}),
        },
      });
      return;
    } catch (currentError) {
      cleanupError = currentError;
      if (attempt < 2) {
        await new Promise((resolve) => setTimeout(resolve, 25 * (attempt + 1)));
      }
    }
  }
  throw cleanupError;
}

export async function runBotBroadcast(
  input: BroadcastInput
): Promise<{ broadcast: BotBroadcast; duplicate: boolean }> {
  const limit = input.limit ?? 500;
  const hash = requestHash(input, limit);
  const loaded = await createOrLoadBroadcast(input, limit, hash);
  if (loaded.broadcast.status === BotBroadcastStatus.COMPLETED) return loaded;

  const claim = await claimBroadcast(loaded.broadcast);
  if (!claim) {
    const current = await prisma.botBroadcast.findUnique({
      where: { id: loaded.broadcast.id },
    });
    if (!current) throw new AppError("Broadcast não encontrado", 404);
    return { broadcast: current, duplicate: true };
  }

  try {
    await ensureRecipientSnapshot(claim);
    const current = await prisma.botBroadcast.findUnique({
      where: { id: claim.broadcast.id },
    });
    if (!current) throw new AppError("Broadcast não encontrado", 404);
    claim.broadcast = current;
    await processRecipients(claim, input.botName);
    const broadcast = await finalizeBroadcast(claim);
    return { broadcast, duplicate: loaded.duplicate };
  } catch (error) {
    try {
      await failGlobalExecution(claim, error);
    } catch (cleanupError) {
      throw new AggregateError(
        [error, cleanupError],
        `${errorMessage(error)}; também não foi possível liberar o lease`
      );
    }
    throw error;
  }
}

export async function serializeBroadcast(
  broadcast: BotBroadcast,
  duplicate: boolean
) {
  const progress = await recipientProgress(broadcast.id);
  return {
    ok: true,
    sent: progress.sent,
    sentCount: progress.sent,
    targeted: progress.targeted,
    targetedCount: progress.targeted,
    skipped: progress.skipped,
    failedCount: progress.failed,
    broadcastId: broadcast.id,
    idempotencyKey: broadcast.idempotencyKey,
    status: broadcast.status,
    duplicate,
    processing:
      broadcast.status === BotBroadcastStatus.PENDING ||
      broadcast.status === BotBroadcastStatus.PROCESSING,
    failed: broadcast.status === BotBroadcastStatus.FAILED,
    lastError: broadcast.lastError,
    sentAt: broadcast.sentAt,
  };
}

export async function listBotBroadcasts(botUserId: string) {
  const broadcasts = await prisma.botBroadcast.findMany({
    where: { botUserId },
    orderBy: { createdAt: "desc" },
    take: 20,
  });
  if (broadcasts.length === 0) return [];

  const groups = await prisma.botBroadcastRecipient.groupBy({
    by: ["broadcastId", "status"],
    where: { broadcastId: { in: broadcasts.map((item) => item.id) } },
    _count: { _all: true },
  });
  const progressById = new Map<string, RecipientProgress>();
  for (const item of broadcasts) {
    progressById.set(item.id, {
      targeted: 0,
      sent: 0,
      skipped: 0,
      failed: 0,
      pending: 0,
      processing: 0,
    });
  }
  for (const group of groups) {
    const progress = progressById.get(group.broadcastId)!;
    const count = group._count._all;
    progress.targeted += count;
    if (group.status === BotBroadcastRecipientStatus.SENT) progress.sent = count;
    else if (group.status === BotBroadcastRecipientStatus.SKIPPED) progress.skipped = count;
    else if (group.status === BotBroadcastRecipientStatus.FAILED) progress.failed = count;
    else if (group.status === BotBroadcastRecipientStatus.PENDING) progress.pending = count;
    else if (group.status === BotBroadcastRecipientStatus.PROCESSING) progress.processing = count;
  }

  return broadcasts.map((item) => {
    const progress = progressById.get(item.id)!;
    const targeted = progress.targeted || item.targetedCount;
    const sent = progress.targeted > 0 ? progress.sent : item.sentCount;
    return {
      id: item.id,
      idempotencyKey: item.idempotencyKey,
      text: item.text || "📷 Imagem",
      audience: item.audience,
      status: item.status,
      sent,
      sentCount: sent,
      targeted,
      targetedCount: targeted,
      skipped: progress.skipped,
      failedCount: progress.failed,
      sentAt: item.sentAt,
      createdAt: item.createdAt,
      processing:
        item.status === BotBroadcastStatus.PENDING ||
        item.status === BotBroadcastStatus.PROCESSING,
      failed: item.status === BotBroadcastStatus.FAILED,
      lastError: item.lastError,
    };
  });
}
