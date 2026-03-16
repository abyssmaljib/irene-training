-- =============================================================================
-- Migration: Fix 7 bugs ใน Shift Badge Cron System
-- =============================================================================
-- BUG-1: Missing Incharge filter ใน main cohort query
-- BUG-2: Notification ไม่ idempotent (wrap ใน badge insert check)
-- BUG-3: Partial failure — Point_Transaction fail → badge ยังอยู่
-- BUG-4: EXTRACT(MILLISECOND) คำนวณผิด → ใช้ EPOCH * 1000
-- BUG-5: NULL last_task_time tie-break ไม่ deterministic → เพิ่ม user_id
-- BUG-7: JSONB version ไม่ถูก validate
-- BUG-10: Audit log staff_count ใช้ re-query แทน variable
-- =============================================================================


-- =============================================================================
-- Fix _process_shift_badge_cohort: เพิ่ม version check + deterministic tie-break
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

  -- counters
  v_badges_awarded INT := 0;
  v_min_diff_sum INT;
BEGIN
  -- ===== 1. ดึง staff ทั้งหมดใน cohort =====
  -- Exclude: Incharge (shift leaders), isAuto (auto-generated records)
  -- ต้องมี shift_badge_stats (JSONB from app) + clock_out แล้ว
  -- [BUG-7 FIX] เพิ่ม version check เพื่อ forward compatibility
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
    -- [BUG-7 FIX] ต้องเป็น version 1 เท่านั้น
    AND COALESCE((c.shift_badge_stats->>'version')::int, 0) = 1
    AND COALESCE(c."Incharge", false) = false   -- ไม่รวม shift leaders
    AND COALESCE(c."isAuto", false) = false;     -- ไม่รวม auto-generated records

  -- นับจำนวน staff
  SELECT COUNT(*) INTO v_staff_count FROM _cohort_staff;

  -- ===== 2. ดึง active shift badges =====
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
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE completed_count > 0
          -- [BUG-5 FIX] เพิ่ม user_id เป็น deterministic tie-break สุดท้าย
          ORDER BY completed_count DESC, last_task_time ASC NULLS LAST, user_id ASC
          LIMIT 1;
        END IF;

        IF v_winner_user_id IS NOT NULL THEN
          PERFORM _award_shift_badge(
            v_winner_user_id, v_badge.id, v_winner_clock_id,
            v_badge.points, v_badge.name, v_badge.icon, p_shift, p_nursinghome_id
          );
          v_badges_awarded := v_badges_awarded + 1;
        END IF;

      WHEN 'shift_most_problems' THEN
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE problem_count > 0
          ORDER BY problem_count DESC, last_task_time ASC NULLS LAST, user_id ASC
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
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE kindness_count > 0
          ORDER BY kindness_count DESC, last_task_time ASC NULLS LAST, user_id ASC
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
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE avg_timing_diff < 999999
          ORDER BY avg_timing_diff ASC, last_task_time ASC NULLS LAST, user_id ASC
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
        NULL;

    END CASE;

  END LOOP;

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


