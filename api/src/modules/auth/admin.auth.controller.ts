import { Request, Response } from "express";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { hashPassword, verifyPassword } from "../../lib/password";
import { issueTokens, verifyRefreshToken } from "../../lib/jwt";
import { adminRegisterSchema, adminLoginSchema, refreshSchema } from "./auth.validators";

function publicAdmin(admin: {
  id: string;
  name: string;
  email: string;
  permissions: string[];
  isSuperAdmin: boolean;
  createdAt: Date;
}) {
  return {
    id: admin.id,
    name: admin.name,
    email: admin.email,
    permissions: admin.permissions,
    isSuperAdmin: admin.isSuperAdmin,
    createdAt: admin.createdAt,
  };
}

// GET /api/admin/auth/needs-setup
// Indica ao painel se ainda não há nenhum admin (mostra tela de registro do super-admin).
export async function needsSetup(_req: Request, res: Response) {
  const count = await prisma.admin.count();
  res.json({ needsSetup: count === 0 });
}

// POST /api/admin/auth/register-super
// Só permitido quando NÃO existe nenhum admin (cria o primeiro super-admin).
export async function registerSuperAdmin(req: Request, res: Response) {
  const { name, email, password } = adminRegisterSchema.parse(req.body);

  const count = await prisma.admin.count();
  if (count > 0) {
    throw new AppError("Super-admin já existe. Registro bloqueado.", 403);
  }

  const admin = await prisma.admin.create({
    data: {
      name,
      email: email.toLowerCase().trim(),
      passwordHash: await hashPassword(password),
      isSuperAdmin: true,
      permissions: ["VERIFICATION", "REPORT", "ACCOUNT_DELETE"],
    },
  });

  const tokens = issueTokens({ sub: admin.id, type: "admin" });
  res.status(201).json({ admin: publicAdmin(admin), ...tokens });
}

// POST /api/admin/auth/login
export async function login(req: Request, res: Response) {
  const { email, password } = adminLoginSchema.parse(req.body);

  const admin = await prisma.admin.findUnique({
    where: { email: email.toLowerCase().trim() },
  });
  if (!admin) throw new AppError("Credenciais inválidas", 401);

  const ok = await verifyPassword(admin.passwordHash, password);
  if (!ok) throw new AppError("Credenciais inválidas", 401);

  const tokens = issueTokens({ sub: admin.id, type: "admin" });
  res.json({ admin: publicAdmin(admin), ...tokens });
}

// POST /api/admin/auth/refresh
export async function refresh(req: Request, res: Response) {
  const { refreshToken } = refreshSchema.parse(req.body);
  const payload = verifyRefreshToken(refreshToken);
  if (payload.type !== "admin") throw new AppError("Token inválido", 401);

  const admin = await prisma.admin.findUnique({ where: { id: payload.sub } });
  if (!admin) throw new AppError("Admin não encontrado", 401);

  const tokens = issueTokens({ sub: admin.id, type: "admin" });
  res.json(tokens);
}

// GET /api/admin/auth/me
export async function me(req: Request, res: Response) {
  const admin = await prisma.admin.findUnique({ where: { id: req.adminId } });
  if (!admin) throw new AppError("Admin não encontrado", 404);
  res.json({ admin: publicAdmin(admin) });
}
