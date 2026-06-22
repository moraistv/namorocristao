import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { hashPassword } from "../../lib/password";
import { assertPermission, assertSuperAdmin } from "../../lib/adminPermission";
import { ageFromBirthday } from "../../lib/age";
import { PREMIUM_PLANS } from "../../lib/premium";
import { notifyUsers } from "../../lib/push";
import { emitToUser } from "../../sockets";

// ─────────── Dashboard ───────────
// GET /api/admin/dashboard
export async function dashboard(_req: Request, res: Response) {
  const [
    totalUsers,
    male,
    female,
    verified,
    likes,
    dislikes,
    superlikes,
    matches,
    devices,
    reports,
    banned,
    pendingVerifications,
    deleteRequests,
  ] = await Promise.all([
    prisma.profile.count(),
    prisma.profile.count({ where: { gender: "MALE" } }),
    prisma.profile.count({ where: { gender: "FEMALE" } }),
    prisma.profile.count({ where: { isVerified: true } }),
    prisma.interaction.count({ where: { type: "LIKE" } }),
    prisma.interaction.count({ where: { type: "DISLIKE" } }),
    prisma.interaction.count({ where: { type: "SUPERLIKE" } }),
    prisma.match.count({ where: { isActive: true } }),
    prisma.deviceToken.count(),
    prisma.report.count(),
    prisma.bannedUser.count(),
    prisma.verificationForm.count({ where: { status: "PENDING" } }),
    prisma.accountDeleteRequest.count({ where: { status: "PENDING" } }),
  ]);

  const online = await prisma.profile.count({ where: { isOnline: true } });

  res.json({
    users: { total: totalUsers, male, female, verified, online },
    interactions: { likes, dislikes, superlikes, total: likes + dislikes + superlikes },
    matches,
    devices,
    reports,
    banned,
    pendingVerifications,
    deleteRequests,
  });
}

// GET /api/admin/stats/signups?days=14
export async function signupsSeries(req: Request, res: Response) {
  const days = Math.min(Math.max(Number(req.query.days) || 14, 1), 90);
  const since = new Date();
  since.setHours(0, 0, 0, 0);
  since.setDate(since.getDate() - (days - 1));

  const users = await prisma.user.findMany({
    where: { createdAt: { gte: since } },
    select: { createdAt: true },
  });

  // Buckets por dia (YYYY-MM-DD).
  const buckets = new Map<string, number>();
  for (let i = 0; i < days; i++) {
    const d = new Date(since);
    d.setDate(since.getDate() + i);
    buckets.set(d.toISOString().slice(0, 10), 0);
  }
  for (const u of users) {
    const key = u.createdAt.toISOString().slice(0, 10);
    if (buckets.has(key)) buckets.set(key, (buckets.get(key) || 0) + 1);
  }

  const series = Array.from(buckets.entries()).map(([date, count]) => ({
    date,
    count,
  }));
  res.json({ series });
}

// Mapa cidade → estado (UF). Cobre as cidades dos perfis de teste + grandes capitais.
const CITY_UF: Record<string, { uf: string; nome: string }> = {
  "são paulo": { uf: "SP", nome: "São Paulo" },
  "sao paulo": { uf: "SP", nome: "São Paulo" },
  "campinas": { uf: "SP", nome: "São Paulo" },
  "guarulhos": { uf: "SP", nome: "São Paulo" },
  "osasco": { uf: "SP", nome: "São Paulo" },
  "santo andré": { uf: "SP", nome: "São Paulo" },
  "santo andre": { uf: "SP", nome: "São Paulo" },
  "são bernardo": { uf: "SP", nome: "São Paulo" },
  "são bernardo do campo": { uf: "SP", nome: "São Paulo" },
  "diadema": { uf: "SP", nome: "São Paulo" },
  "rio de janeiro": { uf: "RJ", nome: "Rio de Janeiro" },
  "belo horizonte": { uf: "MG", nome: "Minas Gerais" },
  "curitiba": { uf: "PR", nome: "Paraná" },
  "porto alegre": { uf: "RS", nome: "Rio Grande do Sul" },
  "salvador": { uf: "BA", nome: "Bahia" },
  "recife": { uf: "PE", nome: "Pernambuco" },
  "fortaleza": { uf: "CE", nome: "Ceará" },
  "brasília": { uf: "DF", nome: "Distrito Federal" },
  "brasilia": { uf: "DF", nome: "Distrito Federal" },
  "goiânia": { uf: "GO", nome: "Goiás" },
  "goiania": { uf: "GO", nome: "Goiás" },
};

