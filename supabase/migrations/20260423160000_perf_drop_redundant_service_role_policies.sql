-- =====================================================
-- Performance: Drop redundant service_role RLS policies
-- =====================================================
-- ที่มา: Supabase advisor `multiple_permissive_policies`
-- ปัญหา: หลายตารางมี policy `service_role_bypass` ที่เช็ค `auth.role() = 'service_role'`
--   → ทำให้ Postgres ต้อง evaluate policy นี้ทุก row บน query ทุกตัว
--
-- เหตุผลที่ปลอดภัย:
--   service_role ใน Supabase มี `rolbypassrls = true` (verified ด้วย pg_roles)
--   → service_role bypass RLS ที่ระดับ role attribute อยู่แล้ว
--   → policy `service_role_bypass` ทั้งหมด REDUNDANT (ไม่ทำอะไรเพิ่ม)
--
-- ผลลัพธ์:
--   - service_role queries ยังทำงานเหมือนเดิม (bypass ผ่าน role attribute)
--   - authenticated/anon queries เร็วขึ้น (ลด policy ที่ต้อง evaluate)
--   - cleanup_snooze_log: เหลือ 0 policies → blocks non-service-role access (intended)
--
-- ตรวจแล้ว: ทั้ง irene_training (Flutter) และ irene-training-admin (Next.js)
--   ไม่มี reference ถึง policy names เหล่านี้

DO $$
DECLARE
  r RECORD;
  dropped_count INT := 0;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN ('service_role_bypass', 'service_role_only', 'service_role_manage')
      AND (
        -- เป็น policy ที่ check service_role ตรงๆ เท่านั้น (ไม่มี logic อื่น)
        qual ~ '^\(\(\s*SELECT\s+auth\.role\(\)\s*AS\s+role\)\s*=\s*''service_role''::text\)$'
        OR qual = '(auth.role() = ''service_role''::text)'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    dropped_count := dropped_count + 1;
  END LOOP;

  RAISE NOTICE 'Dropped % redundant service_role policies', dropped_count;
END $$;
