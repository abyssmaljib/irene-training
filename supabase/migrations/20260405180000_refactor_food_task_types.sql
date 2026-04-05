-- ============================================================
-- Refactor taskType "อาหาร" → แยกเป็นหลายประเภท
-- เสิร์ฟอาหาร = ถ่ายรูปตอนเสิร์ฟ (ไม่มี assessment)
-- ทานอาหารเสร็จ = ถ่ายรูปหลังทาน + assessment ทานได้กี่ %
-- Feed = ให้อาหารทางสายยาง
-- อาหารว่าง = ขนม ผลไม้ นม โปรตีน
-- ============================================================

-- === 1. เสิร์ฟอาหาร: task ที่ชื่อ "รับประทานอาหาร..." (มื้อหลัก) ===
UPDATE "A_Tasks" SET "taskType" = 'เสิร์ฟอาหาร'
WHERE "taskType" = 'อาหาร'
  AND (
    title LIKE '%รับประทานอาหารเช้า%'
    OR title LIKE '%รับประทานอาหารกลางวัน%'
    OR title LIKE '%รับประทานอาหารเย็น%'
    OR title LIKE '%ทานอาหาร%มื้อเช้า%'
    OR title LIKE '%ทานอาหาร%มื้อกลางวัน%'
    OR title LIKE '%ทานอาหาร%มื้อเย็น%'
    OR title LIKE '%อาหารกลางวัน%'
    OR title LIKE '%อาหารเช้า%'
    OR title LIKE '%อาหารเย็น%'
    OR title LIKE '%เสิร์ฟ%'
    OR title LIKE '%เสริฟ%'
  )
  -- ยกเว้น "หลังรับประทาน" ที่เป็นอีกประเภท
  AND title NOT LIKE '%หลัง%';

-- === 2. ทานอาหารเสร็จ: task ที่ชื่อ "หลังรับประทาน..." ===
UPDATE "A_Tasks" SET "taskType" = 'ทานอาหารเสร็จ'
WHERE "taskType" = 'อาหาร'
  AND (
    title LIKE '%หลังรับประทาน%'
    OR title LIKE '%หลังทาน%'
  );

-- === 3. Feed: task ที่ชื่อมี Feed / สายยาง ===
UPDATE "A_Tasks" SET "taskType" = 'Feed'
WHERE "taskType" = 'อาหาร'
  AND (
    title ILIKE '%feed%'
    OR title LIKE '%สายยาง%'
    OR title LIKE '%อาหารปั่น%'
    OR title LIKE '%Blendera%'
    OR title ILIKE '%blendera%'
    OR title LIKE '%อาหารทางการแพทย์%'
    OR title LIKE '%Gen DM%'
    OR title ILIKE '%gen dm%'
    OR title LIKE '%N-sure%'
    OR title LIKE '%แพน-เอ็นเทอราล%'
  );

-- === 4. อาหารว่าง: นม โปรตีน ขนม ผลไม้ ของว่าง ===
UPDATE "A_Tasks" SET "taskType" = 'อาหารว่าง'
WHERE "taskType" = 'อาหาร'
  AND (
    title LIKE '%นม%'
    OR title LIKE '%โปรตีน%'
    OR title LIKE '%Ensure%'
    OR title LIKE '%ขนม%'
    OR title LIKE '%ของว่าง%'
    OR title LIKE '%ผลไม้%'
    OR title LIKE '%Meiji%'
    OR title LIKE '%ข้าวโอ๊ต%'
    OR title LIKE '%หมูปิ้ง%'
    OR title LIKE '%ไส้อั่ว%'
    OR title LIKE '%สปอนเซอร์%'
    OR title LIKE '%ดีน่า%'
  );

-- === 5. ที่เหลือ (ถ้ายังมี taskType = 'อาหาร') → เก็บเป็น 'อาหารว่าง' ===
-- เพราะ tasks ที่เหลือมักเป็นของกินเล็กๆ น้อยๆ
UPDATE "A_Tasks" SET "taskType" = 'อาหารว่าง'
WHERE "taskType" = 'อาหาร';

-- === 6. แจ้ง feedback อาหาร → อื่นๆ ===
UPDATE "A_Tasks" SET "taskType" = 'อื่นๆ'
WHERE "taskType" = 'อาหารว่าง'
  AND title LIKE '%แจ้งฟีคแบค%';

-- === 7. เพิ่ม assessment mapping: ทานอาหารเสร็จ → Subject #2 (ทานได้กี่ %) ===
INSERT INTO "TaskType_Report_Subject" ("task_type", "subject_id", "nursinghome_id") VALUES
  ('ทานอาหารเสร็จ', 2, 1)
ON CONFLICT DO NOTHING;

-- ลบ mapping เดิมของ 'อาหาร' (ถูก refactor แล้ว)
DELETE FROM "TaskType_Report_Subject" WHERE "task_type" = 'อาหาร';

-- ============================================================
-- สรุป taskType ใหม่สำหรับอาหาร:
--
-- เสิร์ฟอาหาร        — ถ่ายรูปจานอาหารตอนเสิร์ฟ (ไม่มี assessment)
-- ทานอาหารเสร็จ      — ถ่ายรูปจานหลังทาน + assessment #2 (ทานได้กี่ %)
-- Feed              — อาหารปั่น/สายยาง/อาหารทางการแพทย์
-- อาหารว่าง          — นม โปรตีน ขนม ผลไม้
-- ============================================================
