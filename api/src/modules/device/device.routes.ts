import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as c from "./device.controller";

// Montado em /api
export const deviceRouter = Router();

deviceRouter.use(requireUser);

deviceRouter.post("/devices", asyncHandler(c.registerDevice));
deviceRouter.delete("/devices", asyncHandler(c.removeDevice));
deviceRouter.get("/notifications", asyncHandler(c.listNotifications));
deviceRouter.post("/notifications/:id/read", asyncHandler(c.readNotification));
deviceRouter.post("/notifications/click", asyncHandler(c.trackNotificationClick));
