-- =====================================================
-- Performance: Consolidate multiple permissive RLS policies
-- =====================================================
-- ที่มา: Supabase advisor `multiple_permissive_policies`
-- ปัญหา: 11 (table, role, cmd) groups มี 2 policies ที่ overlap กัน
--   → Postgres ต้อง evaluate ทั้ง 2 policies ทุก row → overhead
-- แก้: รวม 2 policies เป็น 1 policy ด้วย OR (logic เดียวกัน, evaluate ครั้งเดียว)
--
-- ทุก pair ตรวจ semantics แล้วว่า:
--   - permissive policies = OR'd อยู่แล้ว → รวมเป็น OR ใน policy เดียว ผลลัพธ์เหมือนเดิม
--   - กรณีที่ qual / with_check ต่างกัน → OR แต่ละช่องแยก
--
-- ตรวจแล้ว: app code ของ Flutter + Next.js ไม่มี reference ถึง policy names เหล่านี้
--
-- Idempotent: ใช้ DROP IF EXISTS ก่อน CREATE — run ซ้ำได้

-- =====================================================
-- 1. notifications INSERT
-- =====================================================
-- รวม: active_employee_insert_own_notifications + supervisor_insert_notifications_same_nursinghome
DROP POLICY IF EXISTS active_employee_insert_own_notifications ON public.notifications;
DROP POLICY IF EXISTS supervisor_insert_notifications_same_nursinghome ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_combined ON public.notifications;
CREATE POLICY notifications_insert_combined ON public.notifications
  FOR INSERT TO public
  WITH CHECK (
    -- active employee insert own notification
    (is_active_employee() AND (user_id = (SELECT auth.uid())))
    OR
    -- supervisor (level >= 30) insert for same nursinghome
    (
      EXISTS (
        SELECT 1
        FROM user_info ui
        JOIN user_system_roles usr ON usr.id = ui.role_id
        WHERE ui.id = (SELECT auth.uid())
          AND usr.level >= 30
          AND ui.nursinghome_id IS NOT NULL
          AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
      )
      AND user_id IN (
        SELECT u2.id
        FROM user_info u2
        WHERE u2.nursinghome_id = (
          SELECT ui.nursinghome_id FROM user_info ui WHERE ui.id = (SELECT auth.uid())
        )
        AND ((u2.employment_type IS NULL) OR (u2.employment_type <> 'resigned'::text))
      )
    )
  );

-- =====================================================
-- 2. profiles SELECT
-- =====================================================
-- รวม: allow_read_own_profile + read_same_nh_subquery
DROP POLICY IF EXISTS allow_read_own_profile ON public.profiles;
DROP POLICY IF EXISTS read_same_nh_subquery ON public.profiles;
DROP POLICY IF EXISTS profiles_select_combined ON public.profiles;
CREATE POLICY profiles_select_combined ON public.profiles
  FOR SELECT TO public
  USING (
    -- own profile
    (id = (SELECT auth.uid()))
    OR
    -- same nursinghome (active employee)
    EXISTS (
      SELECT 1 FROM user_info ui
      WHERE ui.id = profiles.id
        AND ui.nursinghome_id IN (
          SELECT ui2.nursinghome_id FROM user_info ui2
          WHERE ui2.id = (SELECT auth.uid())
            AND ui2.nursinghome_id IS NOT NULL
            AND ((ui2.employment_type IS NULL) OR (ui2.employment_type <> 'resigned'::text))
        )
    )
  );

-- =====================================================
-- 3. training_topics SELECT
-- =====================================================
-- รวม: active_read_subquery + read_topics
DROP POLICY IF EXISTS active_read_subquery ON public.training_topics;
DROP POLICY IF EXISTS read_topics ON public.training_topics;
DROP POLICY IF EXISTS training_topics_select_combined ON public.training_topics;
CREATE POLICY training_topics_select_combined ON public.training_topics
  FOR SELECT TO public
  USING (
    -- active topic ทุกคนอ่านได้
    (is_active = true)
    OR
    -- active employee อ่านได้ทั้งหมด (รวม inactive)
    EXISTS (
      SELECT 1 FROM user_info ui
      WHERE ui.id = (SELECT auth.uid())
        AND ui.nursinghome_id IS NOT NULL
        AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
    )
  );

