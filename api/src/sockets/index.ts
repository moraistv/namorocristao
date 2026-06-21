import { Server as SocketIOServer, Socket } from "socket.io";
import { verifyAccessToken } from "../lib/jwt";
import { prisma } from "../config/prisma";
import * as chat from "../modules/chat/chat.service";

let ioRef: SocketIOServer | null = null;

export function getIO(): SocketIOServer | null {
  return ioRef;
}

function userRoom(userId: string) {
  return `user:${userId}`;
}
function matchRoom(matchId: string) {
  return `match:${matchId}`;
}

// Cache leve matchId -> participantes (evita consulta a cada evento de digitação).
const matchParticipants = new Map<string, [string, string]>();
async function getOtherParticipant(
  matchId: string,
  userId: string
): Promise<string | null> {
  let pair = matchParticipants.get(matchId);
  if (!pair) {
    const m = await prisma.match.findUnique({
      where: { id: matchId },
      select: { userAId: true, userBId: true },
    });
    if (!m) return null;
    pair = [m.userAId, m.userBId];
    matchParticipants.set(matchId, pair);
  }
  return pair[0] === userId ? pair[1] : pair[0];
}

export function setupSocket(io: SocketIOServer) {
  ioRef = io;

  // Autenticação no handshake: { auth: { token } }.
  io.use((socket, next) => {
    try {
      const token =
        (socket.handshake.auth?.token as string) ||
        (socket.handshake.headers.authorization || "").replace("Bearer ", "");
      const payload = verifyAccessToken(token);
      if (payload.type !== "user") {
        return next(new Error("Apenas usuários do app podem conectar"));
      }
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
    socket.on("match:join", async ({ matchId }, cb) => {
      try {
        await chat.assertMembership(userId, matchId);
        socket.join(matchRoom(matchId));
        const marked = await chat.markRead(userId, matchId);
        if (marked > 0) {
          io.to(matchRoom(matchId)).emit("messages:read", { matchId, by: userId });
        }
        cb?.({ ok: true });
      } catch (e) {
        cb?.({ ok: false, error: (e as Error).message });
      }
    });

    socket.on("match:leave", ({ matchId }) => {
      socket.leave(matchRoom(matchId));
    });

    // Enviar mensagem.
    socket.on("message:send", async ({ matchId, content, type }, cb) => {
      try {
        const { message, otherId } = await chat.sendMessage({
          senderId: userId,
          matchId,
          content,
          type,
        });
        // Entrega na sala do match e na sala pessoal do destinatário.
        io.to(matchRoom(matchId)).emit("message:new", message);
        io.to(userRoom(otherId)).emit("message:new", message);
        cb?.({ ok: true, message });
      } catch (e) {
        cb?.({ ok: false, error: (e as Error).message });
      }
    });

    // Marcar como lido.
    socket.on("message:read", async ({ matchId }, cb) => {
      try {
        const marked = await chat.markRead(userId, matchId);
        io.to(matchRoom(matchId)).emit("messages:read", { matchId, by: userId });
        cb?.({ ok: true, marked });
      } catch (e) {
        cb?.({ ok: false, error: (e as Error).message });
      }
    });

    // Indicador de digitação. Entrega na sala pessoal do outro usuário,
    // assim funciona tanto no chat aberto quanto na lista de conversas.
    socket.on("typing", async ({ matchId, isTyping }) => {
      const otherId = await getOtherParticipant(matchId, userId);
      if (otherId) {
        io.to(userRoom(otherId)).emit("typing", { matchId, userId, isTyping });
      }
    });

    socket.on("disconnect", () => {
      console.log(`🔌 socket desconectado: user=${userId}`);
    });
  });
}

/** Emite um evento para a sala pessoal de um usuário (ex.: novo match). */
export function emitToUser(userId: string, event: string, payload: unknown) {
  ioRef?.to(userRoom(userId)).emit(event, payload);
}

/** Emite um evento para TODOS os clientes conectados (ex.: config de anúncios mudou). */
export function emitToAll(event: string, payload: unknown) {
  ioRef?.emit(event, payload);
}
