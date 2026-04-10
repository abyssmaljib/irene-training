-- ============================================
-- เพิ่ม post_id ให้ resident_measurements + Scale_Report_Log
-- เพื่อรองรับการบันทึกค่าวัด + assessment ผ่านโพส
-- ============================================

-- ============================================
-- 1. resident_measurements: เพิ่ม post_id + source 'post'
-- ============================================

-- เพิ่ม column post_id (nullable, FK → Post)
ALTER TABLE resident_measurements
  ADD COLUMN IF NOT EXISTS post_id BIGINT REFERENCES public."Post"(id) ON DELETE SET NULL;

-- อัพเดต CHECK constraint ของ source: เพิ่ม 'post'
-- ต้อง drop ก่อนแล้ว re-create เพราะ ALTER CHECK ไม่ได้
ALTER TABLE resident_measurements
  DROP CONSTRAINT IF EXISTS resident_measurements_source_check;

ALTER TABLE resident_measurements
  ADD CONSTRAINT resident_measurements_source_check
  CHECK (source IN ('admission', 'task', 'manual', 'lab_import', 'post'));

-- Index สำหรับ lookup by post_id (เช่น แสดงค่าวัดใน post detail)
CREATE INDEX IF NOT EXISTS idx_resident_measurements_post_id
  ON resident_measurements(post_id) WHERE post_id IS NOT NULL;


-- ============================================
-- 2. Scale_Report_Log: เพิ่ม post_id
-- ============================================

-- เพิ่ม column post_id (nullable, FK → Post)
-- ใช้ CASCADE เพราะถ้าลบ post → assessment ไม่มีที่อยู่แล้ว
ALTER TABLE "Scale_Report_Log"
  ADD COLUMN IF NOT EXISTS post_id BIGINT REFERENCES public."Post"(id) ON DELETE CASCADE;

-- อัพเดต CHECK constraint: อย่างน้อย 1 source ต้องมี
-- เดิม: vital_sign_id IS NOT NULL OR task_log_id IS NOT NULL
-- ใหม่: เพิ่ม OR post_id IS NOT NULL
ALTER TABLE "Scale_Report_Log"
  DROP CONSTRAINT IF EXISTS scale_report_log_source_check;

ALTER TABLE "Scale_Report_Log"
  ADD CONSTRAINT scale_report_log_source_check
  CHECK ("vital_sign_id" IS NOT NULL OR "task_log_id" IS NOT NULL OR "post_id" IS NOT NULL);

-- ป้องกัน duplicate: 1 subject ต่อ 1 post เท่านั้น
ALTER TABLE "Scale_Report_Log"
  ADD CONSTRAINT scale_report_log_post_subject_unique
  UNIQUE (post_id, "Subject_id");

-- Index สำหรับ lookup by post_id
CREATE INDEX IF NOT EXISTS idx_scale_report_log_post_id
  ON "Scale_Report_Log"(post_id) WHERE post_id IS NOT NULL;
