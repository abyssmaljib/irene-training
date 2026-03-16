-- Fix: explicit cast v_badge_record_id::text สำหรับ notification reference_id
-- หลังจาก column เปลี่ยนจาก bigint → text ใน 20260316110000

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
      RAISE WARNING 'Point_Transaction insert failed for user % badge %: %',
        p_user_id, p_badge_name, SQLERRM;
    END;
  END IF;

  -- 3. INSERT notification (reference_id เป็น text column แล้ว)
  BEGIN
    INSERT INTO notifications (
      title, body, user_id, type, reference_table, reference_id
    ) VALUES (
      '🏅 ได้รับเหรียญใหม่!',
      format('%s %s จาก%s', p_badge_icon, p_badge_name, p_shift),
      p_user_id,
      'badge',
      'training_user_badges',
      v_badge_record_id::text  -- explicit cast UUID → text
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification insert failed for user % badge %: %',
      p_user_id, p_badge_name, SQLERRM;
  END;

END;
$$;
