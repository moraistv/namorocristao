import { prisma } from "../config/prisma";
import { AppError } from "./errors";

/** Valida o estado atual da conta antes de aceitar uma sessão de usuário. */
export async function assertActiveUserAccount(userId: string) {
  const [user, bannedRecord] = await Promise.all([
    prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        isBanned: true,
        suspendedUntil: true,
        deletedAt: true,
      },
    }),
    prisma.bannedUser.findUnique({
      where: { userId },
      select: { id: true },
    }),
  ]);

  if (!user || user.deletedAt) {
    throw new AppError(
      "Sessão inválida ou conta indisponível",
      401,
      undefined,
      "ACCOUNT_UNAVAILABLE"
    );
  }
  if (user.isBanned || bannedRecord) {
    throw new AppError("Conta banida", 403, undefined, "ACCOUNT_BANNED");
  }
  if (user.suspendedUntil && user.suspendedUntil.getTime() > Date.now()) {
    throw new AppError(
      "Conta suspensa temporariamente",
      403,
      { suspendedUntil: user.suspendedUntil.toISOString() },
      "ACCOUNT_SUSPENDED"
    );
  }

  return user;
}

/** Garante que a conta administrativa vinculada ao token ainda exista. */
export async function assertActiveAdminAccount(adminId: string) {
  const admin = await prisma.admin.findUnique({
    where: { id: adminId },
    select: { id: true },
  });
  if (!admin) {
    throw new AppError(
      "Sessão de administrador inválida",
      401,
      undefined,
      "ADMIN_ACCOUNT_UNAVAILABLE"
    );
  }
  return admin;
}
