import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as c from "./verification.controller";

// Montado em /api/me/verification
export const verificationRouter = Router();

verificationRouter.use(requireUser);

verificationRouter.post("/", asyncHandler(c.submit));
verificationRouter.get("/", asyncHandler(c.myStatus));
