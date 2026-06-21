import { Request, Response } from "express";
import * as service from "./chat.service";
import { emitToUser } from "../../sockets";

// GET /api/matches/:matchId/messages?limit=&before=
export async function history(req: Request, res: Response) {
  const { matchId } = req.params;
  const limit = req.query.limit ? Number(req.query.limit) : undefined;
  const before = req.query.before ? String(req.query.before) : undefined;
  const messages = await service.getHistory(req.userId!, matchId, {
    limit,
    before,
  });
  res.json({ messages });
}

// POST /api/matches/:matchId/messages/read
export async function read(req: Request, res: Response) {
  const { matchId } = req.params;
  const count = await service.markRead(req.userId!, matchId);
  // Avisa o outro lado em tempo real (vira ✓✓).
  emitToUser(req.userId!, "messages:read", { matchId, by: req.userId });
  res.json({ marked: count });
}

// POST /api/matches/:matchId/messages  (envio confiável; emite em tempo real)
export async function send(req: Request, res: Response) {
  const { matchId } = req.params;
  const { content, type } = req.body ?? {};
  const { message, otherId } = await service.sendMessage({
    senderId: req.userId!,
    matchId,
    content,
    type,
  });
  // Entrega em tempo real para os dois lados (cada um está na sua sala pessoal).
  emitToUser(otherId, "message:new", message);
  emitToUser(req.userId!, "message:new", message);
  res.status(201).json({ message });
}

// POST /api/matches/:matchId/gifts  { giftId }  (envia presente, debita créditos)
export async function sendGift(req: Request, res: Response) {
  const { matchId } = req.params;
  const { giftId } = req.body ?? {};
  const { message, otherId, credits } = await service.sendGift({
    senderId: req.userId!,
    matchId,
    giftId,
  });
  emitToUser(otherId, "message:new", message);
  emitToUser(req.userId!, "message:new", message);
  res.status(201).json({ message, credits });
}
