-- =============================================================================
-- Migration: เปลี่ยน notifications.reference_id จาก bigint เป็น text
-- =============================================================================
-- เหตุผล: cron shift badge ต้อง INSERT reference_id เป็น UUID (training_user_badges.id)
-- แต่ column เดิมเป็น bigint → INSERT fail
-- เปลี่ยนเป็น text เพื่อรองรับทั้ง integer IDs และ UUID IDs
-- ข้อมูลเดิมที่เป็น bigint (เช่น 36172) จะถูก cast เป็น text ("36172")
-- =============================================================================

ALTER TABLE notifications
  ALTER COLUMN reference_id TYPE text
  USING reference_id::text;

-- เพิ่ม comment อธิบาย
COMMENT ON COLUMN notifications.reference_id IS
  'Reference ID (text) — รองรับทั้ง integer IDs (post, task) และ UUID (badge)';
