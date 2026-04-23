-- =====================================================
-- Performance: Wrap auth.uid() / auth.role() / auth.jwt() in (SELECT ...)
-- =====================================================
-- ที่มา: Supabase advisor `auth_rls_initplan` (231 policies)
-- ปัญหา: เรียก auth.uid()/auth.role()/auth.jwt() ตรงๆ ใน RLS policy
--   → Postgres ประเมิน func ใหม่ทุก row (init plan)
-- แก้: wrap ใน (SELECT ...) เพื่อให้ Postgres cache ค่าครั้งเดียวต่อ query
--   → query ที่ดึงเยอะ (residents, tasks, medicine logs) เร็วขึ้น 10-100x
--
-- รูปแบบการแก้:
--   auth.uid()  → (SELECT auth.uid())
--   auth.role() → (SELECT auth.role())
--   auth.jwt()  → (SELECT auth.jwt())
--
-- Logic เดิมไม่เปลี่ยน — แค่ wrapper ของ function call
-- → security ไม่กระทบ, Flutter app ไม่กระทบ (อ่าน/เขียนได้เหมือนเดิม แต่เร็วขึ้น)
--
-- Safety:
--   - ใช้ ALTER POLICY (Postgres 15+) → ไม่ต้อง drop/recreate
--   - DO block จะ skip policy ที่ wrap แล้ว (idempotent)
--   - ทำใน transaction เดียว — ถ้า fail ตัวใด rollback ทั้งหมด

DO $$
DECLARE
  r RECORD;
  new_qual TEXT;
  new_check TEXT;
  fixed_count INT := 0;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        (qual ~ 'auth\.(uid|role|jwt)\(\)' AND qual !~ '\(\s*[Ss][Ee][Ll][Ee][Cc][Tt]\s+auth\.(uid|role|jwt)\(\)')
        OR (with_check ~ 'auth\.(uid|role|jwt)\(\)' AND with_check !~ '\(\s*[Ss][Ee][Ll][Ee][Cc][Tt]\s+auth\.(uid|role|jwt)\(\)')
      )
  LOOP
    new_qual := r.qual;
    new_check := r.with_check;

    -- ============================================
    -- Wrap auth.uid() — ใช้ token-protect ป้องกัน double-wrap
    -- ============================================
    IF new_qual IS NOT NULL THEN
      -- Step 1: ป้องกันรูปแบบที่ wrap แล้ว (case variants ของ SELECT)
      new_qual := replace(new_qual, '(SELECT auth.uid() AS uid)', '__WRAPPED_UID__');
      new_qual := replace(new_qual, '( SELECT auth.uid() AS uid)', '__WRAPPED_UID__');
      new_qual := replace(new_qual, '(SELECT auth.uid())', '__WRAPPED_UID__');
      new_qual := replace(new_qual, '( SELECT auth.uid())', '__WRAPPED_UID__');
      -- Step 2: wrap ตัว bare
      new_qual := replace(new_qual, 'auth.uid()', '(SELECT auth.uid())');
      -- Step 3: restore wrapped tokens
      new_qual := replace(new_qual, '__WRAPPED_UID__', '(SELECT auth.uid())');

      -- Same pattern for auth.role()
      new_qual := replace(new_qual, '(SELECT auth.role() AS role)', '__WRAPPED_ROLE__');
      new_qual := replace(new_qual, '( SELECT auth.role() AS role)', '__WRAPPED_ROLE__');
      new_qual := replace(new_qual, '(SELECT auth.role())', '__WRAPPED_ROLE__');
      new_qual := replace(new_qual, '( SELECT auth.role())', '__WRAPPED_ROLE__');
      new_qual := replace(new_qual, 'auth.role()', '(SELECT auth.role())');
      new_qual := replace(new_qual, '__WRAPPED_ROLE__', '(SELECT auth.role())');

      -- Same for auth.jwt()
      new_qual := replace(new_qual, '(SELECT auth.jwt() AS jwt)', '__WRAPPED_JWT__');
      new_qual := replace(new_qual, '( SELECT auth.jwt() AS jwt)', '__WRAPPED_JWT__');
      new_qual := replace(new_qual, '(SELECT auth.jwt())', '__WRAPPED_JWT__');
      new_qual := replace(new_qual, '( SELECT auth.jwt())', '__WRAPPED_JWT__');
      new_qual := replace(new_qual, 'auth.jwt()', '(SELECT auth.jwt())');
      new_qual := replace(new_qual, '__WRAPPED_JWT__', '(SELECT auth.jwt())');
    END IF;

    -- ============================================
    -- Same logic for with_check
    -- ============================================
    IF new_check IS NOT NULL THEN
      new_check := replace(new_check, '(SELECT auth.uid() AS uid)', '__WRAPPED_UID__');
      new_check := replace(new_check, '( SELECT auth.uid() AS uid)', '__WRAPPED_UID__');
      new_check := replace(new_check, '(SELECT auth.uid())', '__WRAPPED_UID__');
      new_check := replace(new_check, '( SELECT auth.uid())', '__WRAPPED_UID__');
      new_check := replace(new_check, 'auth.uid()', '(SELECT auth.uid())');
      new_check := replace(new_check, '__WRAPPED_UID__', '(SELECT auth.uid())');

      new_check := replace(new_check, '(SELECT auth.role() AS role)', '__WRAPPED_ROLE__');
      new_check := replace(new_check, '( SELECT auth.role() AS role)', '__WRAPPED_ROLE__');
      new_check := replace(new_check, '(SELECT auth.role())', '__WRAPPED_ROLE__');
      new_check := replace(new_check, '( SELECT auth.role())', '__WRAPPED_ROLE__');
      new_check := replace(new_check, 'auth.role()', '(SELECT auth.role())');
      new_check := replace(new_check, '__WRAPPED_ROLE__', '(SELECT auth.role())');

      new_check := replace(new_check, '(SELECT auth.jwt() AS jwt)', '__WRAPPED_JWT__');
      new_check := replace(new_check, '( SELECT auth.jwt() AS jwt)', '__WRAPPED_JWT__');
      new_check := replace(new_check, '(SELECT auth.jwt())', '__WRAPPED_JWT__');
      new_check := replace(new_check, '( SELECT auth.jwt())', '__WRAPPED_JWT__');
      new_check := replace(new_check, 'auth.jwt()', '(SELECT auth.jwt())');
      new_check := replace(new_check, '__WRAPPED_JWT__', '(SELECT auth.jwt())');
    END IF;

    -- ============================================
    -- ALTER POLICY ตามชนิดของ clause ที่มี
    -- ============================================
    IF r.qual IS NOT NULL AND r.with_check IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s) WITH CHECK (%s)',
        r.policyname, r.schemaname, r.tablename, new_qual, new_check
      );
    ELSIF r.qual IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s)',
        r.policyname, r.schemaname, r.tablename, new_qual
      );
    ELSIF r.with_check IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I WITH CHECK (%s)',
        r.policyname, r.schemaname, r.tablename, new_check
      );
    END IF;

    fixed_count := fixed_count + 1;
  END LOOP;

  RAISE NOTICE 'auth_rls_initplan: fixed % policies', fixed_count;
END $$;
