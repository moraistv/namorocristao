import { NextFunction, Request, Response } from "express";
import { assertActiveAdminAccount, assertActiveUserAccount } from "../lib/accountAccess";
import { assertSuperAdmin } from "../lib/adminPermission";
import { AppError, asyncHandler } from "../lib/errors";
import { verifyAccessToken } from "../lib/jwt";

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
    throw new AppError(
      "Token de acesso ausente",
      401,
      undefined,
      "ACCESS_TOKEN_REQUIRED"
    );
  }
  return header.slice("Bearer ".length).trim();
}

/** Exige token de usuário e confirma no banco que a conta segue ativa. */
export const requireUser = asyncHandler(
  async (req: Request, _res: Response, next: NextFunction) => {
    const payload = verifyAccessToken(extractToken(req));
    if (payload.type !== "user") {
      throw new AppError(
        "Acesso restrito a usuários do app",
        403,
        undefined,
        "USER_ACCESS_REQUIRED"
      );
    }
    await assertActiveUserAccount(payload.sub);
    req.userId = payload.sub;
    next();
  }
);

/** Exige token de admin e confirma no banco que a conta ainda existe. */
export const requireAdmin = asyncHandler(
  async (req: Request, _res: Response, next: NextFunction) => {
    const payload = verifyAccessToken(extractToken(req));
    if (payload.type !== "admin") {
      throw new AppError(
        "Acesso restrito a administradores",
        403,
        undefined,
        "ADMIN_ACCESS_REQUIRED"
      );
    }
    await assertActiveAdminAccount(payload.sub);
    req.adminId = payload.sub;
    next();
  }
);

/** Exige super-admin e revalida a função atual diretamente no banco. */
export const requireSuperAdmin = asyncHandler(
  async (req: Request, _res: Response, next: NextFunction) => {
    await assertSuperAdmin(req.adminId);
    next();
  }
);