// GET /api/admin/stats/locations — usuários por estado (BR) e por cidade.
export async function locationStats(_req: Request, res: Response) {
  const grouped = await prisma.profile.groupBy({
    by: ["city"],
    _count: { city: true },
  });

  const states = new Map<string, { uf: string; nome: string; count: number }>();
  const cities: { city: string; count: number }[] = [];
  let outros = 0;

  for (const g of grouped) {
    const count = g._count.city;
    const raw = (g.city || "").trim();
    if (raw) cities.push({ city: raw, count });
    const key = raw.toLowerCase();
    const uf = CITY_UF[key];
    if (uf) {
      const cur = states.get(uf.uf) ?? { uf: uf.uf, nome: uf.nome, count: 0 };
      cur.count += count;
      states.set(uf.uf, cur);
    } else {
      outros += count;
    }
  }

  const byState = Array.from(states.values()).sort((a, b) => b.count - a.count);
  if (outros > 0) byState.push({ uf: "—", nome: "Outros", count: outros });
  const topCities = cities.sort((a, b) => b.count - a.count).slice(0, 6);

  res.json({ byState, topCities });
}

// ─────────── Usuários ───────────
// GET /api/admin/users?search=&take=&skip=&banned=
export async function listUsers(req: Request, res: Response) {
  const search = (req.query.search as string)?.trim();
  const onlyBanned = req.query.banned === "true";
  const onlyOnline = req.query.online === "true";
  const take = Math.min(Number(req.query.take) || 30, 100);
  const skip = Number(req.query.skip) || 0;

  const and: any[] = [];
  if (search) {
    and.push({
      OR: [
        { fullName: { contains: search, mode: "insensitive" as const } },
        { city: { contains: search, mode: "insensitive" as const } },
      ],
    });
  }
  if (onlyBanned) {
    and.push({ user: { isBanned: true } });
  }
  if (onlyOnline) {
    and.push({ isOnline: true });
  }
  const where = and.length ? { AND: and } : {};

  const [items, total] = await Promise.all([
    prisma.profile.findMany({
      where,
      take,
      skip,
      orderBy: { createdAt: "desc" },
      include: { user: { select: { email: true, provider: true, isBanned: true, suspendedUntil: true, createdAt: true } } },
    }),
    prisma.profile.count({ where }),
  ]);

  const now = Date.now();
  res.json({
    total,
    users: items.map((p) => ({
      userId: p.userId,
      fullName: p.fullName,
      email: p.user.email,
      provider: p.user.provider,
      gender: p.gender,
      age: ageFromBirthday(p.birthday),
      city: p.city,
      isVerified: p.isVerified,
      isBanned: p.user.isBanned,
      isSuspended: !!p.user.suspendedUntil && p.user.suspendedUntil.getTime() > now,
      suspendedUntil: p.user.suspendedUntil,
      isOnline: p.isOnline,
      lastActiveAt: p.lastActiveAt,
      profilePicture: p.profilePicture,
      createdAt: p.createdAt,
    })),
  });
}

