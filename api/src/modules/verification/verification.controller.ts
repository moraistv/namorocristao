import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";

const submitSchema = z.object({
  selfieUrl: z.string().url(),
});

// POST /api/me/verification
export async function submit(req: Request, res: Response) {
  const { selfieUrl } = submitSchema.parse(req.body);
  const form = await prisma.verificationForm.create({
    data: { userId: req.userId!, selfieUrl, status: "PENDING" },
  });
  res.status(201).json({ verification: form });
}

// GET /api/me/verification
export async function myStatus(req: Request, res: Response) {
  const form = await prisma.verificationForm.findFirst({
    where: { userId: req.userId! },
    orderBy: { createdAt: "desc" },
  });
  res.json({ verification: form ?? null });
}
