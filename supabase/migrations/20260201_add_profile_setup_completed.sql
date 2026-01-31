-- Migration: Add profile_setup_completed flag to user_info
-- Purpose: Track whether user has completed the required profile setup (Page 1)
-- Date: 2026-02-01

-- เพิ่ม column profile_setup_completed
-- ใช้เช็คว่า user กรอกข้อมูลพื้นฐาน (ชื่อ-สกุล, ชื่อเล่น) แล้วหรือยัง
ALTER TABLE public.user_info
ADD COLUMN IF NOT EXISTS profile_setup_completed boolean DEFAULT false;

-- สร้าง index เพื่อให้ query เร็วขึ้นตอนเช็คสถานะ
CREATE INDEX IF NOT EXISTS idx_user_info_profile_setup_completed
ON public.user_info(id, profile_setup_completed);

-- อัพเดท user เก่าที่มีข้อมูลครบแล้ว ให้ถือว่า setup เสร็จแล้ว
-- เงื่อนไข: มี full_name และ nickname ที่ไม่ว่าง
UPDATE public.user_info
SET profile_setup_completed = true
WHERE full_name IS NOT NULL
  AND full_name != ''
  AND nickname IS NOT NULL
  AND nickname != '';

-- เพิ่ม comment อธิบาย column
COMMENT ON COLUMN public.user_info.profile_setup_completed IS
'Flag indicating user has completed required profile setup (Page 1: full_name, nickname). Set to true after first-time setup.';