-- =====================================================
-- 4. user_info SELECT
-- =====================================================
-- รวม: allow_read_own_user_info + read_same_nursinghome
DROP POLICY IF EXISTS allow_read_own_user_info ON public.user_info;
DROP POLICY IF EXISTS read_same_nursinghome ON public.user_info;
DROP POLICY IF EXISTS user_info_select_combined ON public.user_info;
CREATE POLICY user_info_select_combined ON public.user_info
  FOR SELECT TO public
  USING (
    -- own row (รวม case ที่ user ยังไม่ assigned nursinghome หรือ resigned)
    (id = (SELECT auth.uid()))
    OR
    -- same nursinghome (admin เห็นรวม resigned, คนอื่นเห็นเฉพาะ active)
    (
      ((SELECT auth.uid()) IS NOT NULL)
      AND (nursinghome_id IS NOT NULL)
      AND (nursinghome_id = get_current_user_nursinghome_id())
      AND (is_current_user_admin() OR ((employment_type IS NULL) OR (employment_type <> 'resigned'::text)))
    )
  );

-- =====================================================
-- 5. user_info UPDATE
-- =====================================================
-- รวม: manager_update_same_nursinghome + update_own_profile
-- USING + WITH CHECK clauses ต่างกัน → OR แต่ละช่อง
DROP POLICY IF EXISTS manager_update_same_nursinghome ON public.user_info;
DROP POLICY IF EXISTS update_own_profile ON public.user_info;
DROP POLICY IF EXISTS user_info_update_combined ON public.user_info;
CREATE POLICY user_info_update_combined ON public.user_info
  FOR UPDATE TO public
  USING (
    -- manager update คนอื่นใน nursinghome เดียวกัน
    (
      ((SELECT auth.uid()) IS NOT NULL)
      AND (nursinghome_id IS NOT NULL)
      AND (nursinghome_id = get_current_user_nursinghome_id())
      AND is_current_user_manager()
    )
    OR
    -- update own profile (active employee เท่านั้น)
    (
      (id = (SELECT auth.uid()))
      AND (nursinghome_id IS NOT NULL)
      AND ((employment_type IS NULL) OR (employment_type <> 'resigned'::text))
    )
  )
  WITH CHECK (
    -- manager check: nursinghome เดียวกัน + role level <= ตัวเอง
    (
      (nursinghome_id = get_current_user_nursinghome_id())
      AND ((role_id IS NULL) OR (get_role_level((role_id)::bigint) <= get_current_user_role_level()))
    )
    OR
    -- own profile check: ห้ามเปลี่ยน role + ห้ามเปลี่ยน nursinghome
    (
      (id = (SELECT auth.uid()))
      AND (NOT (role_id IS DISTINCT FROM get_current_user_role_id()))
      AND (NOT (nursinghome_id IS DISTINCT FROM get_current_user_nursinghome_id()))
    )
  );

-- =====================================================
-- 6. user_system_roles ALL (hq_manage)
-- =====================================================
-- รวม: hq_manage_roles + hq_manage_subquery (logic เดียวกัน — HQ employee = nh_id 1)
DROP POLICY IF EXISTS hq_manage_roles ON public.user_system_roles;
DROP POLICY IF EXISTS hq_manage_subquery ON public.user_system_roles;
DROP POLICY IF EXISTS user_system_roles_hq_manage_combined ON public.user_system_roles;
CREATE POLICY user_system_roles_hq_manage_combined ON public.user_system_roles
  FOR ALL TO public
  USING (
    -- HQ employee สามารถจัดการได้
    (is_active_employee() AND (get_user_nursinghome_id() = 1))
    OR
    -- เก่า: หา nh_id 1 ใน user's nh (ใช้ logic เดียวกัน — keep for safety)
    (1 IN (
      SELECT ui.nursinghome_id FROM user_info ui
      WHERE ui.id = (SELECT auth.uid())
        AND ui.nursinghome_id IS NOT NULL
        AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
    ))
  );

-- =====================================================
-- 7. user_system_roles SELECT (active_*)
-- =====================================================
-- รวม: active_employee_read_roles + active_read_subquery (เนื้อหาเหมือน — เก็บเวอร์ชัน helper)
DROP POLICY IF EXISTS active_employee_read_roles ON public.user_system_roles;
DROP POLICY IF EXISTS active_read_subquery ON public.user_system_roles;
DROP POLICY IF EXISTS user_system_roles_select_combined ON public.user_system_roles;
CREATE POLICY user_system_roles_select_combined ON public.user_system_roles
  FOR SELECT TO public
  USING (
    is_active_employee()
    OR
    EXISTS (
      SELECT 1 FROM user_info ui
      WHERE ui.id = (SELECT auth.uid())
        AND ui.nursinghome_id IS NOT NULL
        AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
    )
  );

