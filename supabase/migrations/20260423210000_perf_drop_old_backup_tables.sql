-- =====================================================
-- Cleanup: Drop 8 old empty backup tables
-- =====================================================
-- ที่มา: Supabase advisor `no_primary_key` (8 tables)
-- ตรวจแล้ว:
--   - ทุก table มี n_live_tup = 0 (empty — schema only)
--   - ชื่อมี date suffix 2026-03-04 ถึง 2026-03-28 (1+ เดือน)
--   - ไม่มี reference ใน app code (Flutter / admin / edge functions)
--   - รวม ~7.3 MB ของ disk + bloat ใน schema list
--
-- User confirmed: "เราสำรองไว้มานานมากแล้วล่ะ น่าจะไม่ได้ใช้แล้ว"
--
-- ใช้ DROP TABLE IF EXISTS — idempotent, safe ถ้ารันซ้ำ

DROP TABLE IF EXISTS public._backup_b_ticket_med_20260304;
DROP TABLE IF EXISTS public._backup_clock_duplicates_20260327;
DROP TABLE IF EXISTS public._backup_med_history;
DROP TABLE IF EXISTS public._backup_med_history_20260304;
DROP TABLE IF EXISTS public._backup_medicine_list;
DROP TABLE IF EXISTS public._backup_medicine_list_20260304;
DROP TABLE IF EXISTS public._backup_medicine_tag_20260304;
DROP TABLE IF EXISTS public._backup_post_dd_duplicate_20260328;
