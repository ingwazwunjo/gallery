/**
 * True when a state-changing request came from our own site.
 *
 * Browsers send `Origin` on every POST. We compare its host with the host the request was sent to
 * (`x-forwarded-host` behind a proxy, else `host`). We deliberately do not use
 * request.nextUrl.origin: on `next start` it is always http://localhost:<port>, whatever the real
 * host is. A cross-site page cannot forge either header in a victim's browser, and a non-browser
 * client that forges them has no victim cookies to ride on.
 */
export function isSameOriginRequest(
  originHeader: string | null,
  hostHeader: string | null,
): boolean {
  if (!originHeader || !hostHeader) return false;
  try {
    const origin = new URL(originHeader);
    if (origin.protocol !== "https:" && origin.protocol !== "http:") return false;
    return origin.host.toLowerCase() === firstHost(hostHeader);
  } catch {
    return false;
  }
}

/** The host the client addressed. `x-forwarded-host` may list several hosts; the first is the client's. */
export function requestHost(headers: Headers): string | null {
  return headers.get("x-forwarded-host") ?? headers.get("host");
}

function firstHost(header: string): string {
  return header.split(",")[0].trim().toLowerCase();
}

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

export function isSafeMethod(method: string): boolean {
  return SAFE_METHODS.has(method.toUpperCase());
}
