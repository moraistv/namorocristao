import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";

const reportSchema = z.object({
  reportedId: z.string().uuid(),
  reason: z.string().min(3).max(500),
});

const blockSchema = z.object({
  blockedId: z.string().uuid(),
});

/** Encerra (desativa) o match entre dois usuários, se existir. */
async function endMatchBetween(a: string, b: string) {
  const [userAId, userBId] = a < b ? [a, b] : [b, a];
  await prisma.match.updateMany({
    where: { userAId, userBId },
    data: { isActive: false },
  });
}

// POST /api/reports
export async function createReport(req: Request, res: Response) {
  const { reportedId, reason } = reportSchema.parse(req.body);
  if (reportedId === req.userId) {
    throw new AppError("Não é possível denunciar a si mesmo", 400);
  }
  const report = await prisma.report.create({
    data: { reporterId: req.userId!, reportedId, reason },
  });
  res.status(201).json({ report });
}

// POST /api/blocks
export async function createBlock(req: Request, res: Response) {
  const { blockedId } = blockSchema.parse(req.body);
  if (blockedId === req.userId) {
    throw new AppError("Não é possível bloquear a si mesmo", 400);
  }
  const block = await prisma.block.upsert({
    where: { blockerId_blockedId: { blockerId: req.userId!, blockedId } },
    create: { blockerId: req.userId!, blockedId },
    update: {},
  });
  await endMatchBetween(req.userId!, blockedId);
  res.status(201).json({ block });
}

// DELETE /api/blocks/:blockedId
export async function removeBlock(req: Request, res: Response) {
  const blockedId = req.params.blockedId;
  await prisma.block.deleteMany({
    where: { blockerId: req.userId!, blockedId },
  });
  res.json({ ok: true });
}

// GET /api/blocks
export async function listBlocks(req: Request, res: Response) {
  const blocks = await prisma.block.findMany({
    where: { blockerId: req.userId! },
    orderBy: { createdAt: "desc" },
  });
  res.json({ blocks });
}

// POST /api/me/delete-request
export async function requestAccountDeletion(req: Request, res: Response) {
  const reqDel = await prisma.accountDeleteRequest.upsert({
    where: { userId: req.userId! },
    create: { userId: req.userId!, status: "PENDING" },
    update: { status: "PENDING" },
  });
  res.status(201).json({ request: reqDel });
}

// DELETE /api/me/delete-request
export async function cancelAccountDeletion(req: Request, res: Response) {
  await prisma.accountDeleteRequest.updateMany({
    where: { userId: req.userId!, status: "PENDING" },
    data: { status: "CANCELED" },
  });
  res.json({ ok: true });
}
