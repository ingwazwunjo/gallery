/**
 * True when a state-changing request came from our own site. Browsers send `Origin` on every
 * POST; a missing or different origin is rejected.
 */
export function isSameOriginRequest(originHeader: string | null, expectedOrigin: string): boolean {
  if (!originHeader) return false;
  try {
    return new URL(originHeader).origin === new URL(expectedOrigin).origin;
  } catch {
    return false;
  }
}
