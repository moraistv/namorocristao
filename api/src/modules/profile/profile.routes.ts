import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as controller from "./profile.controller";

export const profileRouter = Router();

profileRouter.use(requireUser);

profileRouter.get("/profile", asyncHandler(controller.getMyProfile));
profileRouter.put("/profile", asyncHandler(controller.upsertMyProfile));
profileRouter.put("/location", asyncHandler(controller.updateLocation));
profileRouter.post("/online", asyncHandler(controller.setOnline));
profileRouter.post("/photos", asyncHandler(controller.uploadPhoto));
profileRouter.post("/boost", asyncHandler(controller.activateBoost));
profileRouter.post("/incognito", asyncHandler(controller.setIncognito));
profileRouter.get("/stats", asyncHandler(controller.getStats));
