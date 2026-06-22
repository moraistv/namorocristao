-- CreateTable: campanhas de notificação push enviadas pelo painel
CREATE TABLE "notification_broadcasts" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "audience" TEXT NOT NULL,
    "imageUrl" TEXT,
    "actionType" TEXT,
    "actionValue" TEXT,
    "targetedCount" INTEGER NOT NULL DEFAULT 0,
    "sentCount" INTEGER NOT NULL DEFAULT 0,
    "deliveredCount" INTEGER NOT NULL DEFAULT 0,
    "clickedCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "notification_broadcasts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "notification_broadcasts_createdAt_idx" ON "notification_broadcasts"("createdAt");
