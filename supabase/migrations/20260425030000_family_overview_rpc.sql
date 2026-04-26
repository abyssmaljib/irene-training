-- ============================================
-- RPC: family_overview_data — รวม 5 queries ของ family portal overview ให้เป็น 1 round-trip
-- ============================================
-- ที่ใช้: app/(public)/family/[token]/page.tsx ใน irene-training-admin (Next.js admin)
-- เดิม: page.tsx ยิง 5 queries (vitals + appts + medicine + relations + (subjects&logs))
-- ใหม่: ยิง RPC เดียวที่ aggregate ทุกอย่างเป็น JSONB
-- เป้าหมาย: ลด round-trip จาก 5 → 1 (saving 50-150ms cold cache)
--
-- Security: SECURITY DEFINER ตอน return — bypass RLS เหมือน service-role client เดิม
--           ปลอดภัยเพราะ resident_id ที่ส่งมาเป็น lookup key ที่ already validated
--           จาก med_share_token (UUID ที่ random ใน residents) — ดู getResident.ts
--           callee ใช้ service-role เพื่อบายพาส RLS อยู่แล้ว → ฟังก์ชันนี้แค่ pre-aggregate
-- Stability: STABLE — ทุก query เป็น read-only, ไม่ modify state

CREATE OR REPLACE FUNCTION public.family_overview_data(p_resident_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_thirty_days   timestamptz := now() - interval '30 days';
  v_result        jsonb;
BEGIN
  SELECT jsonb_build_object(

    -- ====== สัญญาณชีพล่าสุด (1 row หรือ null) ======
    'latest_vital', (
      SELECT to_jsonb(v.*)
      FROM (
        SELECT
          id, created_at,
          "Temp", "sBP", "dBP", "PR", "O2", "RR", "DTX", "Insulin",
          user_nickname, vital_signs_status
        FROM combined_vitalsign_details_view
        WHERE resident_id = p_resident_id
        ORDER BY created_at DESC
        LIMIT 1
      ) v
    ),

    -- ====== นัดหมายที่จะถึง (อันใกล้สุด 1 รายการ) ======
    'upcoming_appointment', (
      SELECT to_jsonb(a.*)
      FROM (
        SELECT
          id, "Title", "Type", "dateTime", hospital, "isNPO"
        FROM "C_Calendar"
        WHERE resident_id = p_resident_id
          AND "dateTime" >= v_now
        ORDER BY "dateTime" ASC
        LIMIT 1
      ) a
    ),

    -- ====== สถิติยา (count + low-stock buckets) ======
    -- ⚠️ ยา PRN ไม่นับเป็น "ใกล้หมด" เพราะ usage rate ไม่คงที่ → predicted_run_out_date ไม่แม่น
    'medicine_stats', (
      SELECT jsonb_build_object(
        'regular_count', COUNT(*) FILTER (WHERE NOT prn),
        'prn_count',     COUNT(*) FILTER (WHERE prn),
        'low_stock_7d',  COUNT(*) FILTER (WHERE NOT prn AND run_out_within_7_days),
        'low_stock_15d', COUNT(*) FILTER (WHERE NOT prn AND run_out_within_15_days AND NOT run_out_within_7_days)
      )
      FROM medicine_summary
      WHERE resident_id = p_resident_id
        AND status = 'on'
    ),

    -- ====== 3 ยาประจำที่จะหมดเร็วสุด (ใน 15 วัน) — ไม่รวม PRN ======
    'medicine_low_stock_top', COALESCE((
      SELECT jsonb_agg(to_jsonb(m.*) ORDER BY m.predicted_run_out_date ASC)
      FROM (
        SELECT
          medicine_list_id,
          brand_name,
          generic_name,
          str,
          unit,
          remaining_pills,
          predicted_run_out_date,
          run_out_within_7_days
        FROM medicine_summary
        WHERE resident_id = p_resident_id
          AND status = 'on'
          AND NOT prn
          AND run_out_within_15_days
          AND predicted_run_out_date IS NOT NULL
        ORDER BY predicted_run_out_date ASC
        LIMIT 3
      ) m
    ), '[]'::jsonb),

    -- ====== Assessment subjects + scales array (สำหรับให้ frontend คำนวณ trend) ======
    -- Logic ลำดับเดียวกับ scale_report_log_detailed_view — JOIN Scale_Report_Log + Report_Choice
    -- เพื่อ resolve "Choice_id" → "Scale" (1-5)
    'assessment_subjects', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',     rs.id,
        'name',   rs."Subject",
        'scales', COALESCE((
          SELECT jsonb_agg(rc."Scale" ORDER BY srl.created_at)
          FROM "Scale_Report_Log" srl
          JOIN "Report_Choice" rc
            ON rc."Subject" = srl."Subject_id"
           AND rc."Scale"   = srl."Choice_id"
           AND ((rc.sub_item_id IS NULL AND srl.sub_item_id IS NULL)
                OR rc.sub_item_id = srl.sub_item_id)
          WHERE srl.resident_id = p_resident_id
            AND srl."Subject_id" = rs.id
            AND srl.created_at >= v_thirty_days
        ), '[]'::jsonb)
      ))
      FROM (
        SELECT DISTINCT subject_id
        FROM "Resident_Report_Relation"
        WHERE resident_id = p_resident_id
      ) rrr
      JOIN "Report_Subject" rs ON rs.id = rrr.subject_id
    ), '[]'::jsonb)

  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Grant สิทธิ์ให้ service_role + authenticated เรียกได้
-- (family portal ใช้ service-role client → bypass RLS → เรียก RPC ได้)
GRANT EXECUTE ON FUNCTION public.family_overview_data(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.family_overview_data(bigint) TO authenticated;

COMMENT ON FUNCTION public.family_overview_data(bigint) IS
'Aggregate query สำหรับ family portal overview page — รวม latest vital, upcoming appointment, medicine stats + low-stock list, assessment subjects+scales ใน RPC เดียว เพื่อลด round-trip จาก 5→1';
