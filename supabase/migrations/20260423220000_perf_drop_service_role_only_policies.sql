-- =====================================================
-- Performance: Drop 11 more redundant service_role-only policies
-- =====================================================
-- ที่มา: Supabase advisor `multiple_permissive_policies`
-- ต่อจาก Migration 3a (ลบ service_role_bypass/only/manage)
--
-- Policies เหล่านี้ซ่อนอยู่เพราะชื่อไม่ตรง pattern ของ 3a:
-- ทุกตัวมี qual=true, permissive, TO {service_role} เท่านั้น
--
-- เหตุผลที่ redundant:
--   - role `service_role` มี `rolbypassrls = true` (verify แล้วใน Migration 3a)
--   - Policy ไม่มีผลใดๆ
--   - แต่ทำให้ advisor รายงานเป็น multi-permissive
--
-- Verified: ไม่มี app code อ้างชื่อ policy เหล่านี้

DROP POLICY IF EXISTS "Allow service role all" ON public."A_Med_AI_Verification";
DROP POLICY IF EXISTS dvs_service_role ON public."B_Doctor_Visit_Summary";
DROP POLICY IF EXISTS "Service role full access on holidays" ON public."PublicHoliday";
DROP POLICY IF EXISTS service_role_all ON public."TaskType_Report_Subject";
DROP POLICY IF EXISTS "Service role full access billing_accounts" ON public.billing_accounts;
DROP POLICY IF EXISTS "Service role full access billing_invoices" ON public.billing_invoices;
DROP POLICY IF EXISTS "Service role full access billing_service_rates" ON public.billing_service_rates;
DROP POLICY IF EXISTS "Allow all for service role" ON public.job_descriptions;
DROP POLICY IF EXISTS "Service role full access on admissions" ON public.resident_admissions;
DROP POLICY IF EXISTS "Service role full access resident_billing_plan" ON public.resident_billing_plan;
DROP POLICY IF EXISTS rm_service_role ON public.resident_measurements;
