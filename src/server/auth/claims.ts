import { z } from "zod";

/** Who is calling, after the access token has been verified. Deliberately narrow. */
export type AuthContext = {
  userId: string;
  email: string | null;
  via: "cookie" | "bearer";
};

const claimsSchema = z.object({
  sub: z.uuid(),
  role: z.literal("authenticated"),
  email: z.string().optional(),
  is_anonymous: z.boolean().optional(),
});

/**
 * Turns verified JWT claims into an AuthContext, or null when the claims do not describe a
 * real signed-in user (anonymous sessions, service tokens, malformed claims).
 * Pure function: call it only with claims returned by supabase.auth.getClaims(), which verifies them.
 */
export function authContextFromClaims(
  claims: unknown,
  via: AuthContext["via"],
): AuthContext | null {
  const parsed = claimsSchema.safeParse(claims);
  if (!parsed.success || parsed.data.is_anonymous) return null;
  return { userId: parsed.data.sub, email: parsed.data.email ?? null, via };
}

/** Extracts the token from `Authorization: Bearer <token>`; anything else returns null. */
export function bearerToken(header: string | null): string | null {
  if (!header) return null;
  // A JWT is three base64url segments joined by dots.
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(header.trim());
  return match ? match[1] : null;
}
