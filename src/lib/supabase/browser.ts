"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { authCookieOptions } from "./cookie-options";
import { publicSupabaseEnv } from "./public-env";

let client: SupabaseClient | undefined;

/** One Supabase client per browser tab. It stores the session in cookies the server can read. */
export function browserSupabase(): SupabaseClient {
  if (!client) {
    const { url, publishableKey } = publicSupabaseEnv();
    client = createBrowserClient(url, publishableKey, { cookieOptions: authCookieOptions });
  }
  return client;
}
