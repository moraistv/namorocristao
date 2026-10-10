/**
 * Espera curta e aleatória antes de repetir uma transação Serializable que
 * colidiu (P2034). Sem a espera, duas requisições que colidiram tendem a
 * colidir de novo no mesmo instante e esgotam as tentativas à toa.
 *
 * `attempt` começa em 0 (espera de 25 a 75 ms) e a faixa cresce a cada tentativa.
 */
export function retryBackoff(attempt: number): Promise<void> {
  const ms = (25 + Math.floor(Math.random() * 50)) * (attempt + 1);
  return new Promise((resolve) => setTimeout(resolve, ms));
}
