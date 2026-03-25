-- ============================================
-- Migration: med_photo_resize_queue + cron job
-- ============================================
-- สร้าง queue table สำหรับ resize รูปจัดยา 2C/3C ที่เก่ากว่า 14 วัน
-- pg_cron จะ:
--   1. ทุกวันตี 3 → INSERT รูปเก่า > 14 วัน ที่ยังไม่ resize เข้า queue
--   2. ทุก 5 นาที → เรียก Edge Function resize-old-med-photos ถ้ามี items ใน queue

-- ============================================
-- 1. Queue Table
-- ============================================
CREATE TABLE IF NOT EXISTS med_photo_resize_queue (
  id BIGSERIAL PRIMARY KEY,
  -- storage path ของรูปใน med-photos bucket (e.g. 'residents/3/3_2026-03-10_..._2C_1710000000000.jpg')
  storage_path TEXT NOT NULL,
  -- med_log_id ที่เป็นเจ้าของรูป (FK → A_Med_logs)
  med_log_id BIGINT REFERENCES "A_Med_logs"(id),
  -- ประเภทรูป: '2C' หรือ '3C'
  photo_type TEXT NOT NULL CHECK (photo_type IN ('2C', '3C')),
  -- status: pending → processing → done/error/skipped
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'done', 'error', 'skipped')),
  error_message TEXT,
  -- ขนาดก่อน/หลัง resize (bytes) — ใช้ track ว่าประหยัดได้เท่าไหร่
  original_size INTEGER,
  new_size INTEGER,
  -- timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  -- ป้องกัน insert ซ้ำ (ไฟล์เดียวกันไม่ควรอยู่ใน queue 2 ครั้ง)
  UNIQUE (storage_path)
);

-- Index สำหรับ claim query (pending items)
CREATE INDEX IF NOT EXISTS idx_med_photo_resize_queue_status
  ON med_photo_resize_queue (status) WHERE status = 'pending';

-- ============================================
-- 2. RPC: claim items จาก queue (SKIP LOCKED)
-- ============================================
-- ใช้ FOR UPDATE SKIP LOCKED เพื่อป้องกัน concurrent processing
CREATE OR REPLACE FUNCTION claim_med_photo_resize_queue(p_batch_size INTEGER DEFAULT 20)
RETURNS SETOF med_photo_resize_queue
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE med_photo_resize_queue
  SET status = 'processing'
  WHERE id IN (
    SELECT id FROM med_photo_resize_queue
    WHERE status = 'pending'
    ORDER BY created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$;

-- ============================================
-- 3. Function: Enqueue รูปเก่า > 14 วัน
-- ============================================
-- ดึง storage path จาก URL ใน A_Med_logs
-- URL format: https://xxx.supabase.co/storage/v1/object/public/med-photos/residents/3/...
-- Storage path: residents/3/...
CREATE OR REPLACE FUNCTION enqueue_old_med_photos()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count_2c INTEGER := 0;
  v_count_3c INTEGER := 0;
  v_cutoff_date TIMESTAMPTZ := NOW() - INTERVAL '14 days';
  v_storage_prefix TEXT := '/storage/v1/object/public/med-photos/';
BEGIN
  -- Insert 2C photos ที่เก่ากว่า 14 วัน
  INSERT INTO med_photo_resize_queue (storage_path, med_log_id, photo_type)
  SELECT
    -- ดึง path หลัง /storage/v1/object/public/med-photos/
    SUBSTRING("SecondCPictureUrl" FROM POSITION(v_storage_prefix IN "SecondCPictureUrl") + LENGTH(v_storage_prefix)),
    id,
    '2C'
  FROM "A_Med_logs"
  WHERE "SecondCPictureUrl" IS NOT NULL
    AND "SecondCPictureUrl" != ''
    AND created_at < v_cutoff_date
  ON CONFLICT (storage_path) DO NOTHING;

  GET DIAGNOSTICS v_count_2c = ROW_COUNT;

  -- Insert 3C photos ที่เก่ากว่า 14 วัน
  INSERT INTO med_photo_resize_queue (storage_path, med_log_id, photo_type)
  SELECT
    SUBSTRING("ThirdCPictureUrl" FROM POSITION(v_storage_prefix IN "ThirdCPictureUrl") + LENGTH(v_storage_prefix)),
    id,
    '3C'
  FROM "A_Med_logs"
  WHERE "ThirdCPictureUrl" IS NOT NULL
    AND "ThirdCPictureUrl" != ''
    AND "3C_time_stamps" IS NOT NULL
    AND "3C_time_stamps"::timestamptz < v_cutoff_date
  ON CONFLICT (storage_path) DO NOTHING;

  GET DIAGNOSTICS v_count_3c = ROW_COUNT;

  RETURN v_count_2c + v_count_3c;
END;
$$;

-- ============================================
-- 4. Cron Jobs
-- ============================================

-- ทุกวันตี 3 → enqueue รูปเก่า
SELECT cron.schedule(
  'enqueue-old-med-photos',
  '0 3 * * *',  -- ทุกวัน 03:00 UTC (10:00 เวลาไทย)
  $$SELECT enqueue_old_med_photos()$$
);

-- ทุก 5 นาที → เรียก Edge Function resize (ถ้ามี items ใน queue)
-- Edge Function จะ process batch ละ 20 รูป
SELECT cron.schedule(
  'resize-old-med-photos',
  '*/5 * * * *',  -- ทุก 5 นาที
  $$
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM med_photo_resize_queue WHERE status = 'pending' LIMIT 1)
    THEN
      net.http_post(
        url := 'https://amthgthvrxhlxpttioxu.supabase.co/functions/v1/resize-old-med-photos',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := '{}'::jsonb
      )
    ELSE NULL
  END
  $$
);

-- ============================================
-- 5. RLS — ปิดสำหรับ queue table (internal use only)
-- ============================================
ALTER TABLE med_photo_resize_queue ENABLE ROW LEVEL SECURITY;

-- ไม่สร้าง policy → ไม่มี user access ได้ (เฉพาะ service role + security definer functions)
