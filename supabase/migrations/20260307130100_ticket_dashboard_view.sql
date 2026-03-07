-- ===========================================
-- Replace v_tickets_with_last_comment with v_tickets_dashboard
-- Adds: category, is_overdue, days_until_follow_up
-- Filters last comment by event_type = 'comment'
-- ===========================================

DROP VIEW IF EXISTS v_tickets_with_last_comment;

CREATE VIEW v_tickets_dashboard AS
SELECT
    t.id,
    t.created_at,
    t."ticket_Title",
    t."ticket_Description",
    t.nursinghome_id,
    t.created_by,
    t.assignee,
    t.source,
    t."follow_Up_Date",
    t.status,
    t.priority,
    t."meeting_Agenda",
    t.template_ticket_id,
    t.med_list_id,
    t.template_task_id,
    t.resident_id,
    t.source_type,
    t.source_id,
    t.category,
    -- is_overdue: true when follow_up_date has passed and ticket is still active
    (t."follow_Up_Date" < CURRENT_DATE AND t.status NOT IN ('resolved', 'cancelled')) AS is_overdue,
    -- days_until_follow_up: negative means overdue, positive means upcoming
    (t."follow_Up_Date" - CURRENT_DATE) AS days_until_follow_up,
    creator.nickname AS created_by_nickname,
    r."i_Name_Surname" AS resident_name,
    z.zone AS zone_name,
    lc.content AS last_comment_content,
    lc.created_at AS last_comment_at,
    lc.commenter_nickname AS last_comment_nickname
FROM "B_Ticket" t
    LEFT JOIN user_info creator ON t.created_by = creator.id
    LEFT JOIN residents r ON t.resident_id = r.id
    LEFT JOIN nursinghome_zone z ON r.s_zone = z.id
    LEFT JOIN LATERAL (
        SELECT
            c.content,
            c.created_at,
            u.nickname AS commenter_nickname
        FROM "B_Ticket_Comments" c
            LEFT JOIN user_info u ON c.created_by = u.id
        WHERE c.ticket_id = t.id
          AND c.event_type = 'comment'  -- filter out system events
        ORDER BY c.created_at DESC
        LIMIT 1
    ) lc ON true;
