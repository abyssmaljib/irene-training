-- ============================================
-- Repair: สร้าง functions + cron ที่ fail จาก migration 20260324120000
-- ============================================
-- ปัญหา: GET DIAGNOSTICS syntax error ทำให้ function + cron ไม่ถูกสร้าง
-- Table + claim function สร้างสำเร็จแล้ว — migration นี้สร้างเฉพาะส่วนที่ขาด

-- ============================================
-- 1. Function: Enqueue รูปเก่า > 14 วัน (re-create)
-- ============================================
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
-- 2. Cron Jobs
-- ============================================

-- ทุกวันตี 3 → enqueue รูปเก่า
SELECT cron.schedule(
  'enqueue-old-med-photos',
  '0 3 * * *',
  $$SELECT enqueue_old_med_photos()$$
);

-- ทุก 5 นาที → เรียก Edge Function resize (ถ้ามี items ใน queue)
SELECT cron.schedule(
  'resize-old-med-photos',
  '*/5 * * * *',
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