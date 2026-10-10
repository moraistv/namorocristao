import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireAdmin, requireSuperAdmin } from "../../middlewares/auth";
import * as c from "./monetization.controller";

// Presentes, anúncios e versos exigem super-admin. A guarda é por caminho: um
// `use` sem path interceptaria TODA requisição /admin/* que passa por aqui e
// bloquearia rotas de roteadores montados depois (ex.: analytics do bot, que o
// admin comum pode abrir).
export const monetizationAdminRouter = Router();
monetizationAdminRouter.use(
  ["/gifts", "/ads", "/verses"],
  requireAdmin,
  requireSuperAdmin
);

monetizationAdminRouter.get("/gifts", asyncHandler(c.listGifts));
monetizationAdminRouter.post("/gifts", asyncHandler(c.createGift));
monetizationAdminRouter.post("/gifts/upload", asyncHandler(c.uploadGiftImage));
monetizationAdminRouter.put("/gifts/:id", asyncHandler(c.updateGift));
monetizationAdminRouter.delete("/gifts/:id", asyncHandler(c.deleteGift));

monetizationAdminRouter.get("/ads", asyncHandler(c.getAds));
monetizationAdminRouter.put("/ads", asyncHandler(c.updateAds));

monetizationAdminRouter.get("/verses", asyncHandler(c.listVerses));
monetizationAdminRouter.post("/verses", asyncHandler(c.createVerse));
monetizationAdminRouter.put("/verses/:id", asyncHandler(c.updateVerse));
monetizationAdminRouter.delete("/verses/:id", asyncHandler(c.deleteVerse));

// Rotas públicas (app lê em tempo real) — montadas em /api/config
export const configPublicRouter = Router();
configPublicRouter.get("/store", asyncHandler(c.publicStore));
configPublicRouter.get("/ads", asyncHandler(c.publicAds));
configPublicRouter.get("/verse", asyncHandler(c.publicDailyVerse));
configPublicRouter.get("/verses", asyncHandler(c.publicVerses));
