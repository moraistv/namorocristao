import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireAdmin } from "../../middlewares/auth";
import * as controller from "./admin.auth.controller";

export const adminAuthRouter = Router();

adminAuthRouter.get("/needs-setup", asyncHandler(controller.needsSetup));
adminAuthRouter.post("/register-super", asyncHandler(controller.registerSuperAdmin));
adminAuthRouter.post("/login", asyncHandler(controller.login));
adminAuthRouter.post("/refresh", asyncHandler(controller.refresh));
adminAuthRouter.get("/me", requireAdmin, asyncHandler(controller.me));
