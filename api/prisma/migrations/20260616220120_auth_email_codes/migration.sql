-- CreateEnum
CREATE TYPE "EmailCodePurpose" AS ENUM ('LOGIN', 'VERIFY');

-- CreateTable
CREATE TABLE "email_codes" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "purpose" "EmailCodePurpose" NOT NULL DEFAULT 'LOGIN',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "email_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "email_codes_email_idx" ON "email_codes"("email");
