import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as c from "./moderation.controller";

// Montado em /api
export const moderationRouter = Router();

moderationRouter.use(requireUser);

moderationRouter.post("/reports", asyncHandler(c.createReport));
moderationRouter.get("/blocks", asyncHandler(c.listBlocks));
moderationRouter.post("/blocks", asyncHandler(c.createBlock));
moderationRouter.delete("/blocks/:blockedId", asyncHandler(c.removeBlock));
moderationRouter.post("/me/delete-request", asyncHandler(c.requestAccountDeletion));
moderationRouter.delete("/me/delete-request", asyncHandler(c.cancelAccountDeletion));
