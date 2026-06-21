import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as c from "./photoAccess.controller";

// Montado em /api
export const photoAccessRouter = Router();

photoAccessRouter.use(requireUser);

photoAccessRouter.post("/photo-access/request", asyncHandler(c.requestAccess));
photoAccessRouter.post("/photo-access/:id/decide", asyncHandler(c.decide));
photoAccessRouter.get("/photo-access/can-see/:ownerId", asyncHandler(c.canSee));
photoAccessRouter.get("/users/:ownerId/locked-photos", asyncHandler(c.lockedPhotos));