// GET /api/admin/users/:userId — detalhes completos (controle/segurança total)
export async function userDetail(req: Request, res: Response) {
  const userId = req.params.userId;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });
  if (!user) throw new AppError("Usuário não encontrado", 404);

  const [
    likesGiven,
    dislikesGiven,
    superlikesGiven,
    likesReceived,
    superlikesReceived,
    activeMatches,
    totalMatches,
    messagesSent,
    reportsAgainst,
    reportsMade,
    blocksMade,
    blockedByOthers,
    photoReqReceived,
    photoReqMade,
    verifications,
    notifications,
    feeds,
    devices,
    banInfo,
    deleteReq,
    accessLogs,
  ] = await Promise.all([
    prisma.interaction.count({ where: { fromUserId: userId, type: "LIKE" } }),
    prisma.interaction.count({ where: { fromUserId: userId, type: "DISLIKE" } }),
    prisma.interaction.count({ where: { fromUserId: userId, type: "SUPERLIKE" } }),
    prisma.interaction.count({ where: { toUserId: userId, type: "LIKE" } }),
    prisma.interaction.count({ where: { toUserId: userId, type: "SUPERLIKE" } }),
    prisma.match.count({ where: { isActive: true, OR: [{ userAId: userId }, { userBId: userId }] } }),
    prisma.match.count({ where: { OR: [{ userAId: userId }, { userBId: userId }] } }),
    prisma.message.count({ where: { senderId: userId } }),
    prisma.report.count({ where: { reportedId: userId } }),
    prisma.report.count({ where: { reporterId: userId } }),
    prisma.block.count({ where: { blockerId: userId } }),
    prisma.block.count({ where: { blockedId: userId } }),
    prisma.photoAccessRequest.count({ where: { ownerId: userId } }),
    prisma.photoAccessRequest.count({ where: { requesterId: userId } }),
    prisma.verificationForm.findMany({ where: { userId }, orderBy: { createdAt: "desc" }, take: 5 }),
    prisma.notification.count({ where: { userId } }),
    prisma.feed.count({ where: { userId } }),
    prisma.deviceToken.findMany({ where: { userId }, orderBy: { createdAt: "desc" } }),
    prisma.bannedUser.findUnique({ where: { userId } }),
    prisma.accountDeleteRequest.findUnique({ where: { userId } }),
    prisma.accessLog.findMany({ where: { userId }, orderBy: { createdAt: "desc" }, take: 25 }),
  ]);

  // Denúncias recebidas (detalhadas) — ajuda moderação/LGPD.
  const reportsReceivedList = await prisma.report.findMany({
    where: { reportedId: userId },
    orderBy: { createdAt: "desc" },
    take: 15,
  });

  // Gasto estimado a partir do plano premium (não há histórico de pagamentos).
  const PLAN_PRICES: Record<string, { label: string; price: number }> = {
    monthly: { label: "Mensal", price: 29.9 },
    quarterly: { label: "Trimestral", price: 69.9 },
    yearly: { label: "Anual", price: 199.9 },
  };
  const plan = user.premiumPlan ? PLAN_PRICES[user.premiumPlan] : null;
  const estimatedSpend = user.isPremium && plan ? plan.price : 0;

  const photos = user.profile?.mediaFiles?.length ?? 0;
  const lockedPhotos = user.profile?.lockedPhotos?.length ?? 0;
  const accountAgeDays = Math.floor((Date.now() - user.createdAt.getTime()) / 86400000);
  const lastIp = accessLogs[0]?.ip ?? null;

  // Localização (cidade -> UF/estado) para o mapa.
  const cityKey = (user.profile?.city || "").trim().toLowerCase();
  const ufInfo = CITY_UF[cityKey];
  const location = {
    city: user.profile?.city ?? null,
    uf: ufInfo?.uf ?? null,
    stateName: ufInfo?.nome ?? null,
    latitude: user.profile?.latitude ?? null,
    longitude: user.profile?.longitude ?? null,
    addressText: user.profile?.addressText ?? null,
  };

  res.json({
    user: {
      id: user.id,
      email: user.email,
      emailVerified: user.emailVerified,
      provider: user.provider,
      isBanned: user.isBanned,
      isPremium: user.isPremium,
      isSuspended: !!user.suspendedUntil && user.suspendedUntil.getTime() > Date.now(),
      suspendedUntil: user.suspendedUntil,
      premiumPlan: plan?.label ?? null,
      premiumUntil: user.premiumUntil,
      superLikesUsedToday: user.superLikesUsedToday,
      boostsRemaining: user.boostsRemaining,
      credits: user.credits,
      createdAt: user.createdAt,
      deletedAt: user.deletedAt,
      accountAgeDays,
    },
    profile: user.profile,
    location,
    ban: banInfo ? { reason: banInfo.reason, since: banInfo.createdAt } : null,
    deleteRequest: deleteReq ? { status: deleteReq.status, since: deleteReq.createdAt } : null,
    reportsReceived: reportsReceivedList.map((r) => ({
      id: r.id,
      reporterId: r.reporterId,
      reason: r.reason,
      status: r.status,
      at: r.createdAt,
    })),
    billing: {
      isPremium: user.isPremium,
      plan: plan?.label ?? null,
      planPrice: plan?.price ?? null,
      estimatedSpend,
      premiumUntil: user.premiumUntil,
    },
    stats: {
      likesGiven,
      dislikesGiven,
      superlikesGiven,
      likesReceived,
      superlikesReceived,
      activeMatches,
      totalMatches,
      messagesSent,
      reportsAgainst,
      reportsMade,
      blocksMade,
      blockedByOthers,
      photos,
      lockedPhotos,
      photoReqReceived,
      photoReqMade,
      notifications,
      feeds,
      verificationsCount: verifications.length,
      lastVerificationStatus: verifications[0]?.status ?? null,
    },
    security: {
      lastIp,
      devices: devices.map((d) => ({ platform: d.platform, since: d.createdAt })),
      accessLogs: accessLogs.map((l) => ({
        ip: l.ip,
        userAgent: l.userAgent,
        action: l.action,
        at: l.createdAt,
      })),
    },
  });
}

