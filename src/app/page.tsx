import Link from "next/link";

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-4 px-4 py-16">
      <h1 className="text-3xl font-semibold">ArtMatch</h1>
      <p className="text-base leading-relaxed">
        ปัดดูภาพผลงานของศิลปินไทย เจอสไตล์ที่ใช่ แล้วส่งคำขอจ้างวาดได้ทันที
      </p>
      <p className="text-sm opacity-70">อยู่ระหว่างพัฒนา — Closed Beta เร็ว ๆ นี้</p>
      <Link
        href="/login"
        className="bg-foreground text-background mt-4 w-full rounded-lg px-4 py-3 text-center text-base font-medium"
      >
        เข้าสู่ระบบ
      </Link>
    </main>
  );
}
