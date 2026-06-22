import { Router } from "express";
import { asyncHandler } from "../../lib/errors";
import { requireAdmin } from "../../middlewares/auth";
import * as c from "./monetization.controller";

// Rotas de gestão (painel) — montadas em /api/admin
export const monetizationAdminRouter = Router();
monetizationAdminRouter.use(requireAdmin);

monetizationAdminRouter.get("/products", asyncHandler(c.listProducts));
monetizationAdminRouter.post("/products", asyncHandler(c.createProduct));
monetizationAdminRouter.put("/products/:id", asyncHandler(c.updateProduct));
monetizationAdminRouter.delete("/products/:id", asyncHandler(c.deleteProduct));

monetizationAdminRouter.get("/gifts", asyncHandler(c.listGifts));
monetizationAdminRouter.post("/gifts", asyncHandler(c.createGift));
monetizationAdminRouter.post("/gifts/upload", asyncHandler(c.uploadGiftImage));
monetizationAdminRouter.put("/gifts/:id", asyncHandler(c.updateGift));
monetizationAdminRouter.delete("/gifts/:id", asyncHandler(c.deleteGift));

monetizationAdminRouter.get("/monetization", asyncHandler(c.getMonetization));
monetizationAdminRouter.put("/monetization", asyncHandler(c.updateMonetization));

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
