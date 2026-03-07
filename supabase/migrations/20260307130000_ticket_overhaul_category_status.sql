-- ===========================================
-- Ticket Overhaul: category, status, timeline
-- ===========================================

-- 1. Add category column to B_Ticket
ALTER TABLE "B_Ticket" ADD COLUMN IF NOT EXISTS category text DEFAULT 'general';

-- 2. Add timeline fields to B_Ticket_Comments
ALTER TABLE "B_Ticket_Comments" ADD COLUMN IF NOT EXISTS event_type text DEFAULT 'comment';
ALTER TABLE "B_Ticket_Comments" ADD COLUMN IF NOT EXISTS old_status text;
ALTER TABLE "B_Ticket_Comments" ADD COLUMN IF NOT EXISTS new_status text;

-- 3. Migrate existing tickets: set category based on existing data
UPDATE "B_Ticket" SET category = 'medicine' WHERE med_list_id IS NOT NULL;
UPDATE "B_Ticket" SET category = 'task' WHERE source_type = 'task_log' AND category = 'general';

-- 4. Migrate status: completed/closed -> resolved
UPDATE "B_Ticket" SET status = 'resolved' WHERE status IN ('completed', 'closed');

-- 5. Migrate existing comments in B_Ticket_Comments: mark legacy as 'comment'
UPDATE "B_Ticket_Comments" SET event_type = 'comment' WHERE event_type IS NULL;
