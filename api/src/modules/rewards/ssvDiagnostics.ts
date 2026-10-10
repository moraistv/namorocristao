/**
 * Última recusa de um callback SSV com assinatura válida. Fica só em memória:
 * zera ao reiniciar a API e não é compartilhada entre réplicas. Serve para o
 * painel mostrar ao admin por que o Google "chamou e nada aconteceu" na
 * configuração do SSV, sem gravar no banco a cada chamada de uma rota pública.
 */
export interface SsvRejection {
  at: Date;
  reason: string;
  adUnit: string;
}

let last: SsvRejection | null = null;

export function noteSsvRejection(reason: string, adUnit: string): void {
  last = { at: new Date(), reason, adUnit };
}

export function lastSsvRejection(): SsvRejection | null {
  return last;
}

/**
 * Zera quando o bloco Premiado ou o ad_unit esperado mudam: uma recusa antiga
 * já não diz nada sobre a configuração nova e só confundiria o admin.
 */
export function clearSsvRejection(): void {
  last = null;
}