// ─────────── Ban / Unban ───────────
const banSchema = z.object({ reason: z.string().max(300).optional() });

// POST /api/admin/users/:userId/ban
export async function banUser(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  const { reason } = banSchema.parse(req.body ?? {});

  await prisma.$transaction([
    prisma.user.update({ where: { id: userId }, data: { isBanned: true } }),
    prisma.bannedUser.upsert({
      where: { userId },
      create: { userId, reason },
      update: { reason },
    }),
    prisma.match.updateMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      data: { isActive: false },
    }),
  ]);
  emitToUser(userId, "config:me", { banned: true });
  res.json({ ok: true });
}

// DELETE /api/admin/users/:userId/ban
export async function unbanUser(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  await prisma.$transaction([
    prisma.user.update({ where: { id: userId }, data: { isBanned: false } }),
    prisma.bannedUser.deleteMany({ where: { userId } }),
  ]);
  emitToUser(userId, "config:me", { banned: false });
  res.json({ ok: true });
}

// ─────────── Suspensão (banimento temporário) ───────────
const suspendSchema = z.object({ days: z.number().int().min(1).max(365).default(7) });

// POST /api/admin/users/:userId/suspend  { days }
export async function suspendUser(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  const { days } = suspendSchema.parse(req.body ?? {});
  const until = new Date(Date.now() + days * 86400000);

  await prisma.$transaction([
    prisma.user.update({ where: { id: userId }, data: { suspendedUntil: until } }),
    prisma.match.updateMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      data: { isActive: false },
    }),
  ]);
  emitToUser(userId, "config:me", { suspended: true });
  res.json({ ok: true, suspendedUntil: until });
}

