import { z } from "zod";

export const emailSchema = z
  .string()
  .trim()
  .toLowerCase()
  .max(254)
  .pipe(z.email({ message: "กรุณากรอกอีเมลให้ถูกต้อง" }));

export const otpSchema = z
  .string()
  .trim()
  .regex(/^\d{6}$/, { message: "รหัสต้องเป็นตัวเลข 6 หลัก" });
