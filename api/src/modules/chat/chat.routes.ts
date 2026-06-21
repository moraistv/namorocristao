import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as controller from "./chat.controller";

// Montado em /api/matches
export const chatRouter = Router();

chatRouter.use(requireUser);

chatRouter.get("/:matchId/messages", asyncHandler(controller.history));
chatRouter.post("/:matchId/messages", asyncHandler(controller.send));
chatRouter.post("/:matchId/gifts", asyncHandler(controller.sendGift));
chatRouter.post("/:matchId/messages/read", asyncHandler(controller.read));
