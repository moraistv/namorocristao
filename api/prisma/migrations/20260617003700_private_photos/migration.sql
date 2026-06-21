-- CreateEnum
CREATE TYPE "PhotoAccessStatus" AS ENUM ('PENDING', 'APPROVED', 'DENIED');

-- AlterEnum
ALTER TYPE "MessageType" ADD VALUE 'PHOTO_REQUEST';

-- AlterTable
ALTER TABLE "profiles" ADD COLUMN     "lockedPhotos" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateTable
CREATE TABLE "photo_access_requests" (
    "id" TEXT NOT NULL,
    "requesterId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "status" "PhotoAccessStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "photo_access_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "photo_access_requests_ownerId_idx" ON "photo_access_requests"("ownerId");

-- CreateIndex
CREATE INDEX "photo_access_requests_requesterId_idx" ON "photo_access_requests"("requesterId");

-- CreateIndex
CREATE UNIQUE INDEX "photo_access_requests_requesterId_ownerId_key" ON "photo_access_requests"("requesterId", "ownerId");
