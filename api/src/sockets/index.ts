import { Server as SocketIOServer, Socket } from "socket.io";
import { z } from "zod";
import { assertActiveUserAccount } from "../lib/accountAccess";
import { verifyAccessToken } from "../lib/jwt";
import * as chat from "../modules/chat/chat.service";

let ioRef: SocketIOServer | null = null;

const matchPayloadSchema = z.object({
  matchId: z.string().uuid(),
});
const messagePayloadSchema = matchPayloadSchema.extend({
  content: z.string().trim().min(1).max(10000),
  type: z
    .enum(["TEXT", "IMAGE", "AUDIO", "GIFT", "PHOTO_REQUEST"])
    .optional(),
});
const typingPayloadSchema = matchPayloadSchema.extend({
  isTyping: z.boolean(),
});

type SocketAck = (payload: unknown) => void;

function acknowledge(callback: unknown, payload: unknown): void {
  if (typeof callback === "function") {
    (callback as SocketAck)(payload);
  }
}

function socketErrorMessage(error: unknown): string {
  return error instanceof z.ZodError
    ? "Payload inválido"
    : error instanceof Error
      ? error.message
      : "Erro inesperado";
}

export function getIO(): SocketIOServer | null {
  return ioRef;
}

function userRoom(userId: string) {
  return `user:${userId}`;
}
function matchRoom(matchId: string) {
  return `match:${matchId}`;
}

export function setupSocket(io: SocketIOServer) {
  ioRef = io;

  // Autenticação no handshake: valida o token e o estado atual da conta.
  io.use(async (socket, next) => {
    try {
      const authToken = socket.handshake.auth?.token;
      const authorization = socket.handshake.headers.authorization;
      const token =
        typeof authToken === "string"
          ? authToken
          : typeof authorization === "string"
            ? authorization.replace("Bearer ", "")
            : "";
      const payload = verifyAccessToken(token);
      if (payload.type !== "user") {
        return next(new Error("Apenas usuários do app podem conectar"));
      }
      await assertActiveUserAccount(payload.sub);
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error("Não autorizado"));
    }
  });

  io.on("connection", (socket: Socket) => {
    const userId: string = socket.data.userId;
    socket.join(userRoom(userId));
    console.log(`🔌 socket conectado: user=${userId}`);

    // Entrar na sala de um match (e marcar como lido).
    socket.on("match:join", async (payload, callback) => {
      try {
        const { matchId } = matchPayloadSchema.parse(payload);
        await chat.assertMembership(userId, matchId);
        socket.join(matchRoom(matchId));
        const marked = await chat.markRead(userId, matchId);
        if (marked > 0) {
          io.to(matchRoom(matchId)).emit("messages:read", {
            matchId,
            by: userId,
          });
        }
        acknowledge(callback, { ok: true });
      } catch (error) {
        acknowledge(callback, {
          ok: false,
          error: socketErrorMessage(error),
        });
      }
    });

    socket.on("match:leave", (payload, callback) => {
      const parsed = matchPayloadSchema.safeParse(payload);
      if (!parsed.success) {
        acknowledge(callback, { ok: false, error: "Payload inválido" });
        return;
      }
      socket.leave(matchRoom(parsed.data.matchId));
      acknowledge(callback, { ok: true });
    });

    // Enviar mensagem.
    socket.on("message:send", async (payload, callback) => {
      try {
        const { matchId, content, type } = messagePayloadSchema.parse(payload);
        const { message, otherId } = await chat.sendMessage({
          senderId: userId,
          matchId,
          content,
          type,
        });
        // Entrega na sala do match e na sala pessoal do destinatário.
        io.to(matchRoom(matchId)).emit("message:new", message);
        io.to(userRoom(otherId)).emit("message:new", message);
        acknowledge(callback, { ok: true, message });
      } catch (error) {
        acknowledge(callback, {
          ok: false,
          error: socketErrorMessage(error),
        });
      }
    });

    // Marcar como lido.
    socket.on("message:read", async (payload, callback) => {
      try {
        const { matchId } = matchPayloadSchema.parse(payload);
        const marked = await chat.markRead(userId, matchId);
        io.to(matchRoom(matchId)).emit("messages:read", {
          matchId,
          by: userId,
        });
        acknowledge(callback, { ok: true, marked });
      } catch (error) {
        acknowledge(callback, {
          ok: false,
          error: socketErrorMessage(error),
        });
      }
    });

    // Typing exige match ativo, participação e ausência de bloqueio.
    socket.on("typing", async (payload, callback) => {
      try {
        const { matchId, isTyping } = typingPayloadSchema.parse(payload);
        const { otherId } = await chat.assertMembership(userId, matchId);
        io.to(userRoom(otherId)).emit("typing", {
          matchId,
          userId,
          isTyping,
        });
        acknowledge(callback, { ok: true });
      } catch (error) {
        acknowledge(callback, {
          ok: false,
          error: socketErrorMessage(error),
        });
      }
    });

    socket.on("disconnect", () => {
      console.log(`🔌 socket desconectado: user=${userId}`);
    });
  });
}

/** Encerra imediatamente todas as conexões Socket.IO de um usuário. */
export function disconnectUser(userId: string) {
  ioRef?.in(userRoom(userId)).disconnectSockets(true);
}

/** Emite um evento para a sala pessoal de um usuário (ex.: novo match). */
export function emitToUser(userId: string, event: string, payload: unknown) {
  ioRef?.to(userRoom(userId)).emit(event, payload);
}

/** Emite um evento para TODOS os clientes conectados (ex.: config de anúncios mudou). */
export function emitToAll(event: string, payload: unknown) {
  ioRef?.emit(event, payload);
}
