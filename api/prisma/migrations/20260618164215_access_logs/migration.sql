-- CreateTable
CREATE TABLE "access_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "ip" TEXT,
    "userAgent" TEXT,
    "action" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "access_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "access_logs_userId_idx" ON "access_logs"("userId");
