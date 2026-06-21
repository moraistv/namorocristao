import { AdminPermission } from "@prisma/client";
import { prisma } from "../config/prisma";
import { AppError } from "./errors";

/** Garante que o admin tem a permissão (super-admin tem todas). */
export async function assertPermission(
  adminId: string | undefined,
  permission: AdminPermission
) {
  const admin = await prisma.admin.findUnique({ where: { id: adminId } });
  if (!admin) throw new AppError("Admin não encontrado", 401);
  if (admin.isSuperAdmin) return admin;
  if (!admin.permissions.includes(permission)) {
    throw new AppError("Permissão insuficiente", 403);
  }
  return admin;
}

export async function assertSuperAdmin(adminId: string | undefined) {
  const admin = await prisma.admin.findUnique({ where: { id: adminId } });
  if (!admin) throw new AppError("Admin não encontrado", 401);
  if (!admin.isSuperAdmin) throw new AppError("Apenas super-admin", 403);
  return admin;
}
