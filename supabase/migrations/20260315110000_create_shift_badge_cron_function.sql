-- =============================================================================
-- Migration: SQL functions สำหรับ Shift Badge Cron System
-- =============================================================================
-- Hybrid approach:
--   - App คำนวณ stats ตอน clock-out → save JSONB
--   - Cron อ่าน JSONB → เทียบ → award badges + points + notifications
--
-- 2 functions:
--   1. award_shift_badges_for_completed_shifts() — Main entry point (cron เรียก)
--   2. _process_shift_badge_cohort()             — Process 1 cohort (1 เวร 1 วัน 1 NH)
-- =============================================================================

-- =============================================================================
-- Function 2 (สร้างก่อนเพราะ Function 1 เรียกใช้):
-- _process_shift_badge_cohort — Process 1 cohort (เวร+วัน+NH)
-- =============================================================================
CREATE OR REPLACE FUNCTION public._process_shift_badge_cohort(
  p_nursinghome_id BIGINT,
  p_shift TEXT,
  p_adjust_date DATE
)
RETURNS INT  -- จำนวน badges ที่ award
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- staff records ใน cohort นี้
  v_staff RECORD;
  v_staff_count INT := 0;

  -- badge definitions
  v_badge RECORD;

  -- winner determination
  v_winner_user_id UUID;
  v_winner_clock_id BIGINT;
  v_winner_value NUMERIC;
  v_winner_time TEXT;
  v_current_value NUMERIC;
  v_current_time TEXT;

  -- counters
  v_badges_awarded INT := 0;
  v_min_diff_sum INT;

  -- temp vars for award
  v_txn_id BIGINT;
  v_badge_record_id UUID;
