import { Profile } from "@prisma/client";

export const ONLINE_TTL_MS = 5 * 60 * 1000;

/** Instante mínimo aceito para considerar uma presença recente. */
export function onlineCutoff(now = new Date()): Date {
  return new Date(now.getTime() - ONLINE_TTL_MS);
}

/** Deriva presença a partir do heartbeat recente, nunca só do booleano persistido. */
export function isRecentlyOnline(
  profile: Pick<Profile, "isOnline" | "lastActiveAt"> | null | undefined,
  now = new Date()
): boolean {
  return Boolean(
    profile?.isOnline &&
      profile.lastActiveAt &&
      profile.lastActiveAt >= onlineCutoff(now)
  );
}