// DELETE /api/admin/users/:userId/suspend
export async function unsuspendUser(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  await prisma.user.update({ where: { id: userId }, data: { suspendedUntil: null } });
  emitToUser(userId, "config:me", { suspended: false });
  res.json({ ok: true });
}

// ─────────── VIP / Premium ───────────
const premiumSchema = z.object({
  plan: z.enum(["monthly", "quarterly", "yearly"]),
  days: z.number().int().min(1).max(3650).optional(),
});

// POST /api/admin/users/:userId/premium  { plan, days? } — concede VIP
export async function grantPremium(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  const { plan, days } = premiumSchema.parse(req.body ?? {});
  const planDays = days ?? PREMIUM_PLANS[plan].days;
  const until = new Date(Date.now() + planDays * 86400000);

  const user = await prisma.user.update({
    where: { id: userId },
    data: { isPremium: true, premiumPlan: plan, premiumUntil: until },
  });
  // Avisa o app do usuário em tempo real (esconde anúncios, atualiza VIP).
  emitToUser(userId, "config:me", { isPremium: true });
  res.json({ ok: true, premiumUntil: user.premiumUntil, plan });
}

// DELETE /api/admin/users/:userId/premium — remove VIP
export async function revokePremium(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  await prisma.user.update({
    where: { id: userId },
    data: { isPremium: false, premiumPlan: null, premiumUntil: null },
  });
  // Avisa o app do usuário em tempo real.
  emitToUser(userId, "config:me", { isPremium: false });
  res.json({ ok: true });
}

// ─────────── Créditos (super likes / boosts) ───────────
const creditsSchema = z.object({
  superLikes: z.number().int().min(0).max(1000).optional(),
  boosts: z.number().int().min(0).max(1000).optional(),
  credits: z.number().int().min(0).max(100000).optional(),
});

// POST /api/admin/users/:userId/credits  { superLikes?, boosts?, credits? }
export async function addCredits(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const userId = req.params.userId;
  const { superLikes = 0, boosts = 0, credits = 0 } = creditsSchema.parse(req.body ?? {});

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError("Usuário não encontrado", 404);

  // Super likes extras: reduz o contador de uso de hoje (libera mais hoje).
  const newUsed = superLikes > 0 ? user.superLikesUsedToday - superLikes : user.superLikesUsedToday;

  const updated = await prisma.user.update({
    where: { id: userId },
    data: {
      boostsRemaining: { increment: boosts },
      credits: { increment: credits },
      superLikesUsedToday: newUsed,
    },
  });
  res.json({
    ok: true,
    boostsRemaining: updated.boostsRemaining,
    credits: updated.credits,
    superLikesUsedToday: updated.superLikesUsedToday,
  });
  emitToUser(userId, "config:me", { creditsChanged: true });
}

// ─────────── Verificação manual ───────────
const verifySchema = z.object({ verified: z.boolean() });

// POST /api/admin/users/:userId/verify  { verified }
export async function setVerified(req: Request, res: Response) {
  await assertPermission(req.adminId, "VERIFICATION");
  const userId = req.params.userId;
  const { verified } = verifySchema.parse(req.body ?? {});
  await prisma.profile.updateMany({ where: { userId }, data: { isVerified: verified } });
  emitToUser(userId, "config:me", { verified });
  res.json({ ok: true, verified });
}

// ─────────── Denúncias ───────────
// GET /api/admin/reports?status=
export async function listReports(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const status = req.query.status as string | undefined;
  const reports = await prisma.report.findMany({
    where: status ? { status: status as any } : {},
    orderBy: { createdAt: "desc" },
    take: 100,
  });
  res.json({ reports });
}

const reportStatusSchema = z.object({
  status: z.enum(["PENDING", "REVIEWED", "DISMISSED"]),
});

// POST /api/admin/reports/:id
export async function updateReport(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const { status } = reportStatusSchema.parse(req.body);
  const report = await prisma.report.update({
    where: { id: req.params.id },
    data: { status },
  });
  res.json({ report });
}

