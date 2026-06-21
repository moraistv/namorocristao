import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import * as c from "./dev.controller";

// Rotas de teste/simulação (sem auth). NÃO montar em produção.
export const devRouter = Router();

devRouter.post("/live-match/:email", asyncHandler(c.liveMatch));
devRouter.post("/live-likes/:email", asyncHandler(c.liveLikes));
devRouter.post("/live-message/:email", asyncHandler(c.liveMessage));
