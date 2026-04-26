-- ============================================
-- RPC: family_overview_data v2 — optimize ตาม cross-review จาก Codex
-- ============================================
-- v1 (20260425030000): 175ms exec, buffers shared hit=124663
-- v2 changes:
--   1. WITH meds CTE — รวม scan medicine_summary 2 ครั้ง (stats + low_stock_top) → 1 ครั้ง
--   2. LANGUAGE sql แทน plpgsql — pure read-only function ไม่ต้อง plpgsql overhead
--   3. ลบ DECLARE/BEGIN/RETURN block (sql function inline ได้เลย)

CREATE OR REPLACE FUNCTION public.family_overview_data(p_resident_id bigint)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  WITH meds AS (
    -- Scan medicine_summary ครั้งเดียว — ใช้ทั้ง stats และ low_stock_top
    SELECT
      medicine_list_id,
      brand_name,
      generic_name,
      str,
      unit,
      prn,
      remaining_pills,
      predicted_run_out_date,
      run_out_within_7_days,
      run_out_within_15_days
    FROM medicine_summary
    WHERE resident_id = p_resident_id
      AND status = 'on'
  )
  SELECT jsonb_build_object(

    -- ====== สัญญาณชีพล่าสุด ======
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

    -- ====== นัดหมายที่จะถึง (1 รายการใกล้สุด) ======
    'upcoming_appointment', (
      SELECT to_jsonb(a.*)
      FROM (
        SELECT
          id, "Title", "Type", "dateTime", hospital, "isNPO"
        FROM "C_Calendar"
        WHERE resident_id = p_resident_id
          AND "dateTime" >= now()
        ORDER BY "dateTime" ASC
        LIMIT 1
      ) a
    ),

    -- ====== สถิติยา (จาก CTE meds) ======
    -- ⚠️ ยา PRN ไม่นับเป็น "ใกล้หมด" — usage rate ไม่คงที่ → predicted_run_out ไม่แม่น
    'medicine_stats', (
      SELECT jsonb_build_object(
        'regular_count', COUNT(*) FILTER (WHERE NOT prn),
        'prn_count',     COUNT(*) FILTER (WHERE prn),
        'low_stock_7d',  COUNT(*) FILTER (WHERE NOT prn AND run_out_within_7_days),
        'low_stock_15d', COUNT(*) FILTER (WHERE NOT prn AND run_out_within_15_days AND NOT run_out_within_7_days)
      )
      FROM meds
    ),

    -- ====== 3 ยาประจำที่จะหมดเร็วสุด (จาก CTE meds) ======
    'medicine_low_stock_top', COALESCE((
      SELECT jsonb_agg(to_jsonb(m.*) ORDER BY m.predicted_run_out_date ASC)
      FROM (
        SELECT
          medicine_list_id, brand_name, generic_name, str, unit,
          remaining_pills, predicted_run_out_date, run_out_within_7_days
        FROM meds
        WHERE NOT prn
          AND run_out_within_15_days
          AND predicted_run_out_date IS NOT NULL
        ORDER BY predicted_run_out_date ASC
        LIMIT 3
      ) m
    ), '[]'::jsonb),

    -- ====== Assessment subjects + scales (สำหรับ frontend คำนวณ trend) ======
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
            AND srl.created_at >= now() - interval '30 days'
        ), '[]'::jsonb)
      ))
      FROM (
        SELECT DISTINCT subject_id
        FROM "Resident_Report_Relation"
        WHERE resident_id = p_resident_id
      ) rrr
      JOIN "Report_Subject" rs ON rs.id = rrr.subject_id
    ), '[]'::jsonb)

  );
$$;

GRANT EXECUTE ON FUNCTION public.family_overview_data(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.family_overview_data(bigint) TO authenticated;

COMMENT ON FUNCTION public.family_overview_data(bigint) IS
'v2: Aggregate query สำหรับ family portal overview — ใช้ CTE รวม medicine_summary scan + LANGUAGE sql เร็วกว่า plpgsql';