// Resumo de um usuário (para cards de denúncia).
async function userSummary(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });
  if (!user) return { id: userId, exists: false } as any;
  return {
    id: user.id,
    exists: true,
    email: user.email,
    fullName: user.profile?.fullName ?? "(sem perfil)",
    profilePicture: user.profile?.profilePicture ?? null,
    city: user.profile?.city ?? null,
    age: user.profile?.birthday ? ageFromBirthday(user.profile.birthday) : null,
    gender: user.profile?.gender ?? null,
    isVerified: user.profile?.isVerified ?? false,
    isOnline: user.profile?.isOnline ?? false,
    isBanned: user.isBanned,
    isSuspended: !!user.suspendedUntil && user.suspendedUntil.getTime() > Date.now(),
    isPremium: user.isPremium,
    createdAt: user.createdAt,
  };
}

// GET /api/admin/reports/:id — detalhe completo da denúncia (investigação)
export async function reportDetail(req: Request, res: Response) {
  await assertPermission(req.adminId, "REPORT");
  const report = await prisma.report.findUnique({ where: { id: req.params.id } });
  if (!report) throw new AppError("Denúncia não encontrada", 404);

  const [reporter, reported] = await Promise.all([
    userSummary(report.reporterId),
    userSummary(report.reportedId),
  ]);

  // Relação entre as duas contas.
  const [matchBetween, blockReportedToReporter, blockReporterToReported, msgsBetween] =
    await Promise.all([
      prisma.match.findFirst({
        where: {
          OR: [
            { userAId: report.reporterId, userBId: report.reportedId },
            { userAId: report.reportedId, userBId: report.reporterId },
          ],
        },
      }),
      prisma.block.findFirst({ where: { blockerId: report.reportedId, blockedId: report.reporterId } }),
      prisma.block.findFirst({ where: { blockerId: report.reporterId, blockedId: report.reportedId } }),
      prisma.interaction.findMany({
        where: {
          OR: [
            { fromUserId: report.reporterId, toUserId: report.reportedId },
            { fromUserId: report.reportedId, toUserId: report.reporterId },
          ],
        },
      }),
    ]);

  // Histórico de denúncias.
  const [reportsAgainstReported, reportsByReporter, otherReportsAgainst] = await Promise.all([
    prisma.report.count({ where: { reportedId: report.reportedId } }),
    prisma.report.count({ where: { reporterId: report.reporterId } }),
    prisma.report.findMany({
      where: { reportedId: report.reportedId, id: { not: report.id } },
      orderBy: { createdAt: "desc" },
      take: 10,
    }),
  ]);

  res.json({
    report: {
      id: report.id,
      reason: report.reason,
      status: report.status,
      createdAt: report.createdAt,
    },
    reporter,
    reported,
    relationship: {
      isMatched: !!matchBetween,
      matchActive: matchBetween?.isActive ?? false,
      matchSince: matchBetween?.createdAt ?? null,
      reportedBlockedReporter: !!blockReportedToReporter,
      reporterBlockedReported: !!blockReporterToReported,
      interactions: msgsBetween.map((i) => ({ from: i.fromUserId, type: i.type, at: i.createdAt })),
    },
    history: {
      reportsAgainstReported,
      reportsByReporter,
      otherReportsAgainst: otherReportsAgainst.map((r) => ({
        id: r.id,
        reason: r.reason,
        status: r.status,
        at: r.createdAt,
      })),
    },
  });
}

// ─────────── Verificações ───────────
// GET /api/admin/verifications?status=
export async function listVerifications(req: Request, res: Response) {
  await assertPermission(req.adminId, "VERIFICATION");
  const status = (req.query.status as string) || "PENDING";
  const forms = await prisma.verificationForm.findMany({
    where: { status: status as any },
    orderBy: { createdAt: "desc" },
    take: 100,
  });
  res.json({ verifications: forms });
}

