import { OAuth2Client } from "google-auth-library";
import { env } from "../config/env";
import { AppError } from "../lib/errors";

const client = new OAuth2Client();

export interface GoogleUserInfo {
  googleId: string;
  email: string;
  emailVerified: boolean;
  name?: string;
  picture?: string;
}

/** Valida um ID token do Google e retorna os dados do usuário. */
export async function verifyGoogleIdToken(
  idToken: string
): Promise<GoogleUserInfo> {
  if (env.googleClientIds.length === 0) {
    throw new AppError(
      "Login com Google ainda não configurado (defina GOOGLE_CLIENT_IDS)",
      503
    );
  }

  let ticket;
  try {
    ticket = await client.verifyIdToken({
      idToken,
      audience: env.googleClientIds,
    });
  } catch {
    throw new AppError("Token do Google inválido", 401);
  }

  const payload = ticket.getPayload();
  if (!payload || !payload.sub || !payload.email) {
    throw new AppError("Token do Google sem dados suficientes", 401);
  }

  return {
    googleId: payload.sub,
    email: payload.email.toLowerCase(),
    emailVerified: payload.email_verified ?? false,
    name: payload.name,
    picture: payload.picture,
  };
}
