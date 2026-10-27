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

### เข้าสู่ระบบ (B6)

- **Email OTP:** กรอกอีเมลที่ `/login` แล้วกรอกรหัส 6 หลักจากอีเมล บนเครื่องพัฒนาอีเมลไปที่ Mailpit (URL จาก `npx supabase status`)
- **Google:** ใส่ `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` และ `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` ใน shell ก่อน `npx supabase start` และใน Google Cloud ต้องมี redirect URI `http://127.0.0.1:54321/auth/v1/callback`
- **Supabase project จริง:** ตั้งค่าใน dashboard ให้ตรงกับ `supabase/config.toml` (Site URL, Redirect URLs, OTP 6 หลัก หมดอายุ 600 วินาที, template อีเมลจาก `supabase/templates/otp.html`, Google provider)

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
