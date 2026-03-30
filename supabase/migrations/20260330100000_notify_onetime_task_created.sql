-- ============================================
-- notify_onetime_task_created RPC
-- ============================================
-- เมื่อสร้าง one-time task → ส่ง notification ไปหา staff ที่ clock in อยู่
-- และรับผิดชอบ resident นั้นๆ (อยู่ใน selected_resident_id_list)
--
-- ใช้ pattern เดียวกับ notify_ticket_activity:
-- - ไม่ส่งให้ตัวเอง (คนสร้าง)
-- - ไม่ส่งให้คนที่ลาออกแล้ว
-- - Push notification trigger อัตโนมัติจาก existing DB trigger on INSERT

CREATE OR REPLACE FUNCTION notify_onetime_task_created(
  p_resident_id bigint,
  p_task_title text,
  p_scheduled_date text,        -- "YYYY-MM-DD" วันที่กำหนดทำงาน
  p_c_task_id bigint,           -- C_Tasks.id สำหรับ reference
  p_nursinghome_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_id uuid;
  recipient record;
  resident_name text;
  noti_body text;
  new_noti_id bigint;
BEGIN
  -- ต้อง login อยู่
  caller_id := auth.uid();
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- ดึงชื่อ resident สำหรับใส่ใน notification body
  SELECT "i_Name_Surname" INTO resident_name
  FROM resident
  WHERE resident_id = p_resident_id;

  -- สร้าง body message
  noti_body := COALESCE(resident_name, 'ผู้พักอาศัย') || ' — ' || p_scheduled_date;

  -- หา staff ที่ clock in อยู่ + รับผิดชอบ resident นี้
  -- แล้ว insert notification ให้แต่ละคน
  FOR recipient IN
    SELECT DISTINCT c.user_id
    FROM clock_in_out_ver2 c
    JOIN user_info ui ON ui.id = c.user_id
    WHERE c.nursinghome_id = p_nursinghome_id
      AND c.clock_out_timestamp IS NULL                    -- ยัง clock in อยู่
      AND p_resident_id = ANY(c.selected_resident_id_list) -- รับผิดชอบ resident นี้
      AND c.user_id <> caller_id                           -- ไม่ส่งให้ตัวเอง
      AND (ui.employment_type IS NULL OR ui.employment_type <> 'resigned')
  LOOP
    -- Insert notification แล้วเก็บ ID สำหรับ action_url
    INSERT INTO notifications (
      user_id, title, body, type,
      reference_id, reference_table
    )
    VALUES (
      recipient.user_id,
      p_task_title,
      noti_body,
      'task',
      p_c_task_id::text,
      'C_Tasks'
    )
    RETURNING id INTO new_noti_id;

    -- อัพเดต action_url ด้วย notification ID ที่เพิ่งสร้าง
    -- format: irene://notifications/{id} — ให้ Flutter deep link ไปหน้า detail
    UPDATE notifications
    SET action_url = 'irene://notifications/' || new_noti_id
    WHERE id = new_noti_id;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION notify_onetime_task_created TO authenticated;
