-- CreateEnum
CREATE TYPE "BotPersonality" AS ENUM ('ALL', 'SHY', 'FUNNY', 'EXTROVERT');

-- AlterTable (flags de bot no usuário)
ALTER TABLE "users" ADD COLUMN "isBot" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "botPersonality" "BotPersonality";
ALTER TABLE "users" ADD COLUMN "botAiEnabled" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable: regras do chatbot
CREATE TABLE "chatbot_rules" (
    "id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "personality" "BotPersonality" NOT NULL DEFAULT 'ALL',
    "priority" INTEGER NOT NULL DEFAULT 5,
    "keywords" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "responses" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "chatbot_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable: logs (analytics)
CREATE TABLE "chatbot_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "botUserId" TEXT,
    "message" TEXT NOT NULL,
    "matchedCategory" TEXT,
    "usedAi" BOOLEAN NOT NULL DEFAULT false,
    "language" TEXT NOT NULL DEFAULT 'pt',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "chatbot_logs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "chatbot_logs_createdAt_idx" ON "chatbot_logs"("createdAt");

-- CreateTable: configuração dos bots/IA (singleton id=1)
CREATE TABLE "bot_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "aiEnabled" BOOLEAN NOT NULL DEFAULT false,
    "aiProvider" TEXT NOT NULL DEFAULT 'openai',
    "aiModel" TEXT NOT NULL DEFAULT 'gpt-4o-mini',
    "aiApiKey" TEXT,
    "aiSystemPrompt" TEXT NOT NULL DEFAULT 'Voce e uma pessoa crista simpatica em um app de namoro. Responda de forma curta, calorosa e natural, em portugues do Brasil.',
    "replyMinMs" INTEGER NOT NULL DEFAULT 1200,
    "replyMaxMs" INTEGER NOT NULL DEFAULT 3500,
    "fallbackText" TEXT NOT NULL DEFAULT 'Que interessante! Me conta mais sobre voce 😊',
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "bot_settings_pkey" PRIMARY KEY ("id")
);
