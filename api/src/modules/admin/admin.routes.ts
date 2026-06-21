import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireAdmin } from "../../middlewares/auth";
import * as c from "./admin.controller";

// Montado em /api/admin (rotas de gestão; auth do admin fica em /api/admin/auth)
export const adminRouter = Router();

adminRouter.use(requireAdmin);

adminRouter.get("/dashboard", asyncHandler(c.dashboard));
adminRouter.get("/stats/signups", asyncHandler(c.signupsSeries));
adminRouter.get("/stats/locations", asyncHandler(c.locationStats));

adminRouter.get("/users", asyncHandler(c.listUsers));
adminRouter.get("/users/:userId", asyncHandler(c.userDetail));
adminRouter.post("/users/:userId/ban", asyncHandler(c.banUser));
adminRouter.delete("/users/:userId/ban", asyncHandler(c.unbanUser));
adminRouter.post("/users/:userId/suspend", asyncHandler(c.suspendUser));
adminRouter.delete("/users/:userId/suspend", asyncHandler(c.unsuspendUser));
adminRouter.post("/users/:userId/premium", asyncHandler(c.grantPremium));
adminRouter.delete("/users/:userId/premium", asyncHandler(c.revokePremium));
adminRouter.post("/users/:userId/credits", asyncHandler(c.addCredits));
adminRouter.post("/users/:userId/verify", asyncHandler(c.setVerified));

adminRouter.get("/reports", asyncHandler(c.listReports));
adminRouter.get("/reports/:id", asyncHandler(c.reportDetail));
adminRouter.post("/reports/:id", asyncHandler(c.updateReport));

adminRouter.get("/verifications", asyncHandler(c.listVerifications));
adminRouter.post("/verifications/:id/review", asyncHandler(c.reviewVerification));

adminRouter.get("/account-delete-requests", asyncHandler(c.listDeleteRequests));
adminRouter.post(
  "/account-delete-requests/:userId/process",
  asyncHandler(c.processDeleteRequest)
);

adminRouter.get("/settings", asyncHandler(c.getSettings));
adminRouter.put("/settings", asyncHandler(c.updateSettings));

adminRouter.post("/notifications/broadcast", asyncHandler(c.broadcastNotification));
adminRouter.get("/notifications/recent", asyncHandler(c.recentNotifications));

adminRouter.get("/admins", asyncHandler(c.listAdmins));
adminRouter.post("/admins", asyncHandler(c.createAdmin));
adminRouter.delete("/admins/:id", asyncHandler(c.deleteAdmin));
