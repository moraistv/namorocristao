-- Recompensa "VIP por tempo": o anúncio premiado concede horas de VIP.
-- A oferta inicial fica na migration seguinte: um valor novo de enum não pode
-- ser usado na mesma transação em que foi criado.

-- AlterEnum
ALTER TYPE "RewardKind" ADD VALUE 'VIP';

-- AlterTable: se o VIP ganho por anúncio também esconde banner e intersticial
-- (desligado: esses anúncios continuam durante o VIP por anúncio).
ALTER TABLE "ad_settings" ADD COLUMN     "rewardsVipHidesAds" BOOLEAN NOT NULL DEFAULT false;
