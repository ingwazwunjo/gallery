import { NextResponse, type NextRequest } from "next/server";
import { serverSupabase } from "@/server/supabase/server";
import { isSameOriginRequest } from "@/lib/auth/origin";

/** Sign out. POST only, and only from our own pages, so another site cannot log users out. */
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get("origin"), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }
  const supabase = await serverSupabase();
  await supabase.auth.signOut({ scope: "local" });
  const response = NextResponse.redirect(new URL("/login", request.nextUrl.origin), {
    status: 303,
  });
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
