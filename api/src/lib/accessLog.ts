import { Request } from "express";
import { prisma } from "../config/prisma";

/** Extrai o IP real da requisição (considera proxy/X-Forwarded-For). */
export function getClientIp(req: Request): string | undefined {
  const fwd = req.headers["x-forwarded-for"];
  if (typeof fwd === "string" && fwd.length) {
    return fwd.split(",")[0].trim();
  }
  return (req.ip || req.socket?.remoteAddress || undefined)?.replace("::ffff:", "");
}

/** Registra um acesso (login/registro) com IP e user-agent. Nunca lança erro. */
export async function recordAccess(
  req: Request,
  userId: string,
  action: string
): Promise<void> {
  try {
    await prisma.accessLog.create({
      data: {
        userId,
        action,
        ip: getClientIp(req),
        userAgent: (req.headers["user-agent"] as string | undefined)?.slice(0, 400),
      },
    });
  } catch {
    // logging não pode quebrar o fluxo de autenticação
  }
}
