import { Prisma } from "@prisma/client";

/** Relação mínima necessária para identificar perfis virtuais em payloads públicos. */
export const publicProfileInclude = Prisma.validator<Prisma.ProfileInclude>()({
  user: { select: { isBot: true } },
});

export type PublicProfileSource = Prisma.ProfileGetPayload<{
  include: typeof publicProfileInclude;
}>;

type PublicMediaSource = Pick<
  PublicProfileSource,
  "mediaFiles" | "lockedPhotos" | "profilePicture"
>;

/** Remove mídia privada e impede que uma capa privada seja exposta por outro campo. */
export function sanitizePublicMedia(profile: PublicMediaSource) {
  const locked = new Set(profile.lockedPhotos);
  const mediaFiles = profile.mediaFiles.filter((url) => !locked.has(url));
  const profilePicture =
    profile.profilePicture && !locked.has(profile.profilePicture)
      ? profile.profilePicture
      : (mediaFiles[0] ?? null);

  return { mediaFiles, profilePicture };
}

/** Mantém os dois nomes públicos como aliases do mesmo estado persistido. */
export function publicVirtualFlags(isBot: boolean) {
  return { isBot, isVirtual: isBot };
}
