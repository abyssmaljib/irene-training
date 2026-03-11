-- ============================================
-- Migration: med_verification_queue
-- ============================================
-- เปลี่ยนระบบ AI verification จาก "trigger เรียก Edge Function ตรง"
-- เป็น "trigger ใส่ queue → pg_cron poll queue → เรียก Edge Function เป็น batch"
--
-- ข้อดีของ queue-based approach:
-- 1. Trigger ไม่ต้องรอ HTTP response → ลด latency ของ INSERT/UPDATE
-- 2. Retry อัตโนมัติ เมื่อ Edge Function fail
-- 3. Batch processing → ลดจำนวน Edge Function calls
-- 4. ตรวจสอบ stale items (processing ค้าง > 5 นาที) → reset กลับมาทำใหม่
-- 5. ดู queue status ได้ง่าย (debug, monitoring)
--
-- Architecture:
-- A_Med_logs INSERT/UPDATE
--   → trigger_queue_med_verification() ใส่ row เข้า queue
--   → pg_cron ทุก 2 นาที: เช็ค queue → เรียก Edge Function batch
--   → Edge Function: claim_verification_queue() → process → update status

-- ============================================
-- Section 1: สร้างตาราง Queue
-- ============================================
-- เก็บ items ที่รอ AI verification
-- status flow: pending → processing → done/error
-- error items จะ retry อัตโนมัติ (สูงสุด 3 ครั้ง)

CREATE TABLE med_verification_queue (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- ข้อมูลที่ต้องส่งให้ Edge Function
  med_log_id BIGINT NOT NULL,                        -- FK → A_Med_logs.id
  photo_type TEXT NOT NULL CHECK (photo_type IN ('2C', '3C')),  -- ประเภทรูป (2C = ก่อนจัดยา, 3C = หลังจัดยา)
  resident_id INT NOT NULL,                          -- FK → residents.id
  meal TEXT NOT NULL,                                -- มื้อ เช่น 'ก่อนอาหารเช้า'
  photo_url TEXT NOT NULL,                           -- URL ของรูปที่ staff ถ่าย
  calendar_date DATE NOT NULL,                       -- วันที่ของ med log
  nursinghome_id INT NOT NULL,                       -- FK → nursinghomes.id

  -- Queue management
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'done', 'error')),
  retry_count INT NOT NULL DEFAULT 0,                -- จำนวนครั้งที่ retry แล้ว (max 3)
  error_message TEXT,                                -- รายละเอียด error (ถ้ามี)
  started_at TIMESTAMPTZ,                            -- เวลาที่เริ่ม processing
  completed_at TIMESTAMPTZ                           -- เวลาที่ done/error
);

-- Index สำหรับ query ที่ใช้บ่อย:

-- 1. หา pending items เรียงตาม created_at (FIFO)
CREATE INDEX idx_mvq_pending
  ON med_verification_queue (created_at)
  WHERE status = 'pending';

-- 2. หา processing items ที่ค้างนานเกินไป (stale > 5 นาที)
CREATE INDEX idx_mvq_processing_stale
  ON med_verification_queue (started_at)
  WHERE status = 'processing';

-- 3. หา error items ที่ยัง retry ได้ (retry_count < 3)
CREATE INDEX idx_mvq_error_retry
  ON med_verification_queue (created_at)
  WHERE status = 'error' AND retry_count < 3;

-- RLS: เปิดแต่ไม่สร้าง policy → เข้าถึงได้เฉพาะ trigger (SECURITY DEFINER) และ service_role
ALTER TABLE med_verification_queue ENABLE ROW LEVEL SECURITY;


-- ============================================
-- Section 2: ลบ Trigger เดิมที่เรียก Edge Function ตรง
-- ============================================
-- trigger เดิมจาก migration 20260310010000_add_med_ai_trigger.sql
-- เรียก net.http_post() ตรงจาก trigger → ช้าและไม่มี retry

DROP TRIGGER IF EXISTS tr_verify_med_photo ON "A_Med_logs";
DROP FUNCTION IF EXISTS trigger_verify_med_photo();


-- ============================================
-- Section 3: สร้าง Trigger Function ใหม่ (queue-based)
-- ============================================
-- แทนที่จะเรียก Edge Function ตรง → ใส่ข้อมูลเข้า queue แทน
-- ข้อดี: trigger ทำงานเร็วมาก (แค่ INSERT row) ไม่ต้องรอ HTTP
-- SECURITY DEFINER: ให้ trigger bypass RLS เพื่อ INSERT เข้า queue ได้

CREATE OR REPLACE FUNCTION trigger_queue_med_verification()
RETURNS TRIGGER AS $$
DECLARE
  _nursinghome_id INT;
