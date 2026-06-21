import express from "express";
import cors from "cors";
import helmet from "helmet";
import { env } from "./config/env";
import { UPLOADS_DIR } from "./config/paths";
import { router } from "./routes";
import { errorHandler } from "./middlewares/errorHandler";

export function createApp() {
  const app = express();

  app.set("trust proxy", true);

  app.use(helmet({ crossOriginResourcePolicy: false }));
  app.use(
    cors({
      origin: env.corsOrigins.length ? env.corsOrigins : true,
      credentials: true,
    })
  );
  app.use(express.json({ limit: "12mb" }));

  // Arquivos enviados (fotos de perfil) — dev: disco local.
  app.use("/uploads", express.static(UPLOADS_DIR));

  app.use("/api", router);

  app.use(errorHandler);

  return app;
}
