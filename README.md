# ArtMatch

ค้นพบศิลปินไทยผ่านภาพผลงาน แล้วส่งคำขอจ้างวาดได้ทันที — mobile-first web app (MVP)

## เริ่มต้นพัฒนา

ต้องมี Node.js 22+ และ Docker (สำหรับ Supabase local)

```bash
npm install
cp .env.example .env.local
npx supabase start          # พิมพ์ URL และ key ของ local ออกมา ให้ใส่ใน .env.local
npm run db:reset            # สร้างฐานข้อมูลใหม่จาก migrations + seed
npm run dev
```

ผู้ใช้ทดสอบจาก `supabase/seed.sql` (login ด้วย email OTP แล้วเปิดอีเมลใน Mailpit ที่ `npx supabase status` แสดง):
`buyer@` · `artist@` · `artist2@` · `unverified@` · `admin@` · `suspended@` ตามด้วย `artmatch.test`

## Tests

```bash
npm test          # Vitest
npm run db:test   # pgTAP: RLS, privileges, constraints (ต้องรัน supabase start ก่อน)
```

## โครงสร้าง

| Path                  | เนื้อหา                                                  |
| --------------------- | -------------------------------------------------------- |
| `src/app`             | หน้าเว็บและ Route Handlers (`api/v1`)                    |
| `src/server`          | โค้ดฝั่ง server เท่านั้น (env, auth, modules ตาม domain) |
| `supabase/migrations` | Schema, RLS, functions — แก้ฐานข้อมูลผ่านไฟล์นี้เท่านั้น |
| `supabase/tests`      | pgTAP tests                                              |
| `docs/adr`            | บันทึกการตัดสินใจทางสถาปัตยกรรม                          |
