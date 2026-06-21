-- AlterTable
ALTER TABLE "app_settings" ADD COLUMN     "boostDurationMin" INTEGER NOT NULL DEFAULT 30,
ADD COLUMN     "dailyVerseEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "freeDailyLikes" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "incognitoPremiumOnly" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "rewindPremiumOnly" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "superLikeMessageEnabled" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "interactions" ADD COLUMN     "note" TEXT;

-- AlterTable
ALTER TABLE "profiles" ADD COLUMN     "boostUntil" TIMESTAMP(3),
ADD COLUMN     "incognito" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "prompts" JSONB;

-- CreateTable
CREATE TABLE "daily_verses" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "daily_verses_pkey" PRIMARY KEY ("id")
);
