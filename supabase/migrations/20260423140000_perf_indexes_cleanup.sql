-- =====================================================
-- Performance: Drop duplicate indexes + add missing FK indexes
-- =====================================================
-- ที่มา: Supabase advisor performance lints
-- รายละเอียด:
--   1) DROP duplicate indexes 21 รายการ (เก็บตัวที่มี name ดีกว่า)
--      - ทุก pair ที่ drop ตรวจสอบแล้วว่า:
--        * structure เหมือนกันทุกประการ (table, columns, uniqueness, partial WHERE)
--        * หรือเป็น redundant case mismatch (A_Tasks_xxx_idx vs a_tasks_xxx_idx)
--      - ❌ skip pair ที่ structure ต่างกัน (partial WHERE clause, GIST vs btree, ฯลฯ)
--      - ❌ skip pair ที่ drop UNIQUE → จะเสีย uniqueness constraint
--
--   2) ADD missing FK indexes 25 รายการ (focus: hot tables ที่ join บ่อย)
--      - med_reconciliation_warnings (5 FKs) — medicine reconciliation page
--      - billing tables — invoice list, payment lookups
--      - payroll snapshots — finalize/audit lookups
--      - ticket / appointment / doctor visit linking
--
-- Impact:
--   - DROP: ลด disk + เร่ง INSERT/UPDATE บน table ที่กระทบ
--   - ADD: เร่ง JOIN/lookup บน FK 2-10x
--
-- Safety:
--   - ใช้ IF EXISTS / IF NOT EXISTS — idempotent (run ซ้ำได้)
--   - ไม่แตะ view, column, RLS — ไม่กระทบ Flutter app
--   - สร้าง index แบบ regular (ไม่ใช้ CONCURRENTLY เพราะ migration runs ใน transaction)
--     → table จะ lock ช่วงสร้าง index เป็นวินาที (ส่วนใหญ่ table เล็ก ไม่กระทบ user)


-- =====================================================
-- 1. DROP DUPLICATE INDEXES (21 รายการ)
-- =====================================================

-- A_Med_AI_Verification: 2 UNIQUE indexes ซ้ำเป๊ะบน (med_log_id, photo_type)
-- ตัวที่จะ drop เป็น UNIQUE CONSTRAINT (ไม่ใช่ index ธรรมดา) ต้องใช้ DROP CONSTRAINT
-- ตัวที่เก็บไว้ (uq_ai_verify_medlog_phototype) ก็ UNIQUE เหมือนกัน → ไม่เสีย uniqueness
ALTER TABLE public."A_Med_AI_Verification" DROP CONSTRAINT IF EXISTS uq_med_ai_verify_log_type;

-- A_Med_logs: created_at DESC vs ASC — btree ใช้ scan ได้ทั้ง 2 ทิศ
DROP INDEX IF EXISTS public."A_Med_logs_created_at_idx";

-- A_Task_logs: 3 pairs ของ case mismatch (capital vs lowercase)
DROP INDEX IF EXISTS public.a_task_logs_task_id_idx;
DROP INDEX IF EXISTS public.a_task_logs_task_repeat_id_idx;
DROP INDEX IF EXISTS public.a_task_logs_completed_by_idx;

-- A_Task_logs_ver2: case mismatch
DROP INDEX IF EXISTS public.a_task_logs_ver2_task_id;

-- A_Tasks: 2 pairs ของ case mismatch
DROP INDEX IF EXISTS public.a_tasks_nursinghome_id_idx;
DROP INDEX IF EXISTS public.a_tasks_resident_id_idx;

-- Point_Transaction: nh vs nursinghome (named differently, identical structure)
DROP INDEX IF EXISTS public.idx_point_transaction_nursinghome;

-- Post_Tags: post vs post_id, tag vs tag_id (identical)
DROP INDEX IF EXISTS public.idx_post_tags_post_id;
DROP INDEX IF EXISTS public.idx_post_tags_tag_id;

-- PublicHoliday: keep UNIQUE constraint, drop redundant non-unique
DROP INDEX IF EXISTS public.idx_public_holiday_nh_date;

-- medicine_List: identical
DROP INDEX IF EXISTS public.idx_medicine_list_resident;

-- postDoneBy: post vs post_id (identical)
DROP INDEX IF EXISTS public.idx_postdoneby_post_id;

-- training_quiz_answers: 2 pairs (idx_answers_* vs idx_tqa_*)
DROP INDEX IF EXISTS public.idx_tqa_question_id;
DROP INDEX IF EXISTS public.idx_tqa_session_id;

-- training_quiz_sessions: 2 pairs (idx_sessions_* vs idx_tqs_*)
DROP INDEX IF EXISTS public.idx_tqs_user_id;
DROP INDEX IF EXISTS public.idx_tqs_progress_id;

-- training_user_badges: badges_user vs tub_user_id
DROP INDEX IF EXISTS public.idx_tub_user_id;

-- training_user_progress: progress_topic vs tup_topic_id
DROP INDEX IF EXISTS public.idx_tup_topic_id;

-- invitations: 3 indexes บน nursinghome_ID — ตัว plain ไม่จำเป็น (ตัว nh + composite cover แล้ว)
DROP INDEX IF EXISTS public.idx_invitations_nursinghome_id;


