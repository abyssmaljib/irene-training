-- ============================================
-- เพิ่ม audit columns ใน med_DB
-- ============================================
-- เพิ่ม created_by, updated_at, updated_by
-- เพื่อติดตามว่าใครสร้าง/แก้ไขยาในฐานข้อมูล เมื่อไหร่
-- created_at มีอยู่แล้ว (default now())

-- 1. เพิ่ม columns (nullable เพราะ record เดิมไม่มีข้อมูล)
ALTER TABLE public."med_DB"
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- 2. Foreign key constraints → อ้างอิง user_info.id
ALTER TABLE public."med_DB"
  ADD CONSTRAINT med_db_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES public.user_info(id)
    ON UPDATE CASCADE ON DELETE SET NULL NOT VALID;

ALTER TABLE public."med_DB"
  ADD CONSTRAINT med_db_updated_by_fkey
    FOREIGN KEY (updated_by) REFERENCES public.user_info(id)
    ON UPDATE CASCADE ON DELETE SET NULL NOT VALID;

-- 3. Trigger: auto-set updated_at เมื่อ update record
CREATE OR REPLACE FUNCTION public.set_med_db_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER med_db_set_updated_at
  BEFORE UPDATE ON public."med_DB"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_med_db_updated_at();
