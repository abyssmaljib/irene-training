-- =============================================================================
-- Migration: เตรียม schema สำหรับ Shift Badge Cron System
-- =============================================================================
-- แทนที่จะ award badge ทันทีตอน clock-out (ซึ่ง broken อยู่ — ROOT CAUSE: query
-- column ที่ไม่มีใน view), เปลี่ยนเป็น:
--   1. App คำนวณ stats ตอน clock-out → save JSONB ลง clock_in_out_ver2
--   2. Cron job เทียบ stats ของทุกคนในเวรเดียวกัน → award badges
--
-- JSONB schema ที่ app จะเขียน:
-- {
--   "completed_count": 15,      -- จำนวน task ที่เสร็จ
--   "problem_count": 3,         -- จำนวน task ที่เจอปัญหา
--   "kindness_count": 2,        -- จำนวน task ที่ช่วยดูแล resident คนอื่น
--   "avg_timing_diff": 12.5,    -- ค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
--   "difficulty_diff_sum": 8,   -- ผลรวม (user_rating - norm) เฉพาะที่ > 0
--   "norm_difficulty_sum": 10,  -- ผลรวม (norm - user_rating) เฉพาะที่ > 0
--   "last_task_time": "...",    -- ISO 8601 ของ task สุดท้าย (ใช้ tie-break)
--   "total_tasks": 20,          -- จำนวน tasks ทั้งหมด
--   "adjust_date": "2026-03-15",-- วันที่ปรับ (local, hour<7 shift back 1 day)
--   "version": 1                -- schema version สำหรับ forward compat
-- }
-- =============================================================================

-- 1. เพิ่ม JSONB stats column — app เขียนตอน clock-out
ALTER TABLE clock_in_out_ver2
  ADD COLUMN IF NOT EXISTS shift_badge_stats JSONB DEFAULT NULL;

COMMENT ON COLUMN clock_in_out_ver2.shift_badge_stats IS
  'JSONB stats ที่ app คำนวณตอน clock-out สำหรับ cron เทียบ badge';

-- 2. เพิ่ม badge_processed flag — cron set true หลัง process เสร็จ
ALTER TABLE clock_in_out_ver2
  ADD COLUMN IF NOT EXISTS badge_processed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN clock_in_out_ver2.badge_processed IS
  'true = cron เทียบ badge แล้ว สำหรับ clock record นี้';

-- 3. เพิ่ม clock_record_id ใน training_user_badges สำหรับ idempotency
--    ป้องกัน duplicate badge ถ้า cron retry
ALTER TABLE training_user_badges
  ADD COLUMN IF NOT EXISTS clock_record_id BIGINT;

COMMENT ON COLUMN training_user_badges.clock_record_id IS
  'FK ไป clock_in_out_ver2.id — ใช้สำหรับ idempotency (ป้องกัน badge ซ้ำ)';

-- 4. Partial UNIQUE index: ป้องกัน duplicate badge ต่อ clock record
--    เฉพาะ records ที่มี clock_record_id (shift badges จาก cron)
--    NULL clock_record_id (quiz/onboarding badges) ไม่ถูก enforce
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_badge_clock_record
  ON training_user_badges (clock_record_id, badge_id)
  WHERE clock_record_id IS NOT NULL;

-- 5. Performance index: cron query เฉพาะ unprocessed records ที่มี stats
--    index จะเล็กมากเพราะส่วนใหญ่ badge_processed = true
CREATE INDEX IF NOT EXISTS idx_clock_badge_unprocessed
  ON clock_in_out_ver2 (nursinghome_id, shift)
  WHERE badge_processed = false
    AND clock_out_timestamp IS NOT NULL
    AND shift_badge_stats IS NOT NULL;

-- 6. Audit log table — เก็บผลการ process แต่ละ cohort สำหรับ debug
CREATE TABLE IF NOT EXISTS shift_badge_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  nursinghome_id BIGINT,
  shift TEXT,                  -- 'เวรเช้า' หรือ 'เวรดึก'
  adjust_date DATE,
  staff_count INT,             -- จำนวน staff ใน cohort
  badges_awarded INT DEFAULT 0,-- จำนวน badges ที่ award
  skipped_reason TEXT,         -- เหตุผลที่ skip (เช่น staff < 2)
  errors TEXT[],               -- error messages (ถ้ามี)
  processing_ms INT            -- เวลาที่ใช้ process (ms)
);

COMMENT ON TABLE shift_badge_log IS
  'Audit log สำหรับ shift badge cron — ใช้ debug + monitoring';

-- 7. Disable "Chill Mode" badge (shift_most_dead_air)
--    เก็บสถิติก่อน ยังไม่ award (ตาม user decision)
UPDATE training_badges SET is_active = false
  WHERE requirement_type = 'shift_most_dead_air';

-- 8. Backfill: mark ทุก existing clocked-out shifts เป็น processed
--    เพื่อไม่ให้ cron พยายาม process shifts เก่าที่ไม่มี JSONB stats
UPDATE clock_in_out_ver2 SET badge_processed = true
  WHERE clock_out_timestamp IS NOT NULL;