-- =====================================================
-- 2. ADD FK INDEXES (25 รายการ — focus hot tables)
-- =====================================================

-- med_reconciliation_warnings — medicine reconciliation page (heavy joins)
CREATE INDEX IF NOT EXISTS idx_med_reconciliation_warnings_acknowledged_by
  ON public.med_reconciliation_warnings (acknowledged_by);
CREATE INDEX IF NOT EXISTS idx_med_reconciliation_warnings_ai_recommendation_id
  ON public.med_reconciliation_warnings (ai_recommendation_id);
CREATE INDEX IF NOT EXISTS idx_med_reconciliation_warnings_conflicting_med_db_id
  ON public.med_reconciliation_warnings (conflicting_med_db_id);
CREATE INDEX IF NOT EXISTS idx_med_reconciliation_warnings_resolved_by
  ON public.med_reconciliation_warnings (resolved_by);
CREATE INDEX IF NOT EXISTS idx_med_reconciliation_warnings_trigger_med_db_id
  ON public.med_reconciliation_warnings (trigger_med_db_id);

-- A_Med_logs — QC reviewer joins
CREATE INDEX IF NOT EXISTS "idx_A_Med_logs_qc_2c_reviewer"
  ON public."A_Med_logs" (qc_2c_reviewer);
CREATE INDEX IF NOT EXISTS "idx_A_Med_logs_qc_3c_reviewer"
  ON public."A_Med_logs" (qc_3c_reviewer);

-- A_Task_logs_ver2 — task analytics joins (used in difficulty ratings, problem resolution)
CREATE INDEX IF NOT EXISTS "idx_A_Task_logs_ver2_difficulty_rated_by"
  ON public."A_Task_logs_ver2" (difficulty_rated_by);
CREATE INDEX IF NOT EXISTS "idx_A_Task_logs_ver2_resolved_by"
  ON public."A_Task_logs_ver2" (resolved_by);

-- B_Doctor_Visit_Summary — doctor visit assignment + post linking
CREATE INDEX IF NOT EXISTS "idx_B_Doctor_Visit_Summary_assigned_staff_id"
  ON public."B_Doctor_Visit_Summary" (assigned_staff_id);
CREATE INDEX IF NOT EXISTS "idx_B_Doctor_Visit_Summary_post_id"
  ON public."B_Doctor_Visit_Summary" (post_id);

-- B_Ticket — ticket → appointment / doctor visit join
CREATE INDEX IF NOT EXISTS "idx_B_Ticket_doctor_visit_summary_id"
  ON public."B_Ticket" (doctor_visit_summary_id);
CREATE INDEX IF NOT EXISTS "idx_B_Ticket_linked_appointment_id"
  ON public."B_Ticket" (linked_appointment_id);

-- B_Ticket_Comments — comment author join
CREATE INDEX IF NOT EXISTS "idx_B_Ticket_Comments_created_by"
  ON public."B_Ticket_Comments" (created_by);

-- billing_invoices — invoice list scoping
CREATE INDEX IF NOT EXISTS idx_billing_invoices_billing_plan_id
  ON public.billing_invoices (billing_plan_id);
CREATE INDEX IF NOT EXISTS idx_billing_invoices_payment_account_id
  ON public.billing_invoices (payment_account_id);

-- resident_billing_plan — plan → admission / billing account
CREATE INDEX IF NOT EXISTS idx_resident_billing_plan_admission_id
  ON public.resident_billing_plan (admission_id);
CREATE INDEX IF NOT EXISTS idx_resident_billing_plan_billing_account_id
  ON public.resident_billing_plan (billing_account_id);

-- payroll_snapshots — finalize/unfinalize audit lookup
CREATE INDEX IF NOT EXISTS idx_payroll_snapshots_finalized_by
  ON public.payroll_snapshots (finalized_by);
CREATE INDEX IF NOT EXISTS idx_payroll_snapshots_unfinalized_by
  ON public.payroll_snapshots (unfinalized_by);

-- payroll_snapshot_items — item lock audit
CREATE INDEX IF NOT EXISTS idx_payroll_snapshot_items_locked_by
  ON public.payroll_snapshot_items (locked_by);

-- DD_Record_Clock — duty record approver / calendar joins
CREATE INDEX IF NOT EXISTS "idx_DD_Record_Clock_aproover_id"
  ON public."DD_Record_Clock" (aproover_id);
CREATE INDEX IF NOT EXISTS "idx_DD_Record_Clock_calendar_appointment_id"
  ON public."DD_Record_Clock" (calendar_appointment_id);
CREATE INDEX IF NOT EXISTS "idx_DD_Record_Clock_calendar_bill_id"
  ON public."DD_Record_Clock" (calendar_bill_id);

-- Duty_Transaction_Clock — duty buyer/seller lookup
CREATE INDEX IF NOT EXISTS "idx_Duty_Transaction_Clock_user_1"
  ON public."Duty_Transaction_Clock" (user_1);
CREATE INDEX IF NOT EXISTS "idx_Duty_Transaction_Clock_user_2"
  ON public."Duty_Transaction_Clock" (user_2);
