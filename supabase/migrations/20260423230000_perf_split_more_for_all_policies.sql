-- =====================================================
-- Performance: Split 11 more FOR ALL policies into INSERT/UPDATE/DELETE
-- =====================================================
-- ที่มา: Supabase advisor `multiple_permissive_policies`
-- ต่อจาก Migration 5 (split hq_manage_subquery 20 ตาราง)
--
-- ปัญหา: ตารางเหล่านี้มี FOR ALL policy + FOR SELECT policy → SELECT overlap
-- แก้: split FOR ALL → INSERT, UPDATE, DELETE → SELECT ใช้แค่ SELECT policy
--
-- Verified ทุกตารางว่า FOR ALL user ผ่าน SELECT policy ได้ (no access loss):
--   - B_AI_Config, B_Core_Value_Global: SELECT qual = true (ทุกคน)
--   - B_Incident_Category, B_Nursinghome_Location: ใช้ same_nh เหมือนกัน
--   - B_Nursinghome_WiFi: SELECT qual = true (any authenticated)
--   - TaskType_Report_Subject, blended_food_recipes: manage user เป็น active employee → ผ่าน active_read
--   - invitations: incharge_or_above เป็น user ใน same_nh → ผ่าน read_same_nh
--   - payroll_transfer_settings, staff_salary_history: manager ใน same_nh → ผ่าน read_same_nh
--   - permission_configs: HQ full-access user เป็น active employee → ผ่าน active_read_subquery

DO $$
DECLARE
  r RECORD;
  split_count INT := 0;
  base_name TEXT;
  role_clause TEXT;
  insert_policy TEXT;
  update_policy TEXT;
  delete_policy TEXT;
BEGIN
  FOR r IN
    SELECT
      p.schemaname, p.tablename, p.policyname, p.qual, p.with_check, p.roles
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.cmd = 'ALL'
      AND (p.tablename, p.policyname) IN (
        ('B_AI_Config', 'HQ users can manage AI config'),
        ('B_Core_Value_Global', 'HQ users can manage global core values'),
        ('B_Incident_Category', 'Managers can manage categories'),
        ('B_Nursinghome_Location', 'Users can manage their nursinghome location'),
        ('B_Nursinghome_WiFi', 'nursinghome_write'),
        ('TaskType_Report_Subject', 'hq_manage'),
        ('blended_food_recipes', 'shift_leader_manage'),
        ('invitations', 'incharge_write_same_nursinghome_invitations'),
        ('payroll_transfer_settings', 'payroll_transfer_settings_manage_by_manager'),
        ('staff_salary_history', 'salary_history_manage_by_manager'),
        ('permission_configs', 'hq_full_access_write_permission_configs')
      )
  LOOP
    -- Build TO role clause (preserve original)
    role_clause := array_to_string(r.roles, ',');

    -- Build new policy names (suffix _ins / _upd / _del)
    base_name := r.policyname || ' _split';
    insert_policy := r.policyname || '_ins';
    update_policy := r.policyname || '_upd';
    delete_policy := r.policyname || '_del';

    -- Drop original FOR ALL
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);

    -- INSERT: ใช้ with_check ถ้ามี ถ้าไม่มีใช้ qual
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR INSERT TO %s WITH CHECK (%s)',
      insert_policy, r.schemaname, r.tablename, role_clause,
      COALESCE(r.with_check, r.qual)
    );

    -- UPDATE: USING + WITH CHECK
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR UPDATE TO %s USING (%s) WITH CHECK (%s)',
      update_policy, r.schemaname, r.tablename, role_clause,
      r.qual,
      COALESCE(r.with_check, r.qual)
    );

    -- DELETE: USING
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR DELETE TO %s USING (%s)',
      delete_policy, r.schemaname, r.tablename, role_clause,
      r.qual
    );

    split_count := split_count + 1;
  END LOOP;

  RAISE NOTICE 'Split % more FOR ALL policies', split_count;
END $$;
