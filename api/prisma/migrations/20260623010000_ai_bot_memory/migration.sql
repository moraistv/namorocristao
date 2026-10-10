-- Configuração individual e segura para bots existentes, epoch de memória e
-- saldo explícito de Super Likes comprados/concedidos.
ALTER TABLE "users"
  ADD COLUMN "botSystemPrompt" TEXT,
  ADD COLUMN "botAiModel" TEXT,
  ADD COLUMN "botAiModelProvider" TEXT,
  ADD COLUMN "botTemperature" DOUBLE PRECISION NOT NULL DEFAULT 0.75,
  ADD COLUMN "botMemoryEnabled" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "botMemoryEpoch" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "bonusSuperLikes" INTEGER NOT NULL DEFAULT 0;

CREATE INDEX "users_isBot_deletedAt_idx"
  ON "users"("isBot", "deletedAt");

-- Valores negativos eram usados como bônus implícito. Converte o saldo sem
-- alterar a quantidade disponível e normaliza o contador diário.
UPDATE "users"
SET "bonusSuperLikes" = "bonusSuperLikes" + GREATEST(-"superLikesUsedToday", 0),
    "superLikesUsedToday" = GREATEST("superLikesUsedToday", 0);

-- Registros legados mantêm proveniência desconhecida (NULL). O default vale
-- somente para novas linhas; escritas da aplicação registram a origem.
ALTER TABLE "interactions"
  ADD COLUMN "superLikeUsedBonus" BOOLEAN;
ALTER TABLE "interactions"
  ALTER COLUMN "superLikeUsedBonus" SET DEFAULT false;

-- Memória global e vínculo da credencial ao provider; mantém os demais valores
-- atuais da linha singleton, se ela já existir.
ALTER TABLE "bot_settings"
  ADD COLUMN "aiApiKeyProvider" TEXT,
  ADD COLUMN "memoryEnabled" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "memoryRefreshMessages" INTEGER NOT NULL DEFAULT 8,
  ADD COLUMN "recentMessageLimit" INTEGER NOT NULL DEFAULT 24;

-- Preserva a credencial legada associando-a apenas ao provider selecionado e conhecido.
UPDATE "bot_settings"
SET "aiApiKeyProvider" = LOWER("aiProvider")
WHERE "aiApiKey" IS NOT NULL
  AND LOWER("aiProvider") IN ('deepseek', 'openai');

-- Modelos individuais legados passam a carregar o provider global apenas
-- quando o singleton contém um valor conhecido; nenhum provider é inferido.
UPDATE "users" AS u
SET "botAiModelProvider" = LOWER(s."aiProvider")
FROM "bot_settings" AS s
WHERE s."id" = 1
  AND u."botAiModel" IS NOT NULL
  AND BTRIM(u."botAiModel") <> ''
  AND LOWER(s."aiProvider") IN ('deepseek', 'openai');

-- Novas instalações passam a usar DeepSeek por padrão sem sobrescrever settings existentes.
ALTER TABLE "bot_settings" ALTER COLUMN "aiProvider" SET DEFAULT 'deepseek';
ALTER TABLE "bot_settings" ALTER COLUMN "aiModel" SET DEFAULT 'deepseek-chat';
ALTER TABLE "bot_settings" ALTER COLUMN "aiSystemPrompt" SET DEFAULT 'Voce e um perfil virtual cristao identificado como IA. Converse com respeito, acolhimento e transparencia, em portugues do Brasil.';

-- Origem explícita corrige a classificação histórica de analytics.
ALTER TABLE "chatbot_logs"
  ADD COLUMN "responseSource" TEXT,
  ADD COLUMN "latencyMs" INTEGER;

UPDATE "chatbot_logs"
SET "responseSource" = CASE
  WHEN "usedAi" = true THEN 'AI'
  WHEN "matchedCategory" IS NOT NULL THEN 'RULE'
  ELSE 'FALLBACK'
END;

ALTER TABLE "chatbot_logs" ALTER COLUMN "responseSource" SET DEFAULT 'FALLBACK';
ALTER TABLE "chatbot_logs" ALTER COLUMN "responseSource" SET NOT NULL;

CREATE INDEX "chatbot_logs_responseSource_createdAt_idx"
  ON "chatbot_logs"("responseSource", "createdAt");
CREATE INDEX "chatbot_logs_botUserId_createdAt_idx"
  ON "chatbot_logs"("botUserId", "createdAt");