-- =============================================================================
-- Fix _award_shift_badge: wrap points ใน SAVEPOINT เพื่อ partial failure safety
-- [BUG-3 FIX] ถ้า Point_Transaction fail → badge ยังอยู่ แค่ไม่ได้ points
-- [BUG-2 FIX] notification skip ถ้า badge ไม่ได้ถูก insert จริง
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
  -- [BUG-3 FIX] wrap ใน BEGIN/EXCEPTION เพื่อไม่ให้ fail ทำให้ badge rollback
  IF p_badge_points > 0 THEN
    BEGIN
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
      );
    EXCEPTION WHEN OTHERS THEN
      -- points fail ไม่ rollback badge (user ยังได้ badge แต่ไม่ได้ points)
      RAISE WARNING 'Point_Transaction insert failed for user % badge %: %',
        p_user_id, p_badge_name, SQLERRM;
    END;
  END IF;

  -- 3. INSERT notification
  BEGIN
    INSERT INTO notifications (
      title, body, user_id, type, reference_table, reference_id
    ) VALUES (
      '🏅 ได้รับเหรียญใหม่!',
      format('%s %s จาก%s', p_badge_icon, p_badge_name, p_shift),
      p_user_id,
      'badge',
      'training_user_badges',
      v_badge_record_id::text
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification insert failed for user % badge %: %',
      p_user_id, p_badge_name, SQLERRM;
  END;

END;
$$;


-- =============================================================================
-- Fix award_shift_badges_for_completed_shifts:
-- [BUG-1 FIX] เพิ่ม Incharge filter ใน cohort query
-- [BUG-4 FIX] ใช้ EPOCH * 1000 แทน EXTRACT(MILLISECOND)
-- [BUG-10 FIX] ใช้ v_staff_count จาก _process_shift_badge_cohort ใน audit log
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
  -- [BUG-10 FIX] เก็บ staff_count จาก temp table แทน re-query
  v_staff_count INT;
BEGIN
  -- ===== Concurrency lock =====
  -- Lock ID 867531 = unique สำหรับ shift badge cron
  PERFORM pg_advisory_xact_lock(867531);

  -- ===== ดึง cohorts ที่ต้อง process =====
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
      -- [BUG-1 FIX] เพิ่ม Incharge filter ให้ตรงกับ _process_shift_badge_cohort
      AND COALESCE(c."Incharge", false) = false
      -- [BUG-7 FIX] เฉพาะ version 1
      AND COALESCE((c.shift_badge_stats->>'version')::int, 0) = 1
      -- รอ 2 ชม. หลัง clock-out
      AND c.clock_out_timestamp <= NOW() - INTERVAL '2 hours'
      -- Lookback 7 วันเท่านั้น
      AND c.clock_in_timestamp >= NOW() - INTERVAL '7 days'
    LIMIT 20
  LOOP
    v_start_time := clock_timestamp();
    v_errors := ARRAY[]::TEXT[];

    BEGIN
      v_badges_awarded := _process_shift_badge_cohort(
        v_cohort.nursinghome_id,
        v_cohort.shift,
        v_cohort.adjust_date
      );

      v_total_badges := v_total_badges + v_badges_awarded;

    EXCEPTION WHEN OTHERS THEN
      v_errors := array_append(v_errors, SQLERRM);
      v_badges_awarded := 0;

      -- ยังคง mark processed เพื่อไม่ให้ retry loop ซ้ำเรื่อยๆ
      UPDATE clock_in_out_ver2
      SET badge_processed = true
      WHERE nursinghome_id = v_cohort.nursinghome_id
        AND shift = v_cohort.shift
        AND shift_badge_stats IS NOT NULL
        AND (shift_badge_stats->>'adjust_date')::date = v_cohort.adjust_date
        AND badge_processed = false
        AND clock_out_timestamp IS NOT NULL;
    END;

    -- [BUG-4 FIX] ใช้ EPOCH * 1000 แทน EXTRACT(MILLISECOND)
    v_processing_ms := (EXTRACT(EPOCH FROM clock_timestamp() - v_start_time) * 1000)::int;

    -- [BUG-10 FIX] ใช้ COUNT จาก _cohort_staff temp table แทน re-query
    -- (temp table อาจถูก DROP แล้วจาก ON COMMIT DROP ถ้ามี error,
    --  fallback ใช้ re-query เฉพาะกรณี error)
    BEGIN
      SELECT COUNT(*) INTO v_staff_count FROM _cohort_staff;
    EXCEPTION WHEN OTHERS THEN
      -- temp table ไม่มี (error case) → re-query
      SELECT COUNT(*) INTO v_staff_count
      FROM clock_in_out_ver2
      WHERE nursinghome_id = v_cohort.nursinghome_id
        AND shift = v_cohort.shift
        AND shift_badge_stats IS NOT NULL
        AND (shift_badge_stats->>'adjust_date')::date = v_cohort.adjust_date
        AND COALESCE("Incharge", false) = false
        AND COALESCE("isAuto", false) = false;
    END;

    INSERT INTO shift_badge_log (
      nursinghome_id, shift, adjust_date,
      staff_count, badges_awarded, errors, processing_ms
    ) VALUES (
      v_cohort.nursinghome_id,
      v_cohort.shift,
      v_cohort.adjust_date,
      v_staff_count,
      v_badges_awarded,
      CASE WHEN array_length(v_errors, 1) > 0 THEN v_errors ELSE NULL END,
      v_processing_ms
    );

    v_cohort_count := v_cohort_count + 1;
  END LOOP;

  -- ===== Summary log =====
  IF v_cohort_count > 0 THEN
    RAISE NOTICE 'Shift Badge Cron: processed % cohorts, awarded % badges',
      v_cohort_count, v_total_badges;
  END IF;

END;
$$;
