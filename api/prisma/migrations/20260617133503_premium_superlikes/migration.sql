-- AlterTable
ALTER TABLE "users" ADD COLUMN     "boostsRemaining" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "premiumPlan" TEXT,
ADD COLUMN     "premiumUntil" TIMESTAMP(3),
ADD COLUMN     "superLikesResetAt" TIMESTAMP(3),
ADD COLUMN     "superLikesUsedToday" INTEGER NOT NULL DEFAULT 0;
