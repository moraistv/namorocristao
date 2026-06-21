-- CreateEnum
CREATE TYPE "ProductKind" AS ENUM ('PREMIUM', 'CREDITS', 'SUPERLIKES', 'BOOSTS');

-- CreateTable
CREATE TABLE "products" (
    "id" TEXT NOT NULL,
    "kind" "ProductKind" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "googleProductId" TEXT,
    "priceCents" INTEGER NOT NULL DEFAULT 0,
    "amount" INTEGER NOT NULL DEFAULT 0,
    "durationDays" INTEGER,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gifts" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "costCredits" INTEGER NOT NULL DEFAULT 1,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "bannerEnabled" BOOLEAN NOT NULL DEFAULT true,
    "interstitialEnabled" BOOLEAN NOT NULL DEFAULT true,
    "rewardedEnabled" BOOLEAN NOT NULL DEFAULT true,
    "androidBannerId" TEXT,
    "androidInterstitialId" TEXT,
    "androidRewardedId" TEXT,
    "interstitialEverySecs" INTEGER NOT NULL DEFAULT 120,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ad_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "monetization_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "creditPriceCents" INTEGER NOT NULL DEFAULT 100,
    "currency" TEXT NOT NULL DEFAULT 'BRL',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "monetization_settings_pkey" PRIMARY KEY ("id")
);
