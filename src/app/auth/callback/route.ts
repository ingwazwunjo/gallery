import { NextResponse, type NextRequest } from "next/server";
import { serverSupabase } from "@/server/supabase/server";
import { safeNextPath } from "@/lib/auth/redirect";

/**
 * Google sends the user back here with a one-time `code` (PKCE). We exchange it for a session,
 * which sets the auth cookies, then continue to a same-site path only.
 *
 * Redirects use a relative Location so the browser stays on the host it is already on
 * (request.nextUrl.origin is always localhost under `next start`).
 */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;
  const next = safeNextPath(params.get("next"));
  const code = params.get("code");

  if (code) {
    const supabase = await serverSupabase();
    const ok = await supabase.auth
      .exchangeCodeForSession(code)
      .then(({ error }) => !error)
      .catch(() => false);
    if (ok) return redirectTo(next);
  }

  const failed = new URLSearchParams({ error: "oauth", next });
  return redirectTo(`/login?${failed}`);
}

function redirectTo(path: string) {
  return new NextResponse(null, {
    status: 303,
    headers: { Location: path, "Cache-Control": "private, no-store" },
  });
}
