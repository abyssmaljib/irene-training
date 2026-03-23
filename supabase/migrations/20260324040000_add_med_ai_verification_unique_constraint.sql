-- เพิ่ม unique constraint บน (med_log_id, photo_type) สำหรับ A_Med_AI_Verification
-- จำเป็นสำหรับ verify-med-photo-batch edge function ที่ใช้ upsert onConflict
-- แทน pattern เดิมที่ delete → insert (ซึ่งมี race condition)
--
-- ลบ duplicate rows ก่อน (เก็บ row ล่าสุด) เพื่อป้องกัน constraint fail
DELETE FROM "A_Med_AI_Verification" a
USING "A_Med_AI_Verification" b
WHERE a.med_log_id = b.med_log_id
  AND a.photo_type = b.photo_type
  AND a.id < b.id;

-- สร้าง unique constraint
ALTER TABLE "A_Med_AI_Verification"
  ADD CONSTRAINT uq_med_ai_verify_log_type UNIQUE (med_log_id, photo_type);
