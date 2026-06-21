import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as controller from "./user.auth.controller";

export const userAuthRouter = Router();

userAuthRouter.post("/register", asyncHandler(controller.register));
userAuthRouter.post("/login", asyncHandler(controller.login));
userAuthRouter.post("/request-code", asyncHandler(controller.requestCode));
userAuthRouter.post("/login-code", asyncHandler(controller.loginWithCode));
userAuthRouter.post("/google", asyncHandler(controller.loginWithGoogle));
userAuthRouter.post("/refresh", asyncHandler(controller.refresh));
userAuthRouter.get("/me", requireUser, asyncHandler(controller.me));
