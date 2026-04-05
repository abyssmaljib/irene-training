-- ============================================================
-- Scale Assessment: เพิ่ม task_log_id ใน Scale_Report_Log
-- เพื่อรองรับการประเมินจาก checklist task completion
-- (เดิมผูกแค่ vital_sign_id)
-- ============================================================

-- 1. เพิ่ม task_log_id column (nullable — ใช้คู่กับ vital_sign_id)
ALTER TABLE "public"."Scale_Report_Log"
  ADD COLUMN "task_log_id" bigint;

-- 2. FK → A_Task_logs_ver2 (CASCADE delete เมื่อ task log ถูกลบ)
ALTER TABLE "public"."Scale_Report_Log"
  ADD CONSTRAINT "Scale_Report_Log_task_log_id_fkey"
  FOREIGN KEY ("task_log_id")
  REFERENCES "public"."A_Task_logs_ver2"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

-- 3. ลบ orphaned rows ที่ vital_sign_id = NULL (vital sign ถูกลบแต่ rating ค้าง)
-- ต้องลบก่อน CHECK constraint เพราะ rows เหล่านี้จะ violate constraint
DELETE FROM "public"."Scale_Report_Log" WHERE "vital_sign_id" IS NULL;

-- 4. CHECK: อย่างน้อย 1 source ต้องมีค่า (vital_sign หรือ task_log)
ALTER TABLE "public"."Scale_Report_Log"
  ADD CONSTRAINT "scale_report_log_source_check"
  CHECK ("vital_sign_id" IS NOT NULL OR "task_log_id" IS NOT NULL);

-- 4. UNIQUE: ป้องกัน duplicate ratings จาก concurrent task completion
-- (1 task log + 1 subject = 1 rating เท่านั้น)
ALTER TABLE "public"."Scale_Report_Log"
  ADD CONSTRAINT "scale_report_log_task_subject_unique"
  UNIQUE ("task_log_id", "Subject_id");

-- 5. Index สำหรับ query by task_log_id
CREATE INDEX "idx_scale_report_log_task_log_id"
  ON "public"."Scale_Report_Log" ("task_log_id")
  WHERE "task_log_id" IS NOT NULL;

-- 6. Composite index สำหรับ generate-shift-summary query
-- (query pattern: WHERE resident_id = ? AND created_at BETWEEN ? AND ?)
CREATE INDEX IF NOT EXISTS "idx_scale_report_log_resident_created_desc"
  ON "public"."Scale_Report_Log" ("resident_id", "created_at" DESC);
