import { createServer } from "http";
import { Server as SocketIOServer } from "socket.io";
import { createApp } from "./app";
import { env } from "./config/env";
import { prisma } from "./config/prisma";
import { setupSocket } from "./sockets";

async function main() {
  const app = createApp();
  const httpServer = createServer(app);

  // Socket.io (tempo real) — chat, presença, notificações.
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: env.corsOrigins.length ? env.corsOrigins : true,
      credentials: true,
    },
  });
  setupSocket(io);

  // Valida conexão com o banco antes de subir.
  await prisma.$connect();
  console.log("🗄️  Conectado ao PostgreSQL");

  httpServer.listen(env.PORT, () => {
    console.log(`🚀 API no ar em http://localhost:${env.PORT}`);
    console.log(`   Health: http://localhost:${env.PORT}/api/health`);
  });
}

main().catch((err) => {
  console.error("Falha ao iniciar a API:", err);
  process.exit(1);
});