-- =====================================================
-- 8. user_task_seen DELETE
-- =====================================================
-- รวม: active_delete_own_subquery + delete_own_records
DROP POLICY IF EXISTS active_delete_own_subquery ON public.user_task_seen;
DROP POLICY IF EXISTS delete_own_records ON public.user_task_seen;
DROP POLICY IF EXISTS user_task_seen_delete_combined ON public.user_task_seen;
CREATE POLICY user_task_seen_delete_combined ON public.user_task_seen
  FOR DELETE TO public
  USING (
    -- active employee delete own
    (
      (user_id = ((SELECT auth.uid()))::text)
      AND EXISTS (
        SELECT 1 FROM user_info ui
        WHERE ui.id = (SELECT auth.uid())
          AND ui.nursinghome_id IS NOT NULL
          AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
      )
    )
    OR
    -- any authenticated user delete own (รวม resigned)
    (
      ((SELECT auth.uid()) IS NOT NULL)
      AND (user_id = ((SELECT auth.uid()))::text)
    )
  );

-- =====================================================
-- 9. user_task_seen INSERT
-- =====================================================
DROP POLICY IF EXISTS active_insert_own_subquery ON public.user_task_seen;
DROP POLICY IF EXISTS insert_own_records ON public.user_task_seen;
DROP POLICY IF EXISTS user_task_seen_insert_combined ON public.user_task_seen;
CREATE POLICY user_task_seen_insert_combined ON public.user_task_seen
  FOR INSERT TO public
  WITH CHECK (
    -- active employee insert own
    (
      (user_id = ((SELECT auth.uid()))::text)
      AND EXISTS (
        SELECT 1 FROM user_info ui
        WHERE ui.id = (SELECT auth.uid())
          AND ui.nursinghome_id IS NOT NULL
          AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
      )
    )
    OR
    (
      ((SELECT auth.uid()) IS NOT NULL)
      AND (user_id = ((SELECT auth.uid()))::text)
    )
  );

-- =====================================================
-- 10. user_task_seen SELECT
-- =====================================================
DROP POLICY IF EXISTS active_read_subquery ON public.user_task_seen;
DROP POLICY IF EXISTS authenticated_read_all ON public.user_task_seen;
DROP POLICY IF EXISTS user_task_seen_select_combined ON public.user_task_seen;
CREATE POLICY user_task_seen_select_combined ON public.user_task_seen
  FOR SELECT TO public
  USING (
    -- any authenticated user สามารถอ่าน (เพื่อให้ teamwork view ได้)
    ((SELECT auth.uid()) IS NOT NULL)
  );
-- หมายเหตุ: นโยบายเดิม authenticated_read_all อนุญาตทุก user ที่ login อ่านได้แล้ว
-- → active_read_subquery ที่จำกัด active employee ถือเป็น subset → drop ทิ้งได้
-- ดังนั้น combined ใช้แค่ check authenticated เดียวพอ

-- =====================================================
-- 11. user_task_seen UPDATE
-- =====================================================
DROP POLICY IF EXISTS active_update_own_subquery ON public.user_task_seen;
DROP POLICY IF EXISTS update_own_records ON public.user_task_seen;
DROP POLICY IF EXISTS user_task_seen_update_combined ON public.user_task_seen;
CREATE POLICY user_task_seen_update_combined ON public.user_task_seen
  FOR UPDATE TO public
  USING (
    -- active employee update own
    (
      (user_id = ((SELECT auth.uid()))::text)
      AND EXISTS (
        SELECT 1 FROM user_info ui
        WHERE ui.id = (SELECT auth.uid())
          AND ui.nursinghome_id IS NOT NULL
          AND ((ui.employment_type IS NULL) OR (ui.employment_type <> 'resigned'::text))
      )
    )
    OR
    (
      ((SELECT auth.uid()) IS NOT NULL)
      AND (user_id = ((SELECT auth.uid()))::text)
    )
  );
