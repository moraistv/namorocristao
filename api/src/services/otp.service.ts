import argon2 from "argon2";
import { prisma } from "../config/prisma";
import { AppError } from "../lib/errors";
import { sendLoginCodeEmail } from "../lib/email";

const CODE_TTL_MINUTES = 10;

function generateCode(): string {
  // Código numérico de 6 dígitos.
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/** Gera e envia um código de login para o e-mail informado. */
export async function requestLoginCode(email: string): Promise<void> {
  const normalized = email.toLowerCase().trim();
  const code = generateCode();
  const codeHash = await argon2.hash(code);
  const expiresAt = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);

  // Invalida códigos anteriores ainda válidos do mesmo e-mail.
  await prisma.emailCode.updateMany({
    where: { email: normalized, purpose: "LOGIN", consumedAt: null },
    data: { consumedAt: new Date() },
  });

  await prisma.emailCode.create({
    data: { email: normalized, codeHash, purpose: "LOGIN", expiresAt },
  });

  await sendLoginCodeEmail(normalized, code);
}

/** Verifica e consome um código de login. Lança AppError se inválido. */
export async function consumeLoginCode(
  email: string,
  code: string
): Promise<void> {
  const normalized = email.toLowerCase().trim();

  const record = await prisma.emailCode.findFirst({
    where: {
      email: normalized,
      purpose: "LOGIN",
      consumedAt: null,
      expiresAt: { gt: new Date() },
    },
    orderBy: { createdAt: "desc" },
  });

  if (!record) {
    throw new AppError("Código inválido ou expirado", 400);
  }

  const ok = await argon2.verify(record.codeHash, code);
  if (!ok) {
    throw new AppError("Código inválido ou expirado", 400);
  }

  await prisma.emailCode.update({
    where: { id: record.id },
    data: { consumedAt: new Date() },
  });
}
