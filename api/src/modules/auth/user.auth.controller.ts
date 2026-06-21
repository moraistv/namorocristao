import { Request, Response } from "express";
import { prisma } from "../../config/prisma";
import { AppError } from "../../lib/errors";
import { hashPassword, verifyPassword } from "../../lib/password";
import { issueTokens, verifyRefreshToken } from "../../lib/jwt";
import { requestLoginCode, consumeLoginCode } from "../../services/otp.service";
import { verifyGoogleIdToken } from "../../services/google.service";
import { recordAccess } from "../../lib/accessLog";
import {
  registerSchema,
  loginSchema,
  requestCodeSchema,
  loginCodeSchema,
  googleSchema,
  refreshSchema,
} from "./auth.validators";

/** Resposta padrão de usuário (sem dados sensíveis). */
function publicUser(user: {
  id: string;
  email: string;
  emailVerified: boolean;
  provider: string;
  isPremium: boolean;
}) {
  return {
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerified,
    provider: user.provider,
    isPremium: user.isPremium,
  };
}

async function ensureNotBanned(userId: string) {
  const banned = await prisma.bannedUser.findUnique({ where: { userId } });
  if (banned) throw new AppError("Conta banida", 403);

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { suspendedUntil: true },
  });
  if (user?.suspendedUntil && user.suspendedUntil.getTime() > Date.now()) {
    const ate = user.suspendedUntil.toLocaleDateString("pt-BR");
    throw new AppError(`Conta suspensa até ${ate}`, 403);
  }
}

// POST /api/auth/register
export async function register(req: Request, res: Response) {
  const { email, password } = registerSchema.parse(req.body);
  const normalized = email.toLowerCase().trim();

  const existing = await prisma.user.findUnique({ where: { email: normalized } });
  if (existing) throw new AppError("E-mail já cadastrado", 409);

  const user = await prisma.user.create({
    data: {
      email: normalized,
      passwordHash: await hashPassword(password),
      provider: "EMAIL",
    },
  });

  const tokens = issueTokens({ sub: user.id, type: "user" });
  await recordAccess(req, user.id, "register");
  res.status(201).json({ user: publicUser(user), ...tokens, hasProfile: false });
}

// POST /api/auth/login
export async function login(req: Request, res: Response) {
  const { email, password } = loginSchema.parse(req.body);
  const normalized = email.toLowerCase().trim();

  const user = await prisma.user.findUnique({
    where: { email: normalized },
    include: { profile: true },
  });
  if (!user || !user.passwordHash) {
    throw new AppError("Credenciais inválidas", 401);
  }

  const ok = await verifyPassword(user.passwordHash, password);
  if (!ok) throw new AppError("Credenciais inválidas", 401);

  await ensureNotBanned(user.id);

  const tokens = issueTokens({ sub: user.id, type: "user" });
  await recordAccess(req, user.id, "login");
  res.json({
    user: publicUser(user),
    ...tokens,
    hasProfile: Boolean(user.profile),
  });
}

// POST /api/auth/request-code
export async function requestCode(req: Request, res: Response) {
  const { email } = requestCodeSchema.parse(req.body);
  await requestLoginCode(email);
  // Resposta genérica (não revela se o e-mail existe).
  res.json({ message: "Se o e-mail for válido, um código foi enviado." });
}

// POST /api/auth/login-code
export async function loginWithCode(req: Request, res: Response) {
  const { email, code } = loginCodeSchema.parse(req.body);
  const normalized = email.toLowerCase().trim();

  await consumeLoginCode(normalized, code);

  // Cria o usuário se ainda não existir (login por código também cadastra).
  let user = await prisma.user.findUnique({
    where: { email: normalized },
    include: { profile: true },
  });
  if (!user) {
    user = await prisma.user.create({
      data: { email: normalized, provider: "EMAIL", emailVerified: true },
      include: { profile: true },
    });
  } else {
    await ensureNotBanned(user.id);
  }

  const tokens = issueTokens({ sub: user.id, type: "user" });
  await recordAccess(req, user.id, "login_code");
  res.json({
    user: publicUser(user),
    ...tokens,
    hasProfile: Boolean(user.profile),
  });
}

// POST /api/auth/google
export async function loginWithGoogle(req: Request, res: Response) {
  const { idToken } = googleSchema.parse(req.body);
  const info = await verifyGoogleIdToken(idToken);

  let user = await prisma.user.findFirst({
    where: { OR: [{ googleId: info.googleId }, { email: info.email }] },
    include: { profile: true },
  });

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: info.email,
        googleId: info.googleId,
        provider: "GOOGLE",
        emailVerified: info.emailVerified,
      },
      include: { profile: true },
    });
  } else if (!user.googleId) {
    // Vincula o Google a uma conta de e-mail existente.
    user = await prisma.user.update({
      where: { id: user.id },
      data: { googleId: info.googleId },
      include: { profile: true },
    });
  }

  await ensureNotBanned(user.id);

  const tokens = issueTokens({ sub: user.id, type: "user" });
  await recordAccess(req, user.id, "google");
  res.json({
    user: publicUser(user),
    ...tokens,
    hasProfile: Boolean(user.profile),
  });
}

// POST /api/auth/refresh
export async function refresh(req: Request, res: Response) {
  const { refreshToken } = refreshSchema.parse(req.body);
  const payload = verifyRefreshToken(refreshToken);
  if (payload.type !== "user") throw new AppError("Token inválido", 401);

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) throw new AppError("Usuário não encontrado", 401);

  const tokens = issueTokens({ sub: user.id, type: "user" });
  res.json(tokens);
}

// GET /api/auth/me
export async function me(req: Request, res: Response) {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    include: { profile: true },
  });
  if (!user) throw new AppError("Usuário não encontrado", 404);
  res.json({ user: publicUser(user), profile: user.profile ?? null });
}
