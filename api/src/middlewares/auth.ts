import { NextFunction, Request, Response } from "express";
import { verifyAccessToken } from "../lib/jwt";
import { AppError } from "../lib/errors";

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      userId?: string;
      adminId?: string;
    }
  }
}

function extractToken(req: Request): string {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    throw new AppError("Token de acesso ausente", 401);
  }
  return header.slice("Bearer ".length).trim();
}

/** Exige um usuário do app autenticado. */
export function requireUser(req: Request, _res: Response, next: NextFunction) {
  const payload = verifyAccessToken(extractToken(req));
  if (payload.type !== "user") {
    throw new AppError("Acesso restrito a usuários do app", 403);
  }
  req.userId = payload.sub;
  next();
}

/** Exige um admin autenticado. */
export function requireAdmin(req: Request, _res: Response, next: NextFunction) {
  const payload = verifyAccessToken(extractToken(req));
  if (payload.type !== "admin") {
    throw new AppError("Acesso restrito a administradores", 403);
  }
  req.adminId = payload.sub;
  next();
}