-- Idempotência retomável de broadcasts. O hash sentinela impede que uma chave
-- legada seja reutilizada como se o payload original pudesse ser reconstruído.
CREATE TYPE "BotBroadcastStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');
CREATE TYPE "BotBroadcastRecipientStatus" AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'SKIPPED', 'FAILED');

ALTER TABLE "bot_broadcasts"
  ADD COLUMN "idempotencyKey" TEXT,
  ADD COLUMN "requestHash" TEXT,
  ADD COLUMN "recipientLimit" INTEGER NOT NULL DEFAULT 500,
  ADD COLUMN "status" "BotBroadcastStatus" NOT NULL DEFAULT 'PENDING',
  ADD COLUMN "leaseUntil" TIMESTAMP(3),
  ADD COLUMN "leaseToken" TEXT,
  ADD COLUMN "lastError" TEXT,
  ADD COLUMN "startedAt" TIMESTAMP(3),
  ADD COLUMN "snapshotAt" TIMESTAMP(3),
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "bot_broadcasts"
SET "idempotencyKey" = "id"
WHERE "idempotencyKey" IS NULL;

UPDATE "bot_broadcasts"
SET "requestHash" = 'legacy:' || "id",
    "status" = CASE
      WHEN "sentAt" IS NOT NULL THEN 'COMPLETED'::"BotBroadcastStatus"
      ELSE 'FAILED'::"BotBroadcastStatus"
    END,
    "startedAt" = "createdAt",
    "snapshotAt" = "createdAt",
    "lastError" = CASE
      WHEN "sentAt" IS NULL THEN 'Broadcast legado incompleto; payload original não verificável'
      ELSE NULL
    END;

ALTER TABLE "bot_broadcasts" ALTER COLUMN "idempotencyKey" SET NOT NULL;
ALTER TABLE "bot_broadcasts" ALTER COLUMN "requestHash" SET NOT NULL;
ALTER TABLE "bot_broadcasts" ALTER COLUMN "updatedAt" DROP DEFAULT;
CREATE UNIQUE INDEX "bot_broadcasts_idempotencyKey_key"
  ON "bot_broadcasts"("idempotencyKey");
CREATE INDEX "bot_broadcasts_status_leaseUntil_idx"
  ON "bot_broadcasts"("status", "leaseUntil");

CREATE TABLE "bot_broadcast_recipients" (
  "id" TEXT NOT NULL,
  "broadcastId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "status" "BotBroadcastRecipientStatus" NOT NULL DEFAULT 'PENDING',
  "leaseUntil" TIMESTAMP(3),
  "leaseToken" TEXT,
  "messageId" TEXT,
  "error" TEXT,
  "sentAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "bot_broadcast_recipients_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "bot_broadcast_recipients_broadcastId_userId_key"
  ON "bot_broadcast_recipients"("broadcastId", "userId");
CREATE INDEX "bot_broadcast_recipients_broadcastId_status_idx"
  ON "bot_broadcast_recipients"("broadcastId", "status");
CREATE INDEX "bot_broadcast_recipients_status_leaseUntil_idx"
  ON "bot_broadcast_recipients"("status", "leaseUntil");

ALTER TABLE "bot_broadcast_recipients"
  ADD CONSTRAINT "bot_broadcast_recipients_broadcastId_fkey"
  FOREIGN KEY ("broadcastId") REFERENCES "bot_broadcasts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Uma memória acumulativa por match; a remoção do match limpa a memória automaticamente.
CREATE TABLE "bot_conversation_memories" (
  "id" TEXT NOT NULL,
  "matchId" TEXT NOT NULL,
  "botUserId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "summary" TEXT NOT NULL DEFAULT '',
  "knownFacts" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "relationshipStage" TEXT NOT NULL DEFAULT 'initial',
  "messageCount" INTEGER NOT NULL DEFAULT 0,
  "lastMessageAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "bot_conversation_memories_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "bot_conversation_memories_matchId_key"
  ON "bot_conversation_memories"("matchId");
CREATE INDEX "bot_conversation_memories_botUserId_lastMessageAt_idx"
  ON "bot_conversation_memories"("botUserId", "lastMessageAt");
CREATE INDEX "bot_conversation_memories_userId_lastMessageAt_idx"
  ON "bot_conversation_memories"("userId", "lastMessageAt");

ALTER TABLE "bot_conversation_memories"
  ADD CONSTRAINT "bot_conversation_memories_matchId_fkey"
  FOREIGN KEY ("matchId") REFERENCES "matches"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
