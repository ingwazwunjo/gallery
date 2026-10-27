import type { Metadata } from "next";
import { Suspense } from "react";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "เข้าสู่ระบบ · ArtMatch" };

export default function LoginPage() {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-6 px-4 py-12">
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold">เข้าสู่ระบบ ArtMatch</h1>
        <p className="text-sm opacity-70">ยังไม่มีบัญชี? กรอกอีเมลแล้วระบบจะสร้างให้อัตโนมัติ</p>
      </div>
      {/* The form reads ?next= and ?error= from the URL, which is request data. */}
      <Suspense fallback={<div className="h-64" aria-busy="true" />}>
        <LoginForm />
      </Suspense>
      <p className="text-xs leading-relaxed opacity-60">
        เมื่อเข้าสู่ระบบ ถือว่าคุณยอมรับข้อตกลงการใช้งานและนโยบายความเป็นส่วนตัว
        บริการนี้สำหรับผู้มีอายุ 18 ปีขึ้นไป
      </p>
    </main>
  );
}