const reviewSchema = z.object({ approve: z.boolean() });

// POST /api/admin/verifications/:id/review
export async function reviewVerification(req: Request, res: Response) {
  const admin = await assertPermission(req.adminId, "VERIFICATION");
  const { approve } = reviewSchema.parse(req.body);
  const form = await prisma.verificationForm.findUnique({
    where: { id: req.params.id },
  });
  if (!form) throw new AppError("Formulário não encontrado", 404);

  const updated = await prisma.verificationForm.update({
    where: { id: form.id },
    data: { status: approve ? "APPROVED" : "REJECTED", reviewedById: admin.id },
  });

  if (approve) {
    await prisma.profile.updateMany({
      where: { userId: form.userId },
      data: { isVerified: true },
    });
  }
  res.json({ verification: updated });
}

// ─────────── Pedidos de exclusão de conta ───────────
// GET /api/admin/account-delete-requests
export async function listDeleteRequests(req: Request, res: Response) {
  await assertPermission(req.adminId, "ACCOUNT_DELETE");
  const requests = await prisma.accountDeleteRequest.findMany({
    where: { status: "PENDING" },
    orderBy: { createdAt: "desc" },
  });

  const enriched = await Promise.all(
    requests.map(async (r) => {
      const user = await prisma.user.findUnique({
        where: { id: r.userId },
        include: { profile: true },
      });
      return {
        id: r.id,
        userId: r.userId,
        status: r.status,
        createdAt: r.createdAt,
        email: user?.email ?? "(removido)",
        fullName: user?.profile?.fullName ?? "(sem perfil)",
        profilePicture: user?.profile?.profilePicture ?? null,
        city: user?.profile?.city ?? null,
        isPremium: user?.isPremium ?? false,
        userCreatedAt: user?.createdAt ?? null,
      };
    })
  );
  res.json({ requests: enriched });
}

// POST /api/admin/account-delete-requests/:userId/process
// Anonimiza a conta (LGPD): remove dados pessoais, encerra matches, marca DONE.
export async function processDeleteRequest(req: Request, res: Response) {
  await assertPermission(req.adminId, "ACCOUNT_DELETE");
  const userId = req.params.userId;

  await prisma.$transaction([
    prisma.profile.deleteMany({ where: { userId } }),
    prisma.deviceToken.deleteMany({ where: { userId } }),
    prisma.match.updateMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      data: { isActive: false },
    }),
    prisma.user.update({
      where: { id: userId },
      data: {
        email: `deleted-${userId}@deleted.local`,
        passwordHash: null,
        googleId: null,
        deletedAt: new Date(),
      },
    }),
    prisma.accountDeleteRequest.updateMany({
      where: { userId },
      data: { status: "DONE" },
    }),
  ]);
  res.json({ ok: true });
}

// ─────────── Notificações manuais (push) ───────────
const broadcastSchema = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(500),
  audience: z.enum(["all", "premium", "free", "online", "user"]).default("all"),
  userId: z.string().optional(),
});

// POST /api/admin/notifications/broadcast
export async function broadcastNotification(req: Request, res: Response) {
  const { title, body, audience, userId } = broadcastSchema.parse(req.body);

  let userIds: string[] = [];
  const now = new Date();

  if (audience === "user") {
    if (!userId) throw new AppError("userId é obrigatório para envio individual", 422);
    userIds = [userId];
  } else if (audience === "premium") {
    const users = await prisma.user.findMany({
      where: { OR: [{ isPremium: true }, { premiumUntil: { gt: now } }] },
      select: { id: true },
    });
    userIds = users.map((u) => u.id);
  } else if (audience === "free") {
    const users = await prisma.user.findMany({
      where: { isPremium: false, OR: [{ premiumUntil: null }, { premiumUntil: { lte: now } }] },
      select: { id: true },
    });
    userIds = users.map((u) => u.id);
  } else if (audience === "online") {
    const profiles = await prisma.profile.findMany({
      where: { isOnline: true },
      select: { userId: true },
    });
    userIds = profiles.map((p) => p.userId);
  } else {
    const users = await prisma.user.findMany({
      where: { deletedAt: null },
      select: { id: true },
    });
    userIds = users.map((u) => u.id);
  }

  const sent = await notifyUsers(userIds, title, body, { type: "admin" });
  res.json({ ok: true, sent });
}