BEGIN
  -- ดึง nursinghome_id จากตาราง residents
  -- ใช้เพื่อ filter ตอน query และส่งให้ Edge Function
  SELECT nursinghome_id INTO _nursinghome_id
  FROM residents
  WHERE id = NEW.resident_id;

  -- ถ้าหา nursinghome_id ไม่เจอ → ข้ามไป (resident อาจถูกลบหรือ data ไม่ครบ)
  IF _nursinghome_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- ============================================
  -- ตรวจ 2C photo (SecondCPictureUrl)
  -- ============================================
  -- INSERT: ถ้ามีรูป → queue
  -- UPDATE: ถ้ารูปเปลี่ยน (IS DISTINCT FROM จัดการ NULL ให้อัตโนมัติ) → queue
  IF NEW."SecondCPictureUrl" IS NOT NULL AND (
    TG_OP = 'INSERT' OR OLD."SecondCPictureUrl" IS DISTINCT FROM NEW."SecondCPictureUrl"
  ) THEN
    INSERT INTO med_verification_queue
      (med_log_id, photo_type, resident_id, meal, photo_url, calendar_date, nursinghome_id)
    VALUES
      (NEW.id, '2C', NEW.resident_id, NEW.meal, NEW."SecondCPictureUrl", NEW."Created_Date", _nursinghome_id);
  END IF;

  -- ============================================
  -- ตรวจ 3C photo (ThirdCPictureUrl)
  -- ============================================
  IF NEW."ThirdCPictureUrl" IS NOT NULL AND (
    TG_OP = 'INSERT' OR OLD."ThirdCPictureUrl" IS DISTINCT FROM NEW."ThirdCPictureUrl"
  ) THEN
    INSERT INTO med_verification_queue
      (med_log_id, photo_type, resident_id, meal, photo_url, calendar_date, nursinghome_id)
    VALUES
      (NEW.id, '3C', NEW.resident_id, NEW.meal, NEW."ThirdCPictureUrl", NEW."Created_Date", _nursinghome_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- Section 4: สร้าง Trigger บน A_Med_logs
-- ============================================
-- AFTER INSERT OR UPDATE — trigger เมื่อมีรูปใหม่หรือรูปเปลี่ยน
-- เฉพาะ column SecondCPictureUrl หรือ ThirdCPictureUrl

CREATE TRIGGER tr_queue_med_verification
  AFTER INSERT OR UPDATE OF "SecondCPictureUrl", "ThirdCPictureUrl"
  ON "A_Med_logs"
  FOR EACH ROW
  EXECUTE FUNCTION trigger_queue_med_verification();


-- ============================================
-- Section 5: RPC Function สำหรับ Atomic Claim (ให้ Edge Function เรียก)
-- ============================================
-- Edge Function เรียก claim_verification_queue() เพื่อ "จอง" items จาก queue
-- ใช้ FOR UPDATE SKIP LOCKED เพื่อป้องกัน race condition
-- (ถ้ามีหลาย worker ทำงานพร้อมกัน จะไม่จองซ้ำกัน)
--
-- Items ที่ claim ได้:
-- 1. status = 'pending' → ยังไม่เคย process
-- 2. status = 'error' AND retry_count < 3 → error แต่ยัง retry ได้
-- 3. status = 'processing' AND started_at < NOW() - INTERVAL '5 minutes' → ค้างนานเกินไป (stale)
--
-- เรียงลำดับ: pending ก่อน error/stale, แล้วเรียงตาม created_at (FIFO)

CREATE OR REPLACE FUNCTION claim_verification_queue(batch_limit INT DEFAULT 5)
RETURNS SETOF med_verification_queue AS $$
BEGIN
  RETURN QUERY
  UPDATE med_verification_queue
  SET
    status = 'processing',
    started_at = NOW(),
    -- เพิ่ม retry_count เมื่อ re-claim จาก error/stale (ป้องกัน retry ไม่สิ้นสุด)
    -- pending → 0 (ไม่เปลี่ยน), error/stale → +1
    retry_count = CASE
      WHEN med_verification_queue.status = 'pending' THEN med_verification_queue.retry_count
      ELSE med_verification_queue.retry_count + 1
    END
  WHERE id IN (
    SELECT id
    FROM med_verification_queue
    WHERE
      -- 3 กลุ่มที่ claim ได้
      status = 'pending'
      OR (status = 'error' AND retry_count < 3)
      OR (status = 'processing' AND started_at < NOW() - INTERVAL '5 minutes')
    ORDER BY
      -- pending มาก่อน error/stale (priority 0 vs 1)
      CASE WHEN status = 'pending' THEN 0 ELSE 1 END,
      -- ภายในกลุ่มเดียวกัน เรียงตาม created_at (เก่าก่อน)
      created_at
    LIMIT batch_limit
    -- FOR UPDATE SKIP LOCKED: lock rows ที่เลือก, ข้าม rows ที่ถูก lock อยู่
    -- ป้องกัน race condition เมื่อมีหลาย worker
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- Section 6: pg_cron Job — Poll queue ทุก 2 นาที
-- ============================================
-- ทำงานทุก 2 นาที:
-- 1. เช็คว่ามี items ที่ต้อง process ไหม (pending/error-retry/stale)
-- 2. ถ้าไม่มี → จบ (ไม่เรียก Edge Function เปล่าๆ)
-- 3. ถ้ามี → ดึง service_role_key จาก vault → เรียก Edge Function batch

-- ลบ cron job เดิมถ้ามี (กันซ้ำ)
-- ใช้ DO block + EXCEPTION เพราะ cron.unschedule จะ error ถ้า job ไม่มี
DO $$ BEGIN
  PERFORM cron.unschedule('process-med-verification-queue');
EXCEPTION WHEN OTHERS THEN
  -- job ยังไม่มี → ไม่ต้องทำอะไร
END $$;

SELECT cron.schedule(
  'process-med-verification-queue',   -- ชื่อ job (ใช้อ้างอิงตอน unschedule)
  '*/2 * * * *',                      -- ทุก 2 นาที
  $$
  DO $body$
  DECLARE
    _service_role_key TEXT;
  BEGIN
    -- Step 1: เช็คว่ามี items ที่ต้อง process ไหม
    -- ถ้าไม่มี → จบเลย ไม่ต้องเรียก Edge Function
    IF NOT EXISTS (
      SELECT 1
      FROM med_verification_queue
      WHERE
        status = 'pending'
        OR (status = 'error' AND retry_count < 3)
        OR (status = 'processing' AND started_at < NOW() - INTERVAL '5 minutes')
      LIMIT 1
    ) THEN
      RETURN;
    END IF;

    -- Step 2: ดึง service_role_key จาก vault
    SELECT decrypted_secret INTO _service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    -- ถ้าไม่มี key → ข้ามไป (ยังไม่ได้ setup)
    IF _service_role_key IS NULL THEN
      RAISE LOG 'process-med-verification-queue: no service_role_key in vault';
      RETURN;
    END IF;

    -- Step 3: เรียก Edge Function batch ผ่าน pg_net
    -- Edge Function จะเรียก claim_verification_queue() เองเพื่อจอง items
    PERFORM net.http_post(
      url := 'https://amthgthvrxhlxpttioxu.supabase.co/functions/v1/verify-med-photo-batch',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || _service_role_key
      ),
      body := '{}'::jsonb
    );
  END;
  $body$;
  $$
);


-- ============================================
-- Section 7: Backfill — ใส่ queue สำหรับ med logs 7 วันย้อนหลังที่ยังไม่ได้ตรวจ
-- ============================================
-- หา med logs ที่มีรูป แต่ยังไม่มี AI verification ที่ตรงกัน
-- ใส่เข้า queue เพื่อให้ cron job มา process

-- Backfill 2C photos
INSERT INTO med_verification_queue
  (med_log_id, photo_type, resident_id, meal, photo_url, calendar_date, nursinghome_id)
SELECT
  ml.id,
  '2C',
  ml.resident_id,
  ml.meal,
  ml."SecondCPictureUrl",
  ml."Created_Date",
  r.nursinghome_id
FROM "A_Med_logs" ml
JOIN residents r ON r.id = ml.resident_id
WHERE
  -- มีรูป 2C
  ml."SecondCPictureUrl" IS NOT NULL
  -- 7 วันย้อนหลัง
  AND ml."Created_Date" >= CURRENT_DATE - INTERVAL '7 days'
  -- มี nursinghome_id
  AND r.nursinghome_id IS NOT NULL
  -- ยังไม่มี AI verification ที่ตรงกัน (med_log_id + photo_type)
  AND NOT EXISTS (
    SELECT 1
    FROM "A_Med_AI_Verification" av
    WHERE av.med_log_id = ml.id
      AND av.photo_type = '2C'
  )
  -- กัน duplicate กับ items ที่ trigger เพิ่งใส่เข้า queue
  AND NOT EXISTS (
    SELECT 1
    FROM med_verification_queue q
    WHERE q.med_log_id = ml.id
      AND q.photo_type = '2C'
      AND q.status IN ('pending', 'processing')
  );

-- Backfill 3C photos
INSERT INTO med_verification_queue
  (med_log_id, photo_type, resident_id, meal, photo_url, calendar_date, nursinghome_id)
SELECT
  ml.id,
  '3C',
  ml.resident_id,
  ml.meal,
  ml."ThirdCPictureUrl",
  ml."Created_Date",
  r.nursinghome_id
FROM "A_Med_logs" ml
JOIN residents r ON r.id = ml.resident_id
WHERE
  -- มีรูป 3C
  ml."ThirdCPictureUrl" IS NOT NULL
  -- 7 วันย้อนหลัง
  AND ml."Created_Date" >= CURRENT_DATE - INTERVAL '7 days'
  -- มี nursinghome_id
  AND r.nursinghome_id IS NOT NULL
  -- ยังไม่มี AI verification ที่ตรงกัน
  AND NOT EXISTS (
    SELECT 1
    FROM "A_Med_AI_Verification" av
    WHERE av.med_log_id = ml.id
      AND av.photo_type = '3C'
  )
  -- กัน duplicate กับ items ที่ trigger เพิ่งใส่เข้า queue
  AND NOT EXISTS (
    SELECT 1
    FROM med_verification_queue q
    WHERE q.med_log_id = ml.id
      AND q.photo_type = '3C'
      AND q.status IN ('pending', 'processing')
  );
