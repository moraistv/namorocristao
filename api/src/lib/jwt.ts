import jwt, { SignOptions } from "jsonwebtoken";
import { env } from "../config/env";
import { AppError } from "./errors";

export type Principal = "user" | "admin";

export interface TokenPayload {
  sub: string;
  type: Principal;
}

export function signAccessToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES,
  } as SignOptions);
}

export function signRefreshToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_EXPIRES,
  } as SignOptions);
}

export function verifyAccessToken(token: string): TokenPayload {
  try {
    return jwt.verify(token, env.JWT_ACCESS_SECRET) as TokenPayload;
  } catch {
    throw new AppError("Token inválido ou expirado", 401);
  }
}

export function verifyRefreshToken(token: string): TokenPayload {
  try {
    return jwt.verify(token, env.JWT_REFRESH_SECRET) as TokenPayload;
  } catch {
    throw new AppError("Refresh token inválido ou expirado", 401);
  }
}

/** Gera o par de tokens (access + refresh) para um principal. */
export function issueTokens(payload: TokenPayload) {
  return {
    accessToken: signAccessToken(payload),
    refreshToken: signRefreshToken(payload),
  };
}
