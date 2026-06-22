import { Router } from "express";
import { userAuthRouter } from "../modules/auth/user.auth.routes";
import { adminAuthRouter } from "../modules/auth/admin.auth.routes";
import { adminRouter } from "../modules/admin/admin.routes";
import { profileRouter } from "../modules/profile/profile.routes";
import { verificationRouter } from "../modules/verification/verification.routes";
import { matchRouter } from "../modules/match/match.routes";
import { chatRouter } from "../modules/chat/chat.routes";
import { moderationRouter } from "../modules/moderation/moderation.routes";
import { deviceRouter } from "../modules/device/device.routes";
import { photoAccessRouter } from "../modules/photoAccess/photoAccess.routes";
import { devRouter } from "../modules/dev/dev.routes";
import { monetizationAdminRouter, configPublicRouter } from "../modules/monetization/monetization.routes";
import { chatbotAdminRouter } from "../modules/chatbot/chatbot.routes";

export const router = Router();

router.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "namoro-cristao-api",
    time: new Date().toISOString(),
  });
});

// ── Autenticação (rotas públicas) — devem vir ANTES das rotas montadas em "/" ──
router.use("/auth", userAuthRouter); // app (usuários)
router.use("/admin/auth", adminAuthRouter); // painel (admins)

// ── Dev / simulação (somente desenvolvimento) — público, antes das rotas autenticadas ──
if (process.env.NODE_ENV !== "production") {
  router.use("/dev", devRouter);
}

// ── Painel admin (gestão) ──
router.use("/admin", adminRouter);
router.use("/admin", monetizationAdminRouter); // produtos, presentes, créditos, anúncios
router.use("/admin", chatbotAdminRouter); // chatbot (regras/analytics/settings) + bots

// ── Config pública (app lê em tempo real) ──
router.use("/config", configPublicRouter);

// ── Usuário atual ──
router.use("/me/verification", verificationRouter);
router.use("/me", profileRouter);

// ── App (autenticado) — montados em "/" ──
router.use("/", matchRouter); // discovery, swipe, matches
router.use("/", moderationRouter); // reports, blocks, delete-request
router.use("/", deviceRouter); // devices, notifications
router.use("/", photoAccessRouter); // fotos privadas (solicitar/aprovar)

// ── Chat ──
router.use("/matches", chatRouter); // /matches/:matchId/messages
