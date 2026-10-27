import type { Metadata } from "next";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { getAuthContext } from "@/server/auth/context";

export const metadata: Metadata = { title: "บัญชีของฉัน · ArtMatch" };

export default function AccountPage() {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-6 px-4 py-12">
      <h1 className="text-2xl font-semibold">บัญชีของฉัน</h1>
      {/* Reading the session is request data, so it streams in behind a boundary. */}
      <Suspense fallback={<p className="text-sm opacity-60">กำลังโหลด…</p>}>
        <AccountDetails />
      </Suspense>
    </main>
  );
}

async function AccountDetails() {
  const auth = await getAuthContext();
  if (!auth) redirect("/login?next=/account");

  return (
    <div className="flex flex-col gap-4">
      <p className="text-base">
        เข้าสู่ระบบด้วย <span className="font-medium">{auth.email ?? "บัญชี Google"}</span>
      </p>
      <p className="text-sm opacity-70">ขั้นตอนถัดไป (ตั้งชื่อ ยืนยันอายุ 18+) จะเพิ่มในงาน B7</p>
      <form action="/auth/signout" method="post">
        <button
          type="submit"
          className="w-full rounded-lg border border-black/15 px-4 py-3 text-base font-medium dark:border-white/20"
        >
          ออกจากระบบ
        </button>
      </form>
    </div>
  );
}