// GET /api/admin/notifications/recent — últimas notificações enviadas
export async function recentNotifications(_req: Request, res: Response) {
  const list = await prisma.notification.findMany({
    where: { type: "admin" },
    orderBy: { createdAt: "desc" },
    take: 40,
  });
  // Agrupa por título+corpo+minuto (cada broadcast vira 1 linha aproximada).
  res.json({ notifications: list });
}

// ─────────── Configurações do app ───────────
// GET /api/admin/settings
export async function getSettings(_req: Request, res: Response) {
  const settings = await prisma.appSettings.upsert({
    where: { id: 1 },
    create: { id: 1 },
    update: {},
  });
  res.json({ settings });
}

const settingsSchema = z.object({
  isChattingEnabledBeforeMatch: z.boolean().optional(),
  boostDurationMin: z.number().int().min(1).max(720).optional(),
  superLikeMessageEnabled: z.boolean().optional(),
  rewindPremiumOnly: z.boolean().optional(),
  incognitoPremiumOnly: z.boolean().optional(),
  dailyVerseEnabled: z.boolean().optional(),
  freeDailyLikes: z.number().int().min(0).max(1000).optional(),
});

// PUT /api/admin/settings
export async function updateSettings(req: Request, res: Response) {
  const data = settingsSchema.parse(req.body);
  const settings = await prisma.appSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...data },
    update: data,
  });
  res.json({ settings });
}

// ─────────── Gestão de admins (super-admin) ───────────
// GET /api/admin/admins
export async function listAdmins(req: Request, res: Response) {
  await assertSuperAdmin(req.adminId);
  const admins = await prisma.admin.findMany({ orderBy: { createdAt: "desc" } });
  res.json({
    admins: admins.map((a) => ({
      id: a.id,
      name: a.name,
      email: a.email,
      permissions: a.permissions,
      isSuperAdmin: a.isSuperAdmin,
      createdAt: a.createdAt,
    })),
  });
}

const createAdminSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  permissions: z
    .array(z.enum(["VERIFICATION", "REPORT", "ACCOUNT_DELETE"]))
    .default([]),
});

// POST /api/admin/admins
export async function createAdmin(req: Request, res: Response) {
  await assertSuperAdmin(req.adminId);
  const data = createAdminSchema.parse(req.body);
  const existing = await prisma.admin.findUnique({
    where: { email: data.email.toLowerCase() },
  });
  if (existing) throw new AppError("E-mail já usado por outro admin", 409);

  const admin = await prisma.admin.create({
    data: {
      name: data.name,
      email: data.email.toLowerCase(),
      passwordHash: await hashPassword(data.password),
      permissions: data.permissions,
      isSuperAdmin: false,
    },
  });
  res.status(201).json({
    admin: {
      id: admin.id,
      name: admin.name,
      email: admin.email,
      permissions: admin.permissions,
      isSuperAdmin: admin.isSuperAdmin,
    },
  });
}

// DELETE /api/admin/admins/:id
export async function deleteAdmin(req: Request, res: Response) {
  await assertSuperAdmin(req.adminId);
  const target = await prisma.admin.findUnique({ where: { id: req.params.id } });
  if (!target) throw new AppError("Admin não encontrado", 404);
  if (target.isSuperAdmin) throw new AppError("Não é possível remover um super-admin", 400);
  await prisma.admin.delete({ where: { id: target.id } });
  res.json({ ok: true });
}
