import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { emitToUser, getIO } from "../../sockets";

const requestSchema = z.object({ ownerId: z.string().uuid() });

/** Acha o match ativo entre dois usuários. */
async function findActiveMatch(a: string, b: string) {
  const [userAId, userBId] = a < b ? [a, b] : [b, a];
  return prisma.match.findFirst({
    where: { userAId, userBId, isActive: true },
  });
}

function emitMessage(matchId: string, message: unknown, toUserId: string) {
  const io = getIO();
  io?.to(`match:${matchId}`).emit("message:new", message);
  emitToUser(toUserId, "message:new", message);
}

// POST /api/photo-access/request  { ownerId }
export async function requestAccess(req: Request, res: Response) {
  const { ownerId } = requestSchema.parse(req.body);
  const requesterId = req.userId!;
  if (ownerId === requesterId) throw new AppError("Pedido inválido", 400);

  const match = await findActiveMatch(requesterId, ownerId);
  if (!match) throw new AppError("Vocês precisam ter um match", 403);

  const owner = await prisma.profile.findUnique({ where: { userId: ownerId } });
  if (!owner || owner.lockedPhotos.length === 0) {
    throw new AppError("Este perfil não tem fotos privadas", 400);
  }

  const request = await prisma.photoAccessRequest.upsert({
    where: { requesterId_ownerId: { requesterId, ownerId } },
    create: { requesterId, ownerId, status: "PENDING" },
    update: { status: "PENDING" },
  });

  // Mensagem especial no chat (o dono verá Aprovar/Negar).
  const message = await prisma.message.create({
    data: {
      matchId: match.id,
      senderId: requesterId,
      type: "PHOTO_REQUEST",
      content: request.id, // guarda o id do pedido
    },
  });
  emitMessage(match.id, message, ownerId);

  res.status(201).json({ request, matchId: match.id });
}

const decideSchema = z.object({ approve: z.boolean() });

// POST /api/photo-access/:id/decide  { approve }
export async function decide(req: Request, res: Response) {
  const { approve } = decideSchema.parse(req.body);
  const ownerId = req.userId!;
  const request = await prisma.photoAccessRequest.findUnique({
    where: { id: req.params.id },
  });
  if (!request) throw new AppError("Pedido não encontrado", 404);
  if (request.ownerId !== ownerId) throw new AppError("Sem permissão", 403);

  const updated = await prisma.photoAccessRequest.update({
    where: { id: request.id },
    data: { status: approve ? "APPROVED" : "DENIED" },
  });

  // Avisa o solicitante no chat.
  const match = await findActiveMatch(request.requesterId, ownerId);
  if (match) {
    const ownerProfile = await prisma.profile.findUnique({ where: { userId: ownerId } });
    const msg = await prisma.message.create({
      data: {
        matchId: match.id,
        senderId: ownerId,
        type: "TEXT",
        content: approve
          ? "🔓 Liberei minhas fotos privadas para você!"
          : "Preferi não liberar minhas fotos privadas por enquanto.",
      },
    });
    emitMessage(match.id, msg, request.requesterId);
    void ownerProfile;
  }

  res.json({ request: updated });
}

// GET /api/photo-access/can-see/:ownerId
export async function canSee(req: Request, res: Response) {
  const r = await prisma.photoAccessRequest.findUnique({
    where: { requesterId_ownerId: { requesterId: req.userId!, ownerId: req.params.ownerId } },
  });
  res.json({ canSee: r?.status === "APPROVED", status: r?.status ?? null });
}

// GET /api/users/:ownerId/locked-photos  (só se aprovado)
export async function lockedPhotos(req: Request, res: Response) {
  const ownerId = req.params.ownerId;
  const r = await prisma.photoAccessRequest.findUnique({
    where: { requesterId_ownerId: { requesterId: req.userId!, ownerId } },
  });
  if (r?.status !== "APPROVED") throw new AppError("Acesso não liberado", 403);
  const owner = await prisma.profile.findUnique({ where: { userId: ownerId } });
  res.json({ photos: owner?.lockedPhotos ?? [] });
}
