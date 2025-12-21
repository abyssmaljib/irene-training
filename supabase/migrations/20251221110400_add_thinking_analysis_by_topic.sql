-- Add a view for thinking analysis filtered by topic
-- This allows showing skill radar chart per topic in the quiz tab

CREATE OR REPLACE VIEW "public"."training_v_thinking_analysis_by_topic" WITH ("security_invoker"='on') AS
SELECT
    qs.user_id,
    qs.season_id,
    qs.topic_id,
    q.thinking_type,
    count(*) AS total_questions,
    sum(
        CASE
            WHEN qa.is_correct THEN 1
            ELSE 0
        END
    ) AS correct_count,
    round(
        (100.0 * sum(
            CASE
                WHEN qa.is_correct THEN 1
                ELSE 0
            END
        )::numeric) / NULLIF(count(*), 0)::numeric,
        1
    ) AS percent_correct
FROM training_quiz_answers qa
    JOIN training_questions q ON qa.question_id = q.id
    JOIN training_quiz_sessions qs ON qa.session_id = qs.id
WHERE
    q.thinking_type IS NOT NULL
    AND qs.completed_at IS NOT NULL
GROUP BY
    qs.user_id,
    qs.season_id,
    qs.topic_id,
    q.thinking_type
ORDER BY
    qs.user_id,
    qs.topic_id,
    q.thinking_type;

COMMENT ON VIEW "public"."training_v_thinking_analysis_by_topic" IS 'วิเคราะห์ประเภทการคิดแยกตาม topic สำหรับ Pentagon chart ในแต่ละหัวข้อ';

-- Grant permissions
GRANT ALL ON TABLE "public"."training_v_thinking_analysis_by_topic" TO "anon";
GRANT ALL ON TABLE "public"."training_v_thinking_analysis_by_topic" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_thinking_analysis_by_topic" TO "service_role";
