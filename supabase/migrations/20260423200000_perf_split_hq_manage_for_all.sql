-- =====================================================
-- Performance: Split FOR ALL `hq_manage_subquery` into INSERT/UPDATE/DELETE
-- =====================================================
-- ที่มา: Supabase advisor `multiple_permissive_policies`
-- ปัญหา: ตาราง global lookup มี 2 permissive policies overlapping บน SELECT:
--   - hq_manage_subquery (FOR ALL)
--   - active_read_subquery / similar (FOR SELECT)
--   → ทุก SELECT ต้อง evaluate ทั้ง 2 ตัว
-- แก้: split FOR ALL → FOR INSERT, FOR UPDATE, FOR DELETE (เอา SELECT ออก)
--   → SELECT ใช้แค่ active_read_subquery → ลด overhead
--
-- ปลอดภัยเพราะ:
--   HQ user เป็น active employee อยู่แล้ว (ui.nursinghome_id = 1, not resigned)
--   → HQ user ผ่าน active_read_subquery สำหรับ SELECT ได้
--   → ไม่ต้องพึ่ง hq_manage_subquery เพื่อ SELECT
--
-- ตารางที่ split (20 tables — global lookup data):
--   Calendar_Subject, QATable, Relation_TagTopic_UserGroup, Report_Choice,
--   Report_Subject, TagsLabel, Task_Type, med_DB, med_atc_level1, med_atc_level2,
--   med_history, new_tags, pastel_color, programs, training_content,
--   training_questions, training_quiz_answers, training_topics, underlying_disease,
--   period_reward_templates
--
-- ❌ ไม่ split (per-nursinghome data ที่ HQ ต้องการ cross-nh visibility):
--   clock_break_time_nursinghome, user_group, user_with_user_group,
--   leaderboard_periods, leaderboard_snapshots

DO $$
DECLARE
  r RECORD;
  split_count INT := 0;
  target_tables TEXT[] := ARRAY[
    'Calendar_Subject', 'QATable', 'Relation_TagTopic_UserGroup', 'Report_Choice',
    'Report_Subject', 'TagsLabel', 'Task_Type', 'med_DB', 'med_atc_level1', 'med_atc_level2',
    'med_history', 'new_tags', 'pastel_color', 'programs', 'training_content',
    'training_questions', 'training_quiz_answers', 'training_topics', 'underlying_disease',
    'period_reward_templates'
  ];
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname = 'hq_manage_subquery'
      AND cmd = 'ALL'
      AND tablename = ANY(target_tables)
  LOOP
    -- Drop original FOR ALL
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);

    -- Create FOR INSERT (ใช้ with_check ถ้ามี ถ้าไม่มีใช้ qual เป็น check)
    EXECUTE format(
      'CREATE POLICY hq_manage_insert ON %I.%I FOR INSERT TO public WITH CHECK (%s)',
      r.schemaname, r.tablename,
      COALESCE(r.with_check, r.qual)
    );

    -- Create FOR UPDATE (ใช้ qual เป็น USING; with_check ถ้ามี ถ้าไม่มีใช้ qual)
    EXECUTE format(
      'CREATE POLICY hq_manage_update ON %I.%I FOR UPDATE TO public USING (%s) WITH CHECK (%s)',
      r.schemaname, r.tablename,
      r.qual,
      COALESCE(r.with_check, r.qual)
    );

    -- Create FOR DELETE (ใช้ qual เป็น USING)
    EXECUTE format(
      'CREATE POLICY hq_manage_delete ON %I.%I FOR DELETE TO public USING (%s)',
      r.schemaname, r.tablename,
      r.qual
    );

    split_count := split_count + 1;
  END LOOP;

  RAISE NOTICE 'Split % FOR ALL policies into INSERT/UPDATE/DELETE', split_count;
END $$;
