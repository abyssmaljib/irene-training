-- ============================================================
-- อัพเดต scale_report_log_detailed_view
-- เปลี่ยน JOIN vitalSign → LEFT JOIN เพื่อรองรับ task-based entries
-- เพิ่ม task_log_id column (ต้อง DROP + CREATE เพราะ column order เปลี่ยน)
-- ============================================================

DROP VIEW IF EXISTS "public"."scale_report_log_detailed_view";

CREATE VIEW "public"."scale_report_log_detailed_view" WITH ("security_invoker"='off') AS
SELECT
  "srl"."id",
  "srl"."created_at",
  "srl"."vital_sign_id",
  "srl"."task_log_id",
  "srl"."resident_id",
  "srl"."Subject_id" AS "subject_id",
  "rs"."Subject" AS "subject_text",
  "rs"."Description" AS "subject_description",
  "rc"."Scale" AS "choice_scale",
  "rc"."Choice" AS "choice_text",
  "rc"."represent_url",
  "vs"."shift" AS "vital_sign_shift"
FROM "public"."Scale_Report_Log" "srl"
  JOIN "public"."Report_Subject" "rs" ON ("srl"."Subject_id" = "rs"."id")
  JOIN "public"."Report_Choice" "rc" ON (
    "rc"."Subject" = "srl"."Subject_id"
    AND "rc"."Scale" = "srl"."Choice_id"
  )
  -- LEFT JOIN: vital_sign_id อาจเป็น NULL สำหรับ task-based entries
  LEFT JOIN "public"."vitalSign" "vs" ON ("srl"."vital_sign_id" = "vs"."id");

-- Re-grant permissions (DROP removes grants)
GRANT ALL ON TABLE "public"."scale_report_log_detailed_view" TO anon, authenticated, service_role;
