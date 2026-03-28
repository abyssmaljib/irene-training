-- ============================================
-- Fix: resident_measurements security hardening
-- ============================================
-- แก้ไข 4 issues ที่พบจาก security review:
-- 1. ไม่มี DELETE RLS policy
-- 2. View ไม่มี security_invoker
-- 3. Function ไม่มี search_path
-- 4. recorded_by ไม่มี FK ไป auth.users

-- ============================================
-- 1. เพิ่ม DELETE policy — ให้ลบได้เฉพาะ nursinghome เดียวกัน
-- ============================================
-- ใช้สำหรับ soft delete (UPDATE is_deleted = true) หรือ hard delete ในอนาคต
CREATE POLICY "rm_delete_same_nh" ON public.resident_measurements
  FOR DELETE TO authenticated
  USING (nursinghome_id = public.get_current_user_nursinghome_id());

-- ============================================
-- 2. Recreate view ด้วย security_invoker = true
-- ============================================
-- ป้องกัน user ต่าง nursinghome เห็นค่าของ resident คนอื่น
-- เมื่อ query view ผ่าน client โดยตรง
DROP VIEW IF EXISTS public.resident_latest_measurements;

CREATE VIEW public.resident_latest_measurements
WITH (security_invoker = true)
AS
SELECT DISTINCT ON (rm.resident_id, rm.measurement_type)
  rm.id,
  rm.resident_id,
  rm.nursinghome_id,
  rm.measurement_type,
  rm.numeric_value,
  rm.unit,
  rm.recorded_at,
  rm.source,
  rm.recorded_by
FROM public.resident_measurements rm
WHERE rm.is_deleted = FALSE
ORDER BY rm.resident_id, rm.measurement_type, rm.recorded_at DESC;

-- ============================================
-- 3. Recreate function ด้วย search_path = public
-- ============================================
-- ป้องกัน search_path hijack ตาม pattern ของ RLS helper functions
CREATE OR REPLACE FUNCTION public.get_resident_bmi(p_resident_id BIGINT)
RETURNS DECIMAL(4,1)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT ROUND(
    (
      SELECT numeric_value
      FROM public.resident_measurements
      WHERE resident_id = p_resident_id
        AND measurement_type = 'weight'
        AND is_deleted = FALSE
      ORDER BY recorded_at DESC
      LIMIT 1
    )
    /
    POWER(
      (
        SELECT numeric_value / 100.0
        FROM public.resident_measurements
        WHERE resident_id = p_resident_id
          AND measurement_type = 'height'
          AND is_deleted = FALSE
        ORDER BY recorded_at DESC
        LIMIT 1
      ),
      2
    ),
    1
  )::DECIMAL(4,1);
$$;

-- ============================================
-- 4. เพิ่ม FK constraint สำหรับ recorded_by → auth.users
-- ============================================
-- ป้องกัน insert UUID ที่ไม่ exist ใน auth.users
-- recorded_by เป็น NOT NULL → ใช้ RESTRICT ไม่ให้ลบ user ที่มี measurement อยู่
ALTER TABLE public.resident_measurements
  ADD CONSTRAINT rm_recorded_by_fk
  FOREIGN KEY (recorded_by)
  REFERENCES auth.users(id)
  ON DELETE RESTRICT;