BEGIN
  -- ===== 1. ดึง staff ทั้งหมดใน cohort =====
  -- Exclude: Incharge (shift leaders), isAuto (auto-generated records)
  -- ต้องมี shift_badge_stats (JSONB from app) + clock_out แล้ว
  --
  -- DROP ก่อน CREATE เพราะ ON COMMIT DROP จะ drop ตอน transaction commit เท่านั้น
  -- ถ้า function นี้ถูกเรียกหลายครั้งใน loop (จาก award_shift_badges_for_completed_shifts)
  -- temp table จากรอบก่อนจะยังอยู่ → CREATE ซ้ำจะ ERROR (IMP-BUG-1 fix)
  DROP TABLE IF EXISTS _cohort_staff;

  CREATE TEMP TABLE _cohort_staff ON COMMIT DROP AS
  SELECT
    c.id AS clock_record_id,
    c.user_id,
    c.shift_badge_stats,
    -- ดึง stats จาก JSONB
    COALESCE((c.shift_badge_stats->>'completed_count')::int, 0) AS completed_count,
    COALESCE((c.shift_badge_stats->>'problem_count')::int, 0) AS problem_count,
    COALESCE((c.shift_badge_stats->>'kindness_count')::int, 0) AS kindness_count,
    COALESCE((c.shift_badge_stats->>'avg_timing_diff')::numeric, 999999) AS avg_timing_diff,
    COALESCE((c.shift_badge_stats->>'difficulty_diff_sum')::int, 0) AS difficulty_diff_sum,
    COALESCE((c.shift_badge_stats->>'norm_difficulty_sum')::int, 0) AS norm_difficulty_sum,
    c.shift_badge_stats->>'last_task_time' AS last_task_time,
    COALESCE((c.shift_badge_stats->>'total_tasks')::int, 0) AS total_tasks
  FROM clock_in_out_ver2 c
  WHERE c.nursinghome_id = p_nursinghome_id
    AND c.shift = p_shift
    AND (c.shift_badge_stats->>'adjust_date')::date = p_adjust_date
    AND c.badge_processed = false
    AND c.clock_out_timestamp IS NOT NULL
    AND c.shift_badge_stats IS NOT NULL
    AND COALESCE(c."Incharge", false) = false   -- ไม่รวม shift leaders
    AND COALESCE(c."isAuto", false) = false;     -- ไม่รวม auto-generated records

  -- นับจำนวน staff
  SELECT COUNT(*) INTO v_staff_count FROM _cohort_staff;

  -- ===== 2. ดึง active shift badges =====
  -- Loop ทุก badge ที่ category='shift' AND is_active=true
  FOR v_badge IN
    SELECT id, name, icon, points, requirement_type, requirement_value
    FROM training_badges
    WHERE category = 'shift' AND is_active = true
  LOOP
    -- ===== 3. Determine winner/qualifiers ตาม requirement_type =====
    v_winner_user_id := NULL;
    v_winner_clock_id := NULL;

    CASE v_badge.requirement_type

      -- ========== COMPETITIVE BADGES (ต้องมี ≥2 staff) ==========

      WHEN 'shift_most_completed' THEN
        -- ทำ task เสร็จมากที่สุด (ต้องมี ≥1 task, ≥2 staff)
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE completed_count > 0
          ORDER BY completed_count DESC, last_task_time ASC NULLS LAST
          LIMIT 1;
        END IF;

        -- Award winner (ถ้ามี)
        IF v_winner_user_id IS NOT NULL THEN
          PERFORM _award_shift_badge(
            v_winner_user_id, v_badge.id, v_winner_clock_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END IF;

      WHEN 'shift_most_problems' THEN
        -- เจอปัญหามากที่สุด (ต้องมี ≥1 problem, ≥2 staff)
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE problem_count > 0
          ORDER BY problem_count DESC, last_task_time ASC NULLS LAST
          LIMIT 1;
        END IF;

        IF v_winner_user_id IS NOT NULL THEN
          PERFORM _award_shift_badge(
            v_winner_user_id, v_badge.id, v_winner_clock_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END IF;

      WHEN 'shift_most_kindness' THEN
        -- ช่วยดูแล resident คนอื่นมากที่สุด (ต้องมี ≥1, ≥2 staff)
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE kindness_count > 0
          ORDER BY kindness_count DESC, last_task_time ASC NULLS LAST
          LIMIT 1;
        END IF;

        IF v_winner_user_id IS NOT NULL THEN
          PERFORM _award_shift_badge(
            v_winner_user_id, v_badge.id, v_winner_clock_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END IF;

      WHEN 'shift_best_timing' THEN
        -- ทำงานตรงเวลาที่สุด (ค่า timing diff น้อย = ดี, ≥2 staff)
        -- avg_timing_diff 999999 = ไม่มี task ที่มี expected time → exclude
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE avg_timing_diff < 999999  -- ต้องมี task ที่มี expected time
          ORDER BY avg_timing_diff ASC, last_task_time ASC NULLS LAST
          LIMIT 1;
        END IF;

        IF v_winner_user_id IS NOT NULL THEN
          PERFORM _award_shift_badge(
            v_winner_user_id, v_badge.id, v_winner_clock_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END IF;

      -- ========== THRESHOLD BADGES (ไม่ต้อง ≥2 staff, ทุกคนที่ผ่านได้) ==========

      WHEN 'shift_novice_rating' THEN
        -- ประเมินงานว่ายากกว่า norm (difficulty_diff_sum >= threshold)
        v_min_diff_sum := COALESCE(
          (v_badge.requirement_value->>'min_diff_sum')::int, 10
        );

        FOR v_staff IN
          SELECT user_id, clock_record_id FROM _cohort_staff
          WHERE difficulty_diff_sum >= v_min_diff_sum
        LOOP
          PERFORM _award_shift_badge(
            v_staff.user_id, v_badge.id, v_staff.clock_record_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END LOOP;

      WHEN 'shift_master_rating' THEN
        -- ประเมินงานว่าง่ายกว่า norm (norm_difficulty_sum >= threshold)
        v_min_diff_sum := COALESCE(
          (v_badge.requirement_value->>'min_diff_sum')::int, 10
        );

        FOR v_staff IN
          SELECT user_id, clock_record_id FROM _cohort_staff
          WHERE norm_difficulty_sum >= v_min_diff_sum
        LOOP
          PERFORM _award_shift_badge(
            v_staff.user_id, v_badge.id, v_staff.clock_record_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END LOOP;

      ELSE
        -- Unknown requirement_type → skip (forward compatible)
        NULL;

    END CASE;

  END LOOP;  -- end badge loop

  -- ===== 4. Mark ทุก record ใน cohort เป็น processed =====
  UPDATE clock_in_out_ver2
  SET badge_processed = true
  WHERE nursinghome_id = p_nursinghome_id
    AND shift = p_shift
    AND shift_badge_stats IS NOT NULL
    AND (shift_badge_stats->>'adjust_date')::date = p_adjust_date
    AND badge_processed = false
    AND clock_out_timestamp IS NOT NULL;

  RETURN v_badges_awarded;
END;
$$;

COMMENT ON FUNCTION _process_shift_badge_cohort IS
  'Process 1 shift cohort: เทียบ JSONB stats → award badges + points + notifications';


-- =============================================================================
-- Helper Function: _award_shift_badge
-- INSERT badge + points + notification ใน single call
-- ON CONFLICT DO NOTHING สำหรับ idempotency
-- =============================================================================
CREATE OR REPLACE FUNCTION public._award_shift_badge(
  p_user_id UUID,
  p_badge_id UUID,
  p_clock_record_id BIGINT,
  p_badge_points INT,
  p_badge_name TEXT,
  p_badge_icon TEXT,
  p_shift TEXT,
  p_nursinghome_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge_record_id UUID;
  v_txn_id BIGINT;
BEGIN
  -- 1. INSERT badge (ON CONFLICT = skip ถ้ามีแล้ว)
  INSERT INTO training_user_badges (user_id, badge_id, season_id, clock_record_id)
  VALUES (p_user_id, p_badge_id, NULL, p_clock_record_id)
  ON CONFLICT (clock_record_id, badge_id) WHERE clock_record_id IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_badge_record_id;

  -- ถ้า INSERT ถูก skip (duplicate) → ไม่ต้องทำ points/notification
  IF v_badge_record_id IS NULL THEN
    RETURN;
  END IF;

  -- 2. INSERT points transaction
  --    format ต้อง match app: transaction_type='badge_earned',
  --    description='ได้รับเหรียญ: {name}', reference_type='badge'
  IF p_badge_points > 0 THEN
    INSERT INTO "Point_Transaction" (
      user_id, point_change, transaction_type,
      description, reference_type, reference_id,
      nursinghome_id
    ) VALUES (
      p_user_id,
      p_badge_points,
      'badge_earned',
      'ได้รับเหรียญ: ' || p_badge_name,
      'badge',
      p_badge_id::text,
      p_nursinghome_id
    )
    RETURNING id INTO v_txn_id;
  END IF;

  -- 3. INSERT notification (in-app + triggers push via OneSignal)
  BEGIN
    INSERT INTO notifications (
      title, body, user_id, type, reference_table, reference_id
    ) VALUES (
      '🏅 ได้รับเหรียญใหม่!',
      format('%s %s จาก%s', p_badge_icon, p_badge_name, p_shift),
      p_user_id,
      'badge',
      'training_user_badges',
      v_badge_record_id
    );
  EXCEPTION WHEN OTHERS THEN
    -- notification fail ไม่ rollback badge+points (BUG-80 prevention)
    RAISE WARNING 'Notification insert failed for user % badge %: %',
      p_user_id, p_badge_name, SQLERRM;
  END;

END;
$$;

COMMENT ON FUNCTION _award_shift_badge IS
  'Award 1 shift badge: INSERT badge + points + notification (idempotent)';


-- =============================================================================
-- Function 1 (Main Entry Point):
-- award_shift_badges_for_completed_shifts — Cron เรียกทุก 12 ชม.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.award_shift_badges_for_completed_shifts()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cohort RECORD;
  v_badges_awarded INT;
  v_start_time TIMESTAMPTZ;
  v_processing_ms INT;
  v_errors TEXT[];
  v_cohort_count INT := 0;
  v_total_badges INT := 0;
BEGIN
  -- ===== Concurrency lock =====
  -- ป้องกัน 2 cron instances รันพร้อมกัน
  -- Lock ID 867531 = unique สำหรับ function นี้
  PERFORM pg_advisory_xact_lock(867531);

  -- ===== ดึง cohorts ที่ต้อง process =====
  -- Cohort = (nursinghome_id, shift, adjust_date) ที่ยังไม่ processed
  -- รอ ≥2 ชม. หลัง clock-out เพื่อให้ทุกคน clock out ก่อน
  -- Lookback แค่ 7 วัน เพื่อไม่ scan data เก่า
  -- Batch limit 20 cohorts ป้องกัน timeout (BUG-73)
  FOR v_cohort IN
    SELECT DISTINCT
      c.nursinghome_id,
      c.shift,
      (c.shift_badge_stats->>'adjust_date')::date AS adjust_date
    FROM clock_in_out_ver2 c
    WHERE c.badge_processed = false
      AND c.clock_out_timestamp IS NOT NULL
      AND c.shift_badge_stats IS NOT NULL
      AND c.shift IS NOT NULL
      AND COALESCE(c."isAuto", false) = false
      -- รอ 2 ชม. หลัง clock-out
      AND c.clock_out_timestamp <= NOW() - INTERVAL '2 hours'
      -- Lookback 7 วันเท่านั้น
      AND c.clock_in_timestamp >= NOW() - INTERVAL '7 days'
    LIMIT 20
  LOOP
    v_start_time := clock_timestamp();
    v_errors := ARRAY[]::TEXT[];

    -- ===== Error isolation per cohort (BUG-74, BUG-98) =====
    -- ถ้า cohort หนึ่ง fail → ไม่กระทบ cohort อื่น
    BEGIN
      v_badges_awarded := _process_shift_badge_cohort(
        v_cohort.nursinghome_id,
        v_cohort.shift,
        v_cohort.adjust_date
      );

      v_total_badges := v_total_badges + v_badges_awarded;

    EXCEPTION WHEN OTHERS THEN
      -- Log error แต่ไม่ rollback cohort อื่น
      v_errors := array_append(v_errors, SQLERRM);
      v_badges_awarded := 0;

      -- ยังคง mark processed เพื่อไม่ให้ retry loop ซ้ำเรื่อยๆ
      -- (ถ้า error ถาวร เช่น data corruption → ไม่มีประโยชน์ retry)
      UPDATE clock_in_out_ver2
      SET badge_processed = true
      WHERE nursinghome_id = v_cohort.nursinghome_id
        AND shift = v_cohort.shift
        AND shift_badge_stats IS NOT NULL
        AND (shift_badge_stats->>'adjust_date')::date = v_cohort.adjust_date
        AND badge_processed = false
        AND clock_out_timestamp IS NOT NULL;
    END;

    -- ===== Audit log =====
    v_processing_ms := EXTRACT(MILLISECOND FROM clock_timestamp() - v_start_time)::int;

    INSERT INTO shift_badge_log (
      nursinghome_id, shift, adjust_date,
      staff_count, badges_awarded, errors, processing_ms
    )
    SELECT
      v_cohort.nursinghome_id,
      v_cohort.shift,
      v_cohort.adjust_date,
      COUNT(*),
      v_badges_awarded,
      CASE WHEN array_length(v_errors, 1) > 0 THEN v_errors ELSE NULL END,
      v_processing_ms
    FROM clock_in_out_ver2
    WHERE nursinghome_id = v_cohort.nursinghome_id
      AND shift = v_cohort.shift
      AND shift_badge_stats IS NOT NULL
      AND (shift_badge_stats->>'adjust_date')::date = v_cohort.adjust_date;

    v_cohort_count := v_cohort_count + 1;
  END LOOP;

  -- ===== Summary log =====
  IF v_cohort_count > 0 THEN
    RAISE NOTICE 'Shift Badge Cron: processed % cohorts, awarded % badges',
      v_cohort_count, v_total_badges;
  END IF;

END;
$$;

COMMENT ON FUNCTION award_shift_badges_for_completed_shifts IS
  'Main cron entry point: เทียบ shift stats → award badges (ทุก 12 ชม.)';
