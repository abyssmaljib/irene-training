-- Fix: เปลี่ยน version check จาก = 1 เป็น >= 1
-- เพื่อ forward compatibility — ถ้าอนาคตเพิ่ม fields ใหม่ใน version 2
-- cron ยังประมวล fields เดิมจาก version 1 ได้

-- Fix ใน _process_shift_badge_cohort
CREATE OR REPLACE FUNCTION public._process_shift_badge_cohort(
  p_nursinghome_id BIGINT,
  p_shift TEXT,
  p_adjust_date DATE
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_staff RECORD;
  v_staff_count INT := 0;
  v_badge RECORD;
  v_winner_user_id UUID;
  v_winner_clock_id BIGINT;
  v_badges_awarded INT := 0;
  v_min_diff_sum INT;
BEGIN
  DROP TABLE IF EXISTS _cohort_staff;

  CREATE TEMP TABLE _cohort_staff ON COMMIT DROP AS
  SELECT
    c.id AS clock_record_id,
    c.user_id,
    c.shift_badge_stats,
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
    -- [FIX] >= 1 แทน = 1 เพื่อ forward compatibility
    AND COALESCE((c.shift_badge_stats->>'version')::int, 0) >= 1
    AND COALESCE(c."Incharge", false) = false
    AND COALESCE(c."isAuto", false) = false;

  SELECT COUNT(*) INTO v_staff_count FROM _cohort_staff;

  FOR v_badge IN
    SELECT id, name, icon, points, requirement_type, requirement_value
    FROM training_badges
    WHERE category = 'shift' AND is_active = true
  LOOP
    v_winner_user_id := NULL;
    v_winner_clock_id := NULL;

    CASE v_badge.requirement_type

      WHEN 'shift_most_completed' THEN
        IF v_staff_count >= 2 THEN
          SELECT user_id, clock_record_id
          INTO v_winner_user_id, v_winner_clock_id
          FROM _cohort_staff
          WHERE completed_count > 0
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


-- Fix ใน award_shift_badges_for_completed_shifts (main cohort query)
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
  v_staff_count INT;
BEGIN
  PERFORM pg_advisory_xact_lock(867531);

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
      AND COALESCE(c."Incharge", false) = false
      -- [FIX] >= 1 แทน = 1
      AND COALESCE((c.shift_badge_stats->>'version')::int, 0) >= 1
      AND c.clock_out_timestamp <= NOW() - INTERVAL '2 hours'
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
      UPDATE clock_in_out_ver2
      SET badge_processed = true
      WHERE nursinghome_id = v_cohort.nursinghome_id
        AND shift = v_cohort.shift
        AND shift_badge_stats IS NOT NULL
        AND (shift_badge_stats->>'adjust_date')::date = v_cohort.adjust_date
        AND badge_processed = false
        AND clock_out_timestamp IS NOT NULL;
    END;

    v_processing_ms := (EXTRACT(EPOCH FROM clock_timestamp() - v_start_time) * 1000)::int;

    BEGIN
      SELECT COUNT(*) INTO v_staff_count FROM _cohort_staff;
    EXCEPTION WHEN OTHERS THEN
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

  IF v_cohort_count > 0 THEN
    RAISE NOTICE 'Shift Badge Cron: processed % cohorts, awarded % badges',
      v_cohort_count, v_total_badges;
  END IF;

END;
$$;
