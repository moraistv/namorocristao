-- Recompensas por anúncio premiado (substituem a loja paga).
-- As tabelas legadas products/monetization_settings permanecem intactas.

-- CreateEnum
CREATE TYPE "RewardKind" AS ENUM ('SUPERLIKES', 'BOOSTS', 'CREDITS');

-- CreateEnum
CREATE TYPE "RewardClaimStatus" AS ENUM ('PENDING', 'GRANTED', 'EXPIRED');

-- AlterTable
ALTER TABLE "ad_settings" ADD COLUMN     "rewardsMaxPerDay" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "rewardsRequireSsv" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "rewardsSsvAdUnit" TEXT,
ADD COLUMN     "rewardsSsvLastAdUnit" TEXT,
ADD COLUMN     "rewardsSsvLastAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "ad_rewards" (
    "id" TEXT NOT NULL,
    "kind" "RewardKind" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "amount" INTEGER NOT NULL DEFAULT 1,
    "dailyLimit" INTEGER NOT NULL DEFAULT 5,
    "cooldownSecs" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ad_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_reward_claims" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "rewardId" TEXT NOT NULL,
    "kind" "RewardKind" NOT NULL,
    "amount" INTEGER NOT NULL,
    "status" "RewardClaimStatus" NOT NULL DEFAULT 'PENDING',
    "verifiedBy" TEXT,
    "transactionId" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "grantedAt" TIMESTAMP(3),

    CONSTRAINT "ad_reward_claims_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ad_reward_claims_transactionId_key" ON "ad_reward_claims"("transactionId");

-- CreateIndex
CREATE INDEX "ad_reward_claims_userId_status_grantedAt_idx" ON "ad_reward_claims"("userId", "status", "grantedAt");

-- CreateIndex
CREATE INDEX "ad_reward_claims_rewardId_idx" ON "ad_reward_claims"("rewardId");

-- CreateIndex
CREATE INDEX "ad_reward_claims_status_grantedAt_idx" ON "ad_reward_claims"("status", "grantedAt");

-- CreateIndex
CREATE INDEX "ad_reward_claims_status_createdAt_idx" ON "ad_reward_claims"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "ad_reward_claims" ADD CONSTRAINT "ad_reward_claims_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_reward_claims" ADD CONSTRAINT "ad_reward_claims_rewardId_fkey" FOREIGN KEY ("rewardId") REFERENCES "ad_rewards"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Ofertas iniciais (editáveis no painel em Recompensas). Só entram em vigor quando
-- os anúncios e o formato Premiado estiverem ligados na página Anúncios.
INSERT INTO "ad_rewards" ("id", "kind", "title", "description", "amount", "dailyLimit", "cooldownSecs", "active", "sortOrder", "updatedAt") VALUES
    ('6f1d1a52-0c1b-4f7e-9a53-1c2b7d0a0001', 'SUPERLIKES', 'Super Likes grátis', 'Chame a atenção de quem você gostou.', 1, 5, 30, true, 1, CURRENT_TIMESTAMP),
    ('6f1d1a52-0c1b-4f7e-9a53-1c2b7d0a0002', 'BOOSTS', 'Boost grátis', 'Apareça para mais pessoas por um tempo.', 1, 3, 60, true, 2, CURRENT_TIMESTAMP),
    ('6f1d1a52-0c1b-4f7e-9a53-1c2b7d0a0003', 'CREDITS', 'Créditos para presentes', 'Use para enviar presentes nas conversas.', 2, 5, 30, true, 3, CURRENT_TIMESTAMP)
ON CONFLICT ("id") DO NOTHING;
