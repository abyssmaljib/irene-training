-- =============================================================================
-- Migration: ตั้ง pg_cron schedule สำหรับ Shift Badge Cron
-- =============================================================================
-- เวรเช้า: 07:00-19:00 ICT → จบ 19:00 ICT = 12:00 UTC
-- เวรดึก: 19:00-07:00 ICT → จบ 07:00 ICT = 00:00 UTC
--
-- Cron รันตอน: 14:00 UTC (21:00 ICT) + 02:00 UTC (09:00 ICT)
-- = 2 ชม. หลังเวรจบ → ให้เวลา staff ทุกคน clock out ก่อน
--
-- Function มี advisory lock ป้องกัน concurrent runs
-- + batch limit 20 cohorts ป้องกัน timeout
-- =============================================================================

-- ลบ schedule เก่า (ถ้ามี) เพื่อ idempotent migration
SELECT cron.unschedule('award-shift-badges')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'award-shift-badges'
);

-- ตั้ง schedule: 02:00 UTC (09:00 ICT) + 14:00 UTC (21:00 ICT)
SELECT cron.schedule(
  'award-shift-badges',
  '0 2,14 * * *',
  'SELECT public.award_shift_badges_for_completed_shifts()'
);
