import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireUser } from "../../middlewares/auth";
import * as controller from "./match.controller";

export const matchRouter = Router();

matchRouter.use(requireUser);

matchRouter.get("/discovery", asyncHandler(controller.discovery));
matchRouter.post("/swipe", asyncHandler(controller.swipe));
matchRouter.post("/swipe/undo", asyncHandler(controller.undoSwipe));
matchRouter.get("/matches", asyncHandler(controller.matches));
matchRouter.get("/likes", asyncHandler(controller.likes));
matchRouter.get("/top-picks", asyncHandler(controller.topPicks));
matchRouter.get("/users/:id/profile", asyncHandler(controller.userCard));
