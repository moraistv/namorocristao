-- Otimização: índice composto (matchId, createdAt) acelera histórico, última
-- mensagem e contagem de não lidas. Substitui o índice só de matchId.
DROP INDEX IF EXISTS "messages_matchId_idx";
CREATE INDEX "messages_matchId_createdAt_idx" ON "messages"("matchId", "createdAt");
