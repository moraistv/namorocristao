import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import {
  requireAdmin,
  requireSuperAdmin,
  requireUser,
} from "../../middlewares/auth";
import * as c from "./rewards.controller";

// App — montado em /api/me/rewards
export const rewardsUserRouter = Router();
rewardsUserRouter.use(requireUser);
rewardsUserRouter.get("/", asyncHandler(c.listMyRewards));
rewardsUserRouter.post("/claims/:claimId/complete", asyncHandler(c.completeMyReward));
rewardsUserRouter.post("/:rewardId/claims", asyncHandler(c.startMyReward));

// Callback do Google (SSV) — montado em /api/ads, sem login
export const adsCallbackRouter = Router();
adsCallbackRouter.get("/ssv", asyncHandler(c.ssvCallback));

// Painel — montado em /api/admin (somente super-admin). Guarda por caminho para
// não interceptar rotas de roteadores montados depois (ver monetization.routes.ts).
export const rewardsAdminRouter = Router();
rewardsAdminRouter.use(
  ["/rewards", "/reward-settings"],
  requireAdmin,
  requireSuperAdmin
);
rewardsAdminRouter.get("/rewards", asyncHandler(c.adminOverview));
rewardsAdminRouter.post("/rewards", asyncHandler(c.createReward));
rewardsAdminRouter.put("/rewards/:id", asyncHandler(c.updateReward));
rewardsAdminRouter.delete("/rewards/:id", asyncHandler(c.deleteReward));
rewardsAdminRouter.put("/reward-settings", asyncHandler(c.updateRewardSettings));
