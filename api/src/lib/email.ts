import { env } from "../config/env";

/**
 * Envio de e-mail. Em desenvolvimento, apenas loga no console (sem SMTP).
 * Em produção, plugar um provedor (SMTP/SES/Resend) aqui.
 */
export async function sendEmail(params: {
  to: string;
  subject: string;
  text: string;
}): Promise<void> {
  if (env.NODE_ENV !== "production") {
    console.log("\n📧 [DEV EMAIL]");
    console.log(`   Para:    ${params.to}`);
    console.log(`   Assunto: ${params.subject}`);
    console.log(`   Texto:   ${params.text}\n`);
    return;
  }
  // TODO(produção): integrar provedor de e-mail real.
  console.log(`[email] (produção) enviar para ${params.to}: ${params.subject}`);
}

export async function sendLoginCodeEmail(to: string, code: string) {
  await sendEmail({
    to,
    subject: "Seu código de acesso — Namoro Cristão",
    text: `Seu código de acesso é: ${code}\nEle expira em 10 minutos.`,
  });
}
