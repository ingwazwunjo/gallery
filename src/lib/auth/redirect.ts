/**
 * Where to send the user after login. Only a path on this site is allowed, so a link like
 * /login?next=https://evil.example cannot turn our login page into a phishing redirect.
 */
export const DEFAULT_AFTER_LOGIN = "/account";

export function safeNextPath(
  raw: string | null | undefined,
  fallback = DEFAULT_AFTER_LOGIN,
): string {
  if (!raw || raw.length > 512) return fallback;
  // Must be a single leading slash: rejects "//host", "/\host" and absolute URLs.
  if (!raw.startsWith("/") || raw.startsWith("//") || raw.startsWith("/\\")) return fallback;
  // Control characters and backslashes can be normalised by browsers into another origin.
  if (/[\u0000-\u001f\u007f\\]/.test(raw)) return fallback;
  try {
    const url = new URL(raw, "https://artmatch.invalid");
    if (url.origin !== "https://artmatch.invalid") return fallback;
    // Defense in depth: some servers decode %2F / %5C, turning "/%2F%2Fevil" into "//evil".
    const decoded = decodeURIComponent(url.pathname);
    if (decoded.startsWith("//") || decoded.includes("\\")) return fallback;
    // Never bounce back into the auth flow itself (also when the path is percent-encoded).
    const path = decoded.toLowerCase();
    if (path === "/login" || path.startsWith("/login/") || path.startsWith("/auth/"))
      return fallback;
    return url.pathname + url.search + url.hash;
  } catch {
    return fallback;
  }
}
