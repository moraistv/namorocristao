import type { AdSettings, Prisma } from "@prisma/client";

/**
 * Garante que a linha única de `ad_settings` existe e a trava até o fim da
 * transação, devolvendo o retrato já travado.
 *
 * Os PUTs que decidem com base nessa linha (Anúncios e Recompensas) precisam
 * passar por aqui: sem a trava, um lê o retrato antigo enquanto o outro grava
 * e as regras entre os dois (ex.: o bloco Premiado travado pelo SSV) falham.
 */
export async function lockAdSettings(
  tx: Prisma.TransactionClient
): Promise<AdSettings> {
  // ON CONFLICT DO NOTHING: criar a linha na primeira vez não corre contra outra requisição.
  await tx.adSettings.createMany({ data: [{ id: 1 }], skipDuplicates: true });
  await tx.$queryRaw`SELECT id FROM ad_settings WHERE id = 1 FOR UPDATE`;
  return tx.adSettings.findUniqueOrThrow({ where: { id: 1 } });
}
