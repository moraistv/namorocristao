-- CreateTable: histórico de disparos dos modelos (broadcast)
CREATE TABLE "bot_broadcasts" (
    "id" TEXT NOT NULL,
    "botUserId" TEXT NOT NULL,
    "audience" TEXT NOT NULL,
    "messageType" TEXT NOT NULL DEFAULT 'text',
    "text" TEXT,
    "imageUrl" TEXT,
    "targetedCount" INTEGER NOT NULL DEFAULT 0,
    "sentCount" INTEGER NOT NULL DEFAULT 0,
    "deliveredCount" INTEGER NOT NULL DEFAULT 0,
    "clickedCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sentAt" TIMESTAMP(3),
    CONSTRAINT "bot_broadcasts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "bot_broadcasts_botUserId_idx" ON "bot_broadcasts"("botUserId");
CREATE INDEX "bot_broadcasts_createdAt_idx" ON "bot_broadcasts"("createdAt");
