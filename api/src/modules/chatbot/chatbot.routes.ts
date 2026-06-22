import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireAdmin } from "../../middlewares/auth";
import * as c from "./chatbot.controller";

// Gestão do chatbot/bots (painel) — montado em /api/admin
export const chatbotAdminRouter = Router();
chatbotAdminRouter.use(requireAdmin);

// Regras
chatbotAdminRouter.get("/chatbot/rules", asyncHandler(c.listRules));
chatbotAdminRouter.post("/chatbot/rules", asyncHandler(c.createRule));
chatbotAdminRouter.put("/chatbot/rules/:id", asyncHandler(c.updateRule));
chatbotAdminRouter.delete("/chatbot/rules/:id", asyncHandler(c.deleteRule));

// Analytics
chatbotAdminRouter.get("/chatbot/analytics", asyncHandler(c.analytics));

// Configuração de IA
chatbotAdminRouter.get("/chatbot/settings", asyncHandler(c.getSettings));
chatbotAdminRouter.put("/chatbot/settings", asyncHandler(c.updateSettings));

// Bots / Modelos
chatbotAdminRouter.get("/bots", asyncHandler(c.listBots));
chatbotAdminRouter.post("/bots", asyncHandler(c.createBot));
chatbotAdminRouter.put("/bots/:userId", asyncHandler(c.updateBot));
chatbotAdminRouter.delete("/bots/:userId", asyncHandler(c.deleteBot));
chatbotAdminRouter.post("/bots/:userId/broadcast", asyncHandler(c.broadcastFromBot));
