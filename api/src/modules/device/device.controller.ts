import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";

const tokenSchema = z.object({
  token: z.string().min(5),
  platform: z.string().max(20).optional(),
});

// POST /api/devices  (registra token FCM)
export async function registerDevice(req: Request, res: Response) {
  const { token, platform } = tokenSchema.parse(req.body);
  const device = await prisma.deviceToken.upsert({
    where: { token },
    create: { userId: req.userId!, token, platform },
    update: { userId: req.userId!, platform },
  });
  res.status(201).json({ device });
}

// DELETE /api/devices  (remove token)
export async function removeDevice(req: Request, res: Response) {
  const { token } = z.object({ token: z.string() }).parse(req.body);
  await prisma.deviceToken.deleteMany({ where: { token, userId: req.userId! } });
  res.json({ ok: true });
}

// GET /api/notifications
export async function listNotifications(req: Request, res: Response) {
  const notifications = await prisma.notification.findMany({
    where: { userId: req.userId! },
    orderBy: { createdAt: "desc" },
    take: 50,
  });
  res.json({ notifications });
}

// POST /api/notifications/:id/read
export async function readNotification(req: Request, res: Response) {
  await prisma.notification.updateMany({
    where: { id: req.params.id, userId: req.userId! },
    data: { isRead: true },
  });
  res.json({ ok: true });
}
