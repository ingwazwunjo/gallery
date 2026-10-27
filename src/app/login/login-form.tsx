"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { browserSupabase } from "@/lib/supabase/browser";
import { safeNextPath } from "@/lib/auth/redirect";
import { emailSchema, otpSchema } from "@/lib/auth/schemas";
import { authErrorMessage, RESEND_COOLDOWN_SECONDS } from "@/lib/auth/messages";

type Step = "email" | "code";
type AuthErrorLike = Parameters<typeof authErrorMessage>[0];

/** Supabase returns most failures as { error }, but a network failure can throw. Treat both alike. */
async function settle(
  call: () => Promise<{ error: AuthErrorLike | null }>,
): Promise<{ error: AuthErrorLike | null }> {
  try {
    return { error: (await call()).error };
  } catch {
    return { error: {} };
  }
}

export function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNextPath(params.get("next"));

  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(
    params.get("error") ? "เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่" : null,
  );
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  async function sendCode(e?: React.FormEvent) {
    e?.preventDefault();
    setError(null);
    const parsed = emailSchema.safeParse(email);
    if (!parsed.success) return setError(parsed.error.issues[0].message);
    setPending(true);
    const { error } = await settle(() =>
      browserSupabase().auth.signInWithOtp({
        email: parsed.data,
        options: { shouldCreateUser: true },
      }),
    );
    setPending(false);
    if (error) return setError(authErrorMessage(error));
    setEmail(parsed.data);
    setCode("");
    setStep("code");
    setCooldown(RESEND_COOLDOWN_SECONDS);
  }

  async function verifyCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const parsed = otpSchema.safeParse(code);
    if (!parsed.success) return setError(parsed.error.issues[0].message);
    setPending(true);
    const { error } = await settle(() =>
      browserSupabase().auth.verifyOtp({ email, token: parsed.data, type: "email" }),
    );
    if (error) {
      setPending(false);
      return setError(authErrorMessage(error));
    }
    router.replace(next);
    router.refresh();
  }

  async function signInWithGoogle() {
    setError(null);
    setPending(true);
    const callback = new URL("/auth/callback", window.location.origin);
    callback.searchParams.set("next", next);
    const { error } = await settle(() =>
      browserSupabase().auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: callback.toString() },
      }),
    );
    if (error) {
      setPending(false);
      setError(authErrorMessage(error));
    }
  }

  const input =
    "w-full rounded-lg border border-black/15 bg-transparent px-3 py-3 text-base outline-none focus:border-black/50 dark:border-white/20 dark:focus:border-white/60";
  const primary =
    "w-full rounded-lg bg-foreground px-4 py-3 text-base font-medium text-background disabled:opacity-50";
  const secondary =
    "w-full rounded-lg border border-black/15 px-4 py-3 text-base font-medium disabled:opacity-50 dark:border-white/20";

  return (
    <div className="flex flex-col gap-4">
      {error && (
        <p
          role="alert"
          className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-200"
        >
          {error}
        </p>
      )}

      {step === "email" ? (
        <form onSubmit={sendCode} className="flex flex-col gap-3" noValidate>
          <label htmlFor="email" className="text-sm font-medium">
            อีเมล
          </label>
          <input
            id="email"
            type="email"
            inputMode="email"
            autoComplete="email"
            className={input}
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <button type="submit" className={primary} disabled={pending}>
            {pending ? "กำลังส่ง…" : "ส่งรหัสเข้าสู่ระบบ"}
          </button>
        </form>
      ) : (
        <form onSubmit={verifyCode} className="flex flex-col gap-3" noValidate>
          <label htmlFor="code" className="text-sm font-medium">
            รหัส 6 หลักที่ส่งไปที่ {email}
          </label>
          <input
            id="code"
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="\d{6}"
            className={`${input} tracking-[0.5em]`}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
            required
            autoFocus
          />
          <button type="submit" className={primary} disabled={pending}>
            {pending ? "กำลังตรวจสอบ…" : "เข้าสู่ระบบ"}
          </button>
          <div className="flex justify-between text-sm">
            <button type="button" className="underline opacity-70" onClick={() => setStep("email")}>
              เปลี่ยนอีเมล
            </button>
            <button
              type="button"
              className="underline opacity-70 disabled:no-underline disabled:opacity-40"
              disabled={cooldown > 0 || pending}
              onClick={() => sendCode()}
            >
              {cooldown > 0 ? `ส่งรหัสใหม่ได้ใน ${cooldown} วินาที` : "ส่งรหัสใหม่"}
            </button>
          </div>
        </form>
      )}

      <div className="flex items-center gap-3 text-xs opacity-60">
        <span className="h-px flex-1 bg-current opacity-30" />
        หรือ
        <span className="h-px flex-1 bg-current opacity-30" />
      </div>

      <button type="button" className={secondary} onClick={signInWithGoogle} disabled={pending}>
        เข้าสู่ระบบด้วย Google
      </button>
    </div>
  );
}
