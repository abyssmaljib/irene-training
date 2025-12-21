

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_role" AS ENUM (
    'superAdmin',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_abnormal_value_to_dashboard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    abnormal_status text;
    resident_nursinghome_id bigint;
BEGIN
    -- Query the vital_signs_status from the combined_vitalsign_details_view
    -- and nursinghome_id from the residents table
    SELECT 
        cvdv.vital_signs_status,
        r.nursinghome_id
    INTO 
        abnormal_status,
        resident_nursinghome_id
    FROM 
        public.combined_vitalsign_details_view cvdv
    JOIN 
        public.residents r ON cvdv.resident_id = r.id
    WHERE 
        cvdv.id = NEW.id;
    
    -- Insert into the abnormal_value_Dashboard if an abnormal value is found
    IF abnormal_status IS NOT NULL AND abnormal_status <> 'สัญญาณชีพล่าสุดปกติ' THEN
        INSERT INTO public."abnormal_value_Dashboard" (resident_id, abnormal_value, nursinghome_id)
        VALUES (NEW.resident_id, abnormal_status, resident_nursinghome_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_abnormal_value_to_dashboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_resident_report_relations"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  INSERT INTO public."Resident_Report_Relation" (resident_id, subject_id, shift)
  SELECT NEW.id, s.subject_id, s.shift
  FROM (VALUES
    (1, 'เวรดึก'),
    (2, 'เวรเช้า'),
    (3, 'เวรเช้า'),
    (4, 'เวรเช้า')
  ) AS s(subject_id, shift)
  ON CONFLICT (resident_id, subject_id, shift) DO NOTHING;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_resident_report_relations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_resident_template_gen_report_entry"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  existing_entry_count int;
BEGIN
  IF NEW.id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO existing_entry_count
  FROM public."Resident_Template_Gen_Report"
  WHERE resident_id = NEW.id;

  IF existing_entry_count = 0 THEN
    INSERT INTO public."Resident_Template_Gen_Report"(resident_id)
    VALUES (NEW.id);
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_resident_template_gen_report_entry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_pastel_color"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  color_code text;
BEGIN
  -- Select a random color from pastel_color table (using fully qualified name)
  SELECT public.pastel_color.color INTO color_code
  FROM public.pastel_color
  ORDER BY random()
  LIMIT 1;

  NEW.pastel_color := color_code;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."assign_pastel_color"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_program_pastel_color"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  color_code text;
BEGIN
  -- Set search path to empty to prevent search path injection
  SET search_path = '';
  
  SELECT color INTO color_code
  FROM public.pastel_color
  ORDER BY random()
  LIMIT 1;

  NEW.program_pastel_color := color_code;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."assign_program_pastel_color"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_fill_active_season"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- ถ้า season_id ยังเป็น NULL ให้หา active season มาใส่
  IF NEW.season_id IS NULL THEN
    SELECT id INTO NEW.season_id
    FROM training_seasons
    WHERE is_active = true
    LIMIT 1;
    
    -- ถ้าไม่เจอ active season ให้ raise error
    IF NEW.season_id IS NULL THEN
      RAISE EXCEPTION 'No active season found';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_fill_active_season"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_all_cron_jobs"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    job_id INT;
BEGIN
    IF NEW.cancel_snooze THEN
        -- Loop through all cron jobs for the user
        FOR job_id IN
            SELECT j.jobid
            FROM cron.job AS j
            WHERE j.command LIKE format('%%%s%%', OLD.id::UUID) -- Matches user-specific jobs
        LOOP
            -- Unschedule each job
            PERFORM cron.unschedule(job_id);
        END LOOP;

        -- Log the cancellation success
        INSERT INTO snooze_cron_log (user_id, scheduled_time, job_id, status)
        VALUES (NEW.id, NOW(), NULL, 'Cancelled All');
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."cancel_all_cron_jobs"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_and_award_badges"("p_user_id" "uuid", "p_season_id" "uuid", "p_session_id" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_badge RECORD;
  v_should_award BOOLEAN;
  v_req JSONB;
  v_session RECORD;
  v_count INT;
  v_percent NUMERIC;
BEGIN
  -- ดึงข้อมูล session (ถ้ามี)
  IF p_session_id IS NOT NULL THEN
    SELECT * INTO v_session FROM training_quiz_sessions WHERE id = p_session_id;
  END IF;
  
  -- Loop ทุก badge
  FOR v_badge IN SELECT * FROM training_badges WHERE is_active = TRUE
  LOOP
    v_should_award := FALSE;
    v_req := v_badge.requirement_value;
    
    -- ข้ามถ้ามีแล้ว
    IF EXISTS (
      SELECT 1 FROM training_user_badges 
      WHERE user_id = p_user_id AND badge_id = v_badge.id 
        AND (season_id = p_season_id OR season_id IS NULL)
    ) THEN
      CONTINUE;
    END IF;
    
    -- เช็คตามประเภท
    CASE v_badge.requirement_type
      
      WHEN 'perfect_score' THEN
        IF v_session.score = v_session.total_questions THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'high_score_count' THEN
        SELECT COUNT(*) INTO v_count
        FROM training_quiz_sessions
        WHERE user_id = p_user_id AND season_id = p_season_id
          AND score >= (v_req->>'min_score')::INT
          AND completed_at IS NOT NULL;
        IF v_count >= (v_req->>'count')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'improvement' THEN
        IF EXISTS (
          SELECT 1 FROM training_user_progress
          WHERE user_id = p_user_id AND season_id = p_season_id
            AND pretest_score > 0
            AND posttest_score >= pretest_score * (1 + (v_req->>'percent')::NUMERIC / 100)
        ) THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'first_try' THEN
        IF v_session.quiz_type = 'posttest' 
           AND v_session.attempt_number = 1 
           AND v_session.is_passed = TRUE THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'first_try_count' THEN
        SELECT COUNT(DISTINCT topic_id) INTO v_count
        FROM training_quiz_sessions
        WHERE user_id = p_user_id AND season_id = p_season_id
          AND quiz_type = 'posttest' AND attempt_number = 1 AND is_passed = TRUE;
        IF v_count >= (v_req->>'count')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'streak' THEN
        SELECT GREATEST(current_streak, longest_streak) INTO v_count
        FROM training_streaks
        WHERE user_id = p_user_id AND season_id = p_season_id;
        IF v_count >= (v_req->>'days')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'all_topics' THEN
        SELECT COUNT(*) INTO v_count
        FROM training_user_progress
        WHERE user_id = p_user_id AND season_id = p_season_id
          AND posttest_completed_at IS NOT NULL;
        IF v_count >= (SELECT COUNT(*) FROM training_topics WHERE is_active = TRUE) THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'all_reviews' THEN
        SELECT COUNT(*) INTO v_count
        FROM training_user_progress
        WHERE user_id = p_user_id AND season_id = p_season_id
          AND review_count > 0;
        IF v_count >= (SELECT COUNT(*) FROM training_topics WHERE is_active = TRUE) THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'mastery' THEN
        SELECT COUNT(*) INTO v_count
        FROM training_user_progress
        WHERE user_id = p_user_id AND season_id = p_season_id
          AND mastery_level = COALESCE(v_req->>'level', 'expert');
        IF (v_req->>'all')::BOOLEAN = TRUE THEN
          IF v_count >= (SELECT COUNT(*) FROM training_topics WHERE is_active = TRUE) THEN
            v_should_award := TRUE;
          END IF;
        ELSE
          IF v_count >= COALESCE((v_req->>'count')::INT, 1) THEN
            v_should_award := TRUE;
          END IF;
        END IF;
        
      WHEN 'review_count' THEN
        SELECT COALESCE(SUM(review_count), 0) INTO v_count
        FROM training_user_progress
        WHERE user_id = p_user_id AND season_id = p_season_id;
        IF v_count >= (v_req->>'count')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'speed' THEN
        IF v_session.is_passed = TRUE 
           AND v_session.duration_seconds <= (v_req->>'max_seconds')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'time_of_day' THEN
        IF v_session.completed_at IS NOT NULL THEN
          IF v_req->>'before_hour' IS NOT NULL THEN
            IF EXTRACT(HOUR FROM v_session.completed_at) < (v_req->>'before_hour')::INT THEN
              v_should_award := TRUE;
            END IF;
          ELSIF v_req->>'after_hour' IS NOT NULL THEN
            IF EXTRACT(HOUR FROM v_session.completed_at) >= (v_req->>'after_hour')::INT THEN
              v_should_award := TRUE;
            END IF;
          END IF;
        END IF;
        
      WHEN 'weekend' THEN
        SELECT weeks_with_weekend_activity INTO v_count
        FROM training_streaks
        WHERE user_id = p_user_id AND season_id = p_season_id;
        IF v_count >= (v_req->>'weeks')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      WHEN 'thinking_mastery' THEN
        SELECT ROUND(100.0 * SUM(CASE WHEN qa.is_correct THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0))
        INTO v_percent
        FROM training_quiz_answers qa
        JOIN training_questions q ON qa.question_id = q.id
        JOIN training_quiz_sessions qs ON qa.session_id = qs.id
        WHERE qs.user_id = p_user_id AND qs.season_id = p_season_id
          AND q.thinking_type = (v_req->>'type')
          AND qs.completed_at IS NOT NULL;
        IF v_percent >= (v_req->>'percent')::INT THEN
          v_should_award := TRUE;
        END IF;
        
      ELSE
        NULL;
    END CASE;
    
    -- ให้ Badge
    IF v_should_award THEN
      INSERT INTO training_user_badges (user_id, badge_id, season_id)
      VALUES (p_user_id, v_badge.id, p_season_id)
      ON CONFLICT DO NOTHING;
    END IF;
    
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."check_and_award_badges"("p_user_id" "uuid", "p_season_id" "uuid", "p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_clock_in_out_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  last_type text;
BEGIN
  -- Find the latest type for this user
  SELECT type
  INTO last_type
  FROM public."Clock In Out"
  WHERE user_id = NEW.user_id
    AND created_at IS NOT NULL
  ORDER BY created_at DESC
  LIMIT 1;

  -- Allow if no previous clock record
  IF last_type IS NULL THEN
    RETURN NEW;
  END IF;

  -- Prevent duplicate consecutive clock type
  IF NEW.type = last_type THEN
    RAISE EXCEPTION
      'Cannot clock-in or clock-out twice in a row. Last action: %, New action: %',
      last_type, NEW.type;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_clock_in_out_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_fcm_token"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- (ไม่จำเป็นต้อง SET ซ้ำในบอดี้ เพราะตั้งไว้ระดับฟังก์ชันแล้ว)
  -- SET search_path = '';

  -- กันค่าเว้นวรรค/ค่าว่าง
  IF TRIM(COALESCE(NEW.fcm_token, '')) = '' THEN
    RETURN NULL;  -- ยกเลิกรายการนี้ (กัน insert/update ที่เป็นค่าว่าง)
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_fcm_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_secondcpictureurl_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- ทำงานเฉพาะกรณี UPDATE และค่าเปลี่ยนจริง
  IF TG_OP = 'UPDATE'
     AND OLD."SecondCPictureUrl" IS DISTINCT FROM NEW."SecondCPictureUrl" THEN
    BEGIN
      PERFORM supabase_functions.http_request(
        'https://dov46t.buildship.run/executeWorkflow/Mgqje4LQgsJcSEq7Sal8',
        'POST',
        '{"Content-Type":"application/json"}',
        '{}',
        '5000'
      );
    EXCEPTION WHEN OTHERS THEN
      -- บันทึก/กลืน error เพื่อไม่ให้กระทบธุรกรรมหลัก (จะไม่ RAISE)
      -- คุณอาจใส่ RAISE NOTICE ไว้ตรวจสอบชั่วคราวได้
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_secondcpictureurl_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_snooze_cron"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    job_id INT;
BEGIN
    -- Find the job ID associated with this user
    SELECT jobid
    INTO job_id
    FROM cron.job
    WHERE command LIKE '%id = ''' || OLD.id || '''%'
    LIMIT 1;

    IF job_id IS NOT NULL THEN
        BEGIN
            -- Remove the cron job
            PERFORM cron.unschedule(job_id);

            -- Log the successful removal
            INSERT INTO cleanup_snooze_log (user_id, snooze_status, additional_info)
            VALUES (OLD.id, OLD.snooze, format('Successfully removed cron job ID: %s', job_id));
        EXCEPTION WHEN OTHERS THEN
            -- Log the failure
            INSERT INTO cleanup_snooze_log (user_id, snooze_status, additional_info)
            VALUES (OLD.id, OLD.snooze, 'Failed to remove cron job: ' || SQLERRM);
        END;
    ELSE
        -- Log the absence of a matching cron job
        INSERT INTO cleanup_snooze_log (user_id, snooze_status, additional_info)
        VALUES (OLD.id, OLD.snooze, 'No matching cron job found for this user.');
    END IF;

    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."cleanup_snooze_cron"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_post_tag_entries"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$BEGIN
  -- ลบ mapping เดิมของโพสต์
  DELETE FROM public."Post_Tags" pt
  WHERE pt."Post_id" = NEW.id;

  -- ถ้าไม่มีแท็กให้ทำต่อ ก็เคลียร์แล้วจบ
  IF NEW."Tag_Topics" IS NULL OR array_length(NEW."Tag_Topics", 1) IS NULL THEN
    NEW."Tag_Topics" := NULL;
    RETURN NEW;
  END IF;

  -- 1) ใส่แท็กใหม่ที่ยังไม่เคยมี (ตาม nursinghome_id)
  INSERT INTO public."TagsLabel" ("tagName", nursinghome_id)
  SELECT DISTINCT t.tag_name, NEW.nursinghome_id
  FROM unnest(NEW."Tag_Topics") AS t(tag_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public."TagsLabel" tl
    WHERE tl."tagName" = t.tag_name
      AND tl.nursinghome_id = NEW.nursinghome_id
  );

  -- 2) ผูกโพสต์กับแท็กทั้งหมด (กันซ้ำ)
  INSERT INTO public."Post_Tags" ("Post_id", "Tag_id")
  SELECT NEW.id, tl.id
  FROM unnest(NEW."Tag_Topics") AS t(tag_name)
  JOIN public."TagsLabel" tl
    ON tl."tagName" = t.tag_name
   AND tl.nursinghome_id = NEW.nursinghome_id
  WHERE NOT EXISTS (
    SELECT 1
    FROM public."Post_Tags" pt
    WHERE pt."Post_id" = NEW.id
      AND pt."Tag_id" = tl.id
  );

  -- 3) ล้างคอลัมน์ array เพื่อเลี่ยง redundancy
  NEW."Tag_Topics" := NULL;

  RETURN NEW;
END;$$;


ALTER FUNCTION "public"."create_post_tag_entries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_resident_program_entries"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- ทำเฉพาะเมื่อ program_list เปลี่ยนจริง
  if tg_op = 'update' and new.program_list is not distinct from old.program_list then
    return new;
  end if;

  -- เคลียร์ความสัมพันธ์เดิม
  delete from public.resident_programs
  where resident_id = new.id;

  -- ถ้า list ว่าง ก็จบ แต่อย่าไปล้างคอลัมน์ทิ้ง
  if new.program_list is null or array_length(new.program_list, 1) is null then
    return new;
  end if;

  -- ใส่ความสัมพันธ์ใหม่ (ผูกกับ nursinghome_id เพื่อกันหลุดข้ามบ้าน)
  insert into public.resident_programs (resident_id, program_id)
  select new.id, p.id
  from unnest(new.program_list) as n(raw_name)
  cross join lateral lower(trim(both from raw_name)) as name_lc
  join public.programs p
    on lower(p.name) = name_lc
   and p.nursinghome_id = new.nursinghome_id
  on conflict (resident_id, program_id) do nothing;

  -- ❌ อย่าล้างค่าอีกต่อไป
  -- NEW.program_list := NULL;

  return new;
end;
$$;


ALTER FUNCTION "public"."create_resident_program_entries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_resident_underlying_disease_entries"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- ลบความสัมพันธ์เดิมทั้งหมดของ resident นี้ก่อน
  DELETE FROM public.resident_underlying_disease
  WHERE resident_id = NEW.id;

  -- ถ้าลิสต์ว่างหรือเป็นอาร์เรย์ว่าง ให้เคลียร์คอลัมน์แล้วจบ
  IF NEW.underlying_disease_list IS NULL
     OR array_length(NEW.underlying_disease_list, 1) IS NULL THEN
    NEW.underlying_disease_list := NULL;
    RETURN NEW;
  END IF;

  -- แทรกความสัมพันธ์ใหม่ทั้งหมดแบบ set-based
  INSERT INTO public.resident_underlying_disease (resident_id, underlying_id)
  SELECT NEW.id, d.id
  FROM unnest(NEW.underlying_disease_list) AS n(disease_name)
  JOIN public.underlying_disease AS d
    ON d.name = n.disease_name
  ON CONFLICT DO NOTHING;  -- กันซ้ำถ้ามี (ถ้ามี unique constraint คู่ resident_id, underlying_id)

  -- เคลียร์รายการในคอลัมน์เพื่อไม่ให้ข้อมูลซ้ำซ้อน
  NEW.underlying_disease_list := NULL;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_resident_underlying_disease_entries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."date_only"("ts" timestamp with time zone) RETURNS "date"
    LANGUAGE "sql" STABLE STRICT
    SET "search_path" TO ''
    AS $_$
  SELECT $1::date;
$_$;


ALTER FUNCTION "public"."date_only"("ts" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."debug_insert_log_line_queue"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Insert a debug record
    INSERT INTO task_log_line_queue(log_id, status)
    VALUES (NEW.id, 'Debug: Trigger fired - ' || 
           CASE WHEN NEW.post_id IS NOT NULL THEN 'post_id is NOT NULL' ELSE 'post_id is NULL' END || ' - ' ||
           CASE WHEN OLD.post_id IS NULL THEN 'old post_id is NULL' ELSE 'old post_id is NOT NULL' END || ' - ' ||
           CASE WHEN OLD.post_id <> NEW.post_id THEN 'post_id changed' ELSE 'post_id not changed' END);
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."debug_insert_log_line_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."debug_update_log"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- ตรวจสอบว่ามี entry ที่สร้างไปแล้วหรือไม่ในช่วงเวลาใกล้เคียง (ภายใน 5 วินาที)
    IF NOT EXISTS (
        SELECT 1 FROM task_log_line_queue
        WHERE log_id = NEW.id
        AND status = 'waiting'
        AND created_at > NOW() - INTERVAL '5 seconds'
    ) THEN
        -- เพิ่ม entry ที่มีสถานะเป็น 'waiting'
        INSERT INTO task_log_line_queue(log_id, status, created_at)
        VALUES (
            NEW.id,
            'waiting',
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."debug_update_log"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_single_active_season"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.is_active = TRUE THEN
    UPDATE training_seasons SET is_active = FALSE 
    WHERE id != NEW.id AND is_active = TRUE;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."ensure_single_active_season"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_call_webhook_safely"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  begin
    perform supabase_functions.http_request(
      'https://n8nocr.ireneplus.app/webhook/498ef9ec-6c8b-430c-941f-6f6eb15e0a5e',
      'POST',
      '{"Content-Type":"application/json"}',
      json_build_object(
        'queue_id',     NEW.id,
        'vitalsign_id', NEW.vitalsign_id,
        'status',       NEW.status,
        'created_at',   NEW.created_at
      )::text,
      10000
    );

    -- HTTP สำเร็จ → mark PROCESSING
    update vitalsign_sent_queue
       set status = 'PROCESSING'
     where id = NEW.id;

  exception when others then
    -- คง pending ไว้ เพื่อ retry ภายหลัง
    raise notice 'webhook failed: %', sqlerrm;
  end;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."fn_call_webhook_safely"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_enqueue_from_scale_log"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_id bigint := coalesce(new.vital_sign_id, old.vital_sign_id);
begin
  if v_id is null then
    return null;
  end if;

  perform pg_advisory_xact_lock(v_id);

  insert into vitalsign_sent_queue (vitalsign_id, status)
  select v_id, 'pending'
  where not exists (
          select 1 from vitalsign_sent_queue q
          where q.vitalsign_id = v_id
            and q.status in ('pending','PROCESSING')
        )
    and not exists (
          select 1 from vitalsign_sent_queue q
          where q.vitalsign_id = v_id
            and q.status = 'SENT'
        );

  return null;
end;
$$;


ALTER FUNCTION "public"."fn_enqueue_from_scale_log"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- ถ้าเคย SENT แล้ว ไม่ต้องคิวใหม่
  if exists (
    select 1 from vitalsign_sent_queue q
    where q.vitalsign_id = new.id and q.status = 'SENT'
  ) then
    return new;
  end if;

  -- กัน race ระหว่างหลายทริกเกอร์/ทรานแซกชันของ vital_sign เดียวกัน
  perform pg_advisory_xact_lock(new.id::bigint);

  -- ใส่คิวเฉพาะเมื่อยังไม่มีคิวค้างอยู่
  if not exists (
       select 1 from vitalsign_sent_queue q
       where q.vitalsign_id = new.id
         and q.status in ('pending','PROCESSING')
     ) then
    insert into vitalsign_sent_queue (vitalsign_id, status)
    values (new.id, 'pending');
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_insert_log_line_queue"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Insert debug information first to confirm trigger is firing
    INSERT INTO task_log_line_queue (log_id, status, created_at)
    VALUES (NEW.id, 'Trigger fired: ' || TG_OP, NOW());
    
    -- Handle the actual business logic
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.post_id IS NOT NULL THEN
        -- Insert the actual record we need
        INSERT INTO task_log_line_queue (log_id, post_id, created_at)
        VALUES (NEW.id, NEW.post_id, NOW());
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_insert_log_line_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_log_webhook_trigger"("p_webhook_id" "text", "p_event_type" "text", "p_payload" "jsonb", "p_response_status" integer DEFAULT NULL::integer, "p_response_body" "text" DEFAULT NULL::"text", "p_error_message" "text" DEFAULT NULL::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_log_id BIGINT;
BEGIN
  INSERT INTO public.webhook_trigger_logs (
    webhook_id,
    event_type,
    payload,
    response_status,
    response_body,
    error_message
  ) VALUES (
    p_webhook_id,
    p_event_type,
    p_payload,
    p_response_status,
    p_response_body,
    p_error_message
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;


ALTER FUNCTION "public"."fn_log_webhook_trigger"("p_webhook_id" "text", "p_event_type" "text", "p_payload" "jsonb", "p_response_status" integer, "p_response_body" "text", "p_error_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_process_post_id_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- ตรวจสอบเพื่อป้องกันการทำงานซ้ำซ้อน
    IF NOT EXISTS (
        SELECT 1 FROM task_log_line_queue
        WHERE log_id = NEW.id
        AND created_at > NOW() - INTERVAL '5 seconds'
    ) THEN
        -- เพิ่มข้อมูลเข้าคิว
        INSERT INTO task_log_line_queue(log_id, status, created_at)
        VALUES (
            NEW.id,
            'waiting',
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_process_post_id_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_season"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT id FROM training_seasons WHERE is_active = TRUE LIMIT 1;
$$;


ALTER FUNCTION "public"."get_active_season"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_complete_schema"() RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result jsonb;
BEGIN
    -- Get all enums
    WITH enum_types AS (
        SELECT 
            t.typname as enum_name,
            array_agg(e.enumlabel ORDER BY e.enumsortorder) as enum_values
        FROM pg_type t
        JOIN pg_enum e ON t.oid = e.enumtypid
        JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
        GROUP BY t.typname
    )
    SELECT jsonb_build_object(
        'enums',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', enum_name,
                    'values', to_jsonb(enum_values)
                )
            ),
            '[]'::jsonb
        )
    )
    FROM enum_types
    INTO result;

    -- Get all tables with their details
    WITH RECURSIVE 
    columns_info AS (
        SELECT 
            c.oid as table_oid,
            c.relname as table_name,
            a.attname as column_name,
            format_type(a.atttypid, a.atttypmod) as column_type,
            a.attnotnull as notnull,
            pg_get_expr(d.adbin, d.adrelid) as column_default,
            CASE 
                WHEN a.attidentity != '' THEN true
                WHEN pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%' THEN true
                ELSE false
            END as is_identity,
            EXISTS (
                SELECT 1 FROM pg_constraint con 
                WHERE con.conrelid = c.oid 
                AND con.contype = 'p' 
                AND a.attnum = ANY(con.conkey)
            ) as is_pk
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_attribute a ON a.attrelid = c.oid
        LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
        WHERE n.nspname = 'public' 
        AND c.relkind = 'r'
        AND a.attnum > 0 
        AND NOT a.attisdropped
    ),
    fk_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', con.conname,
                    'column', col.attname,
                    'foreign_schema', fs.nspname,
                    'foreign_table', ft.relname,
                    'foreign_column', fcol.attname,
                    'on_delete', CASE con.confdeltype
                        WHEN 'a' THEN 'NO ACTION'
                        WHEN 'c' THEN 'CASCADE'
                        WHEN 'r' THEN 'RESTRICT'
                        WHEN 'n' THEN 'SET NULL'
                        WHEN 'd' THEN 'SET DEFAULT'
                        ELSE NULL
                    END
                )
            ) as foreign_keys
        FROM pg_class c
        JOIN pg_constraint con ON con.conrelid = c.oid
        JOIN pg_attribute col ON col.attrelid = con.conrelid AND col.attnum = ANY(con.conkey)
        JOIN pg_class ft ON ft.oid = con.confrelid
        JOIN pg_namespace fs ON fs.oid = ft.relnamespace
        JOIN pg_attribute fcol ON fcol.attrelid = con.confrelid AND fcol.attnum = ANY(con.confkey)
        WHERE con.contype = 'f'
        GROUP BY c.oid
    ),
    index_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', i.relname,
                    'using', am.amname,
                    'columns', (
                        SELECT jsonb_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum))
                        FROM unnest(ix.indkey) WITH ORDINALITY as u(attnum, ord)
                        JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = u.attnum
                    )
                )
            ) as indexes
        FROM pg_class c
        JOIN pg_index ix ON ix.indrelid = c.oid
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_am am ON am.oid = i.relam
        WHERE NOT ix.indisprimary
        GROUP BY c.oid
    ),
    policy_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', pol.polname,
                    'command', CASE pol.polcmd
                        WHEN 'r' THEN 'SELECT'
                        WHEN 'a' THEN 'INSERT'
                        WHEN 'w' THEN 'UPDATE'
                        WHEN 'd' THEN 'DELETE'
                        WHEN '*' THEN 'ALL'
                    END,
                    'roles', (
                        SELECT string_agg(quote_ident(r.rolname), ', ')
                        FROM pg_roles r
                        WHERE r.oid = ANY(pol.polroles)
                    ),
                    'using', pg_get_expr(pol.polqual, pol.polrelid),
                    'check', pg_get_expr(pol.polwithcheck, pol.polrelid)
                )
            ) as policies
        FROM pg_class c
        JOIN pg_policy pol ON pol.polrelid = c.oid
        GROUP BY c.oid
    ),
    trigger_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', t.tgname,
                    'timing', CASE 
                        WHEN t.tgtype & 2 = 2 THEN 'BEFORE'
                        WHEN t.tgtype & 4 = 4 THEN 'AFTER'
                        WHEN t.tgtype & 64 = 64 THEN 'INSTEAD OF'
                    END,
                    'events', (
                        CASE WHEN t.tgtype & 1 = 1 THEN 'INSERT'
                             WHEN t.tgtype & 8 = 8 THEN 'DELETE'
                             WHEN t.tgtype & 16 = 16 THEN 'UPDATE'
                             WHEN t.tgtype & 32 = 32 THEN 'TRUNCATE'
                        END
                    ),
                    'statement', pg_get_triggerdef(t.oid)
                )
            ) as triggers
        FROM pg_class c
        JOIN pg_trigger t ON t.tgrelid = c.oid
        WHERE NOT t.tgisinternal
        GROUP BY c.oid
    ),
    table_info AS (
        SELECT DISTINCT 
            c.table_oid,
            c.table_name,
            jsonb_agg(
                jsonb_build_object(
                    'name', c.column_name,
                    'type', c.column_type,
                    'notnull', c.notnull,
                    'default', c.column_default,
                    'identity', c.is_identity,
                    'is_pk', c.is_pk
                ) ORDER BY c.column_name
            ) as columns,
            COALESCE(fk.foreign_keys, '[]'::jsonb) as foreign_keys,
            COALESCE(i.indexes, '[]'::jsonb) as indexes,
            COALESCE(p.policies, '[]'::jsonb) as policies,
            COALESCE(t.triggers, '[]'::jsonb) as triggers
        FROM columns_info c
        LEFT JOIN fk_info fk ON fk.table_oid = c.table_oid
        LEFT JOIN index_info i ON i.table_oid = c.table_oid
        LEFT JOIN policy_info p ON p.table_oid = c.table_oid
        LEFT JOIN trigger_info t ON t.table_oid = c.table_oid
        GROUP BY c.table_oid, c.table_name, fk.foreign_keys, i.indexes, p.policies, t.triggers
    )
    SELECT result || jsonb_build_object(
        'tables',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', table_name,
                    'columns', columns,
                    'foreign_keys', foreign_keys,
                    'indexes', indexes,
                    'policies', policies,
                    'triggers', triggers
                )
            ),
            '[]'::jsonb
        )
    )
    FROM table_info
    INTO result;

    -- Get all functions
    WITH function_info AS (
        SELECT 
            p.proname AS name,
            pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
        AND p.prokind = 'f'
    )
    SELECT result || jsonb_build_object(
        'functions',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', name,
                    'definition', definition
                )
            ),
            '[]'::jsonb
        )
    )
    FROM function_info
    INTO result;

    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_complete_schema"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_progress"("p_user_id" "uuid", "p_topic_id" "text", "p_season_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_progress_id UUID;
  v_season_id UUID;
BEGIN
  v_season_id := COALESCE(p_season_id, (SELECT id FROM training_seasons WHERE is_active = TRUE LIMIT 1));
  
  SELECT id INTO v_progress_id
  FROM training_user_progress
  WHERE user_id = p_user_id AND topic_id = p_topic_id AND season_id = v_season_id;
  
  IF v_progress_id IS NULL THEN
    INSERT INTO training_user_progress (user_id, topic_id, season_id)
    VALUES (p_user_id, p_topic_id, v_season_id)
    RETURNING id INTO v_progress_id;
  END IF;
  
  RETURN v_progress_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_progress"("p_user_id" "uuid", "p_topic_id" "text", "p_season_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_random_questions"("p_topic_id" "text", "p_count" integer DEFAULT 20, "p_season_id" "uuid" DEFAULT NULL::"uuid", "p_exclude_session_ids" "uuid"[] DEFAULT '{}'::"uuid"[]) RETURNS TABLE("id" "uuid", "question_text" "text", "question_image_url" "text", "choices" "jsonb", "difficulty" integer, "thinking_type" "text")
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_season_id UUID;
BEGIN
  v_season_id := COALESCE(p_season_id, get_active_season());
  
  RETURN QUERY
  SELECT 
    q.id,
    q.question_text,
    q.question_image_url,
    q.choices,
    q.difficulty,
    q.thinking_type
  FROM training_questions q
  WHERE q.topic_id = p_topic_id
    AND q.is_active = TRUE
    AND (q.season_id IS NULL OR q.season_id = v_season_id)
    -- Optional: exclude questions from previous sessions
    AND (
      p_exclude_session_ids = '{}' 
      OR q.id NOT IN (
        SELECT qa.question_id 
        FROM training_quiz_answers qa 
        WHERE qa.session_id = ANY(p_exclude_session_ids)
      )
    )
  ORDER BY RANDOM()
  LIMIT p_count;
END;
$$;


ALTER FUNCTION "public"."get_random_questions"("p_topic_id" "text", "p_count" integer, "p_season_id" "uuid", "p_exclude_session_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_service_account"() RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  service_account jsonb;
BEGIN
  SELECT jsonb_build_object(
    'project_id', project_id,
    'private_key_id', private_key_id,
    'private_key', private_key,
    'client_email', client_email,
    'client_id', client_id,
    'auth_uri', auth_uri,
    'token_uri', token_uri,
    'auth_provider_x509_cert_url', auth_provider_x509_cert_url,
    'client_x509_cert_url', client_x509_cert_url
  )
  INTO service_account
  FROM public.service_account_table   -- เปลี่ยนเป็นชื่อตารางจริงของคุณ
  LIMIT 1;

  RETURN service_account;  -- ถ้าไม่พบแถว จะคืน NULL
END;
$$;


ALTER FUNCTION "public"."get_service_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_dashboard"("p_user_id" "uuid") RETURNS "json"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_season_id UUID;
BEGIN
  v_season_id := get_active_season();
  
  RETURN json_build_object(
    'season', (
      SELECT row_to_json(s) 
      FROM training_seasons s 
      WHERE s.id = v_season_id
    ),
    'rank', (
      SELECT json_build_object(
        'position', rank,
        'total_score', total_score,
        'total_users', (SELECT COUNT(DISTINCT user_id) FROM training_quiz_sessions WHERE season_id = v_season_id)
      )
      FROM v_leaderboard
      WHERE user_id = p_user_id AND season_id = v_season_id
    ),
    'streak', (
      SELECT row_to_json(st)
      FROM training_streaks st
      WHERE st.user_id = p_user_id AND st.season_id = v_season_id
    ),
    'badges', (
      SELECT json_agg(json_build_object(
        'name', b.name,
        'icon', b.icon,
        'description', b.description,
        'earned_at', ub.earned_at
      ))
      FROM training_user_badges ub
      JOIN training_badges b ON ub.badge_id = b.id
      WHERE ub.user_id = p_user_id AND (ub.season_id = v_season_id OR ub.season_id IS NULL)
    ),
    'thinking_stats', (
      SELECT json_agg(row_to_json(t))
      FROM v_thinking_analysis t
      WHERE t.user_id = p_user_id AND t.season_id = v_season_id
    ),
    'needs_review', (
      SELECT json_agg(json_build_object(
        'topic_id', up.topic_id,
        'topic_name', t.name,
        'next_review_at', up.next_review_at,
        'days_overdue', EXTRACT(DAY FROM NOW() - up.next_review_at)::INT
      ))
      FROM training_user_progress up
      JOIN training_topics t ON up.topic_id = t.id
      WHERE up.user_id = p_user_id 
        AND up.season_id = v_season_id
        AND up.posttest_completed_at IS NOT NULL
        AND up.next_review_at <= NOW()
    ),
    'recent_activity', (
      SELECT json_agg(row_to_json(r))
      FROM (
        SELECT 
          qs.id,
          t.name as topic_name,
          qs.quiz_type,
          qs.score,
          qs.total_questions,
          qs.is_passed,
          qs.completed_at
        FROM training_quiz_sessions qs
        JOIN training_topics t ON qs.topic_id = t.id
        WHERE qs.user_id = p_user_id AND qs.season_id = v_season_id
          AND qs.completed_at IS NOT NULL
        ORDER BY qs.completed_at DESC
        LIMIT 10
      ) r
    ),
    'topic_progress', (
      SELECT json_agg(row_to_json(p))
      FROM v_topic_progress p
      WHERE p.user_id = p_user_id AND p.season_id = v_season_id
    )
  );
END;
$$;


ALTER FUNCTION "public"."get_user_dashboard"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."insert_task_summary"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    SET "TimeZone" TO 'Asia/Bangkok'
    AS $$
DECLARE
  period_start time;
  period_end   time;
  period_label text;
  task_ids           jsonb;
  repeated_task_ids  jsonb[];
BEGIN
  -- 1) คำนวณช่วงเวลาและ label (ช่วงครึ่งเปิด [start, end))
  SELECT
    CASE 
      WHEN now()::time >= time '07:00' AND now()::time < time '09:00' THEN time '07:00'
      WHEN now()::time >= time '09:00' AND now()::time < time '11:00' THEN time '09:00'
      WHEN now()::time >= time '11:00' AND now()::time < time '13:00' THEN time '11:00'
      WHEN now()::time >= time '13:00' AND now()::time < time '15:00' THEN time '13:00'
      WHEN now()::time >= time '15:00' AND now()::time < time '17:00' THEN time '15:00'
      WHEN now()::time >= time '17:00' AND now()::time < time '19:00' THEN time '17:00'
      WHEN now()::time >= time '19:00' AND now()::time < time '21:00' THEN time '19:00'
      WHEN now()::time >= time '21:00' AND now()::time < time '23:00' THEN time '21:00'
    END,
    CASE 
      WHEN now()::time >= time '07:00' AND now()::time < time '09:00' THEN time '09:00'
      WHEN now()::time >= time '09:00' AND now()::time < time '11:00' THEN time '11:00'
      WHEN now()::time >= time '11:00' AND now()::time < time '13:00' THEN time '13:00'
      WHEN now()::time >= time '13:00' AND now()::time < time '15:00' THEN time '15:00'
      WHEN now()::time >= time '15:00' AND now()::time < time '17:00' THEN time '17:00'
      WHEN now()::time >= time '17:00' AND now()::time < time '19:00' THEN time '19:00'
      WHEN now()::time >= time '19:00' AND now()::time < time '21:00' THEN time '21:00'
      WHEN now()::time >= time '21:00' AND now()::time < time '23:00' THEN time '23:00'
    END,
    CASE 
      WHEN now()::time >= time '07:00' AND now()::time < time '09:00' THEN '07:00 - 09:00'
      WHEN now()::time >= time '09:00' AND now()::time < time '11:00' THEN '09:00 - 11:00'
      WHEN now()::time >= time '11:00' AND now()::time < time '13:00' THEN '11:00 - 13:00'
      WHEN now()::time >= time '13:00' AND now()::time < time '15:00' THEN '13:00 - 15:00'
      WHEN now()::time >= time '15:00' AND now()::time < time '17:00' THEN '15:00 - 17:00'
      WHEN now()::time >= time '17:00' AND now()::time < time '19:00' THEN '17:00 - 19:00'
      WHEN now()::time >= time '19:00' AND now()::time < time '21:00' THEN '19:00 - 21:00'
      WHEN now()::time >= time '21:00' AND now()::time < time '23:00' THEN '21:00 - 23:00'
    END
  INTO period_start, period_end, period_label;

  -- ถ้าเวลาปัจจุบันอยู่นอกช่วงที่กำหนด → ไม่ทำอะไร
  IF period_start IS NULL OR period_end IS NULL THEN
    RETURN;
  END IF;

  -- 2) งานที่ยังไม่มี log ในช่วงนั้น (A_Tasks)
  SELECT jsonb_agg(t.id)
  INTO task_ids
  FROM public."A_Tasks" t
  WHERE NOT EXISTS (
    SELECT 1
    FROM public."A_Task_logs" l
    WHERE l.task_id = t.id
      AND l.created_at::date = now()::date
      AND l.created_at::time >= period_start
      AND l.created_at::time <  period_end
  );

  -- 3) งานแบบวนซ้ำที่ยังไม่มี log ในช่วงนั้น (A_Repeated_Task)
  SELECT array_agg(rt.id)
  INTO repeated_task_ids
  FROM public."A_Repeated_Task" rt
  WHERE NOT EXISTS (
    SELECT 1
    FROM public."A_Task_logs" l
    WHERE l."Task_Repeat_Id" = rt.id
      AND l.created_at::date = now()::date
      AND l.created_at::time >= period_start
      AND l.created_at::time <  period_end
  );

  -- 4) บันทึกสรุป (กัน null)
  INSERT INTO public."A_Task_Summary"
    (type, period, time_send, task_ids, repeated_task_id)
  VALUES
    ('รายชั่วโมง',
     period_label,
     now()::time,
     COALESCE(task_ids, '[]'::jsonb),
     COALESCE(repeated_task_ids, '{}'::jsonb[])
    )
  ON CONFLICT DO NOTHING;  -- เปิดใช้ถ้าคุณสร้าง unique key กันซ้ำ
END;
$$;


ALTER FUNCTION "public"."insert_task_summary"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_new_comment"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  postCreatorId uuid;
  postNursingHomeId bigint;
  commenterNickname text;
BEGIN
  -- ดึงข้อมูลโพสต์และเจ้าของโพสต์
  SELECT p.user_id, p.nursinghome_id
  INTO postCreatorId, postNursingHomeId
  FROM public."Post" p
  WHERE p.id = NEW."Post_id";

  -- ถ้าไม่พบโพสต์ ก็จบ
  IF postCreatorId IS NULL THEN
    RETURN NEW;
  END IF;

  -- ชื่อนิคเนมของผู้คอมเมนต์ (อาจเป็น NULL ได้)
  SELECT ui.nickname
  INTO commenterNickname
  FROM public.user_info ui
  WHERE ui.id = NEW.user_id;

  -- ถ้าคอมเมนต์ไม่ใช่เจ้าของโพสต์ → สร้างแจ้งเตือน
  IF NEW.user_id IS DISTINCT FROM postCreatorId THEN
    INSERT INTO public."Notification_Center"
      (post_id, user_id, nursinghome_id, content, seen, originate)
    VALUES
      (NEW."Post_id",
       postCreatorId,
       postNursingHomeId,
       COALESCE(commenterNickname, 'สมาชิกไม่ระบุนาม') || ' ได้แสดงความคิดเห็นในโพสต์ของคุณ',
       FALSE,
       'from post comment');
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_new_comment"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_new_post"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  userid uuid;
BEGIN
  -- ถ้ามีผู้ใช้ถูก tag และ array ไม่ว่าง
  IF NEW.tagged_user IS NOT NULL 
     AND array_length(NEW.tagged_user, 1) > 0 THEN
    
    FOREACH userid IN ARRAY NEW.tagged_user
    LOOP
      INSERT INTO public."Notification_Center" (
        post_id, 
        user_id, 
        nursinghome_id, 
        content, 
        originate
      )
      VALUES (
        NEW.id, 
        userid, 
        NEW.nursinghome_id, 
        'จากกระดานข่าว: ' || COALESCE(NEW."Text", ''), 
        'from post tagged'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_new_post"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."post_enqueue_if_send_to_relative"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  has_tag_new boolean := coalesce(NEW."Tag_Topics", '{}') && array['ส่งให้ญาติ']::text[];
  has_tag_old boolean := coalesce(OLD."Tag_Topics", '{}') && array['ส่งให้ญาติ']::text[];
begin
  -- INSERT: ถ้ามีแท็ก ก็เข้าคิว
  if TG_OP = 'INSERT' then
    if has_tag_new then
      insert into public.prn_post_queue (post_id, status)
      select NEW.id, 'waiting'
      where not exists (
        select 1 from public.prn_post_queue q
        where q.post_id = NEW.id
          and q.status in ('waiting','processing')
      );
    end if;
    return NEW;
  end if;

  -- UPDATE: เข้าคิวเฉพาะช่วง "เพิ่ม" แท็กนี้เข้ามา
  if TG_OP = 'UPDATE' then
    if has_tag_new and not has_tag_old then
      insert into public.prn_post_queue (post_id, status)
      select NEW.id, 'waiting'
      where not exists (
        select 1 from public.prn_post_queue q
        where q.post_id = NEW.id
          and q.status in ('waiting','processing')
      );
    end if;
    return NEW;
  end if;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."post_enqueue_if_send_to_relative"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_third_check_img"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
    -- Check if ThirdCPictureUrl is not null or empty
    IF NEW."ThirdCPictureUrl" IS NOT NULL AND NEW."ThirdCPictureUrl" <> '' THEN
        -- Insert into A_Med_Blurhash
        INSERT INTO public."A_Med_Blurhash" ("MedLogId", "PictureUrl", "Type")
        VALUES (NEW.id, NEW."ThirdCPictureUrl", 3);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."process_third_check_img"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_program_summary_daily"() RETURNS "void"
    LANGUAGE "sql"
    SET "search_path" TO ''
    SET "TimeZone" TO 'Asia/Bangkok'
    AS $$
  INSERT INTO public.program_summary_daily (
    snapshot_date,
    program_id,
    program_name,
    nursinghome_id,
    member_count,
    resident_names,
    created_at
  )
  SELECT
    current_date,                           -- = (now() at time zone 'Asia/Bangkok')::date
    v.program_id,
    v.program_name,
    v.nursinghome_id,
    COUNT(DISTINCT v.resident_id) AS member_count,
    ARRAY_AGG(DISTINCT v.resident_name ORDER BY v.resident_name) AS resident_names,
    now()                                   -- ตาม timezone ที่ตั้งไว้ด้านบน
  FROM public.v_program_membership v
  WHERE v.s_status = 'Stay'
  GROUP BY v.program_id, v.program_name, v.nursinghome_id
  ON CONFLICT (snapshot_date, program_id, nursinghome_id) DO UPDATE
  SET member_count   = EXCLUDED.member_count,
      resident_names = EXCLUDED.resident_names,
      created_at     = EXCLUDED.created_at;
$$;


ALTER FUNCTION "public"."refresh_program_summary_daily"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_duplicates_from_lists"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- ทำงานเฉพาะตอนมีการแก้ program_list จริงๆ
  if tg_op = 'update' and new.program_list is not distinct from old.program_list then
    return new;
  end if;

  if new.program_list is not null then
    new.program_list := (
      select coalesce(array_agg(distinct trim(both from v)), '{}')
      from unnest(new.program_list) as v
    );
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."remove_duplicates_from_lists"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."schedule_snooze_cron"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    SET "TimeZone" TO 'Asia/Bangkok'
    AS $$
DECLARE
  job_id int;
  run_at timestamptz;
  schedule_time text;
BEGIN
  INSERT INTO public.trigger_schedule_snooze_log (user_id, snooze_status, additional_info)
  VALUES (NEW.id, NEW.snooze, 'Trigger executed.');

  IF NEW.snooze THEN
    run_at := now() + interval '1 hour';
    schedule_time := to_char(run_at, 'MI HH') || ' * * *';

    BEGIN
      job_id := cron.schedule(
        schedule_time,
        format(
          'UPDATE public.user_info SET snooze = false WHERE id = %L',
          NEW.id::uuid
        )
      );

      INSERT INTO public.trigger_schedule_snooze_log (user_id, snooze_status, additional_info)
      VALUES (NEW.id, NEW.snooze, format('Cron job %s scheduled at %s (Asia/Bangkok).', job_id, schedule_time));

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO public.trigger_schedule_snooze_log (user_id, snooze_status, additional_info)
      VALUES (NEW.id, NEW.snooze, 'Failed to schedule cron job: ' || SQLERRM);
    END; -- ปิด block BEGIN/EXCEPTION
  END IF; -- ปิด IF NEW.snooze
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."schedule_snooze_cron"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_active_season_for_question"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- ถ้า season_id เป็น NULL → ใส่ active season
  IF NEW.season_id IS NULL THEN
    SELECT id INTO NEW.season_id
    FROM training_seasons
    WHERE is_active = TRUE
    LIMIT 1;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_active_season_for_question"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_must_complete_by_image"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- ถ้า sampleImageURL เป็น null หรือ empty ให้ตั้ง must_complete_by_image = false
  IF NEW."sampleImageURL" IS NULL OR trim(NEW."sampleImageURL") = '' THEN
    NEW.must_complete_by_image := false;
  END IF;

  -- ถ้าไม่ใช่ null/empty จะไม่ไปยุ่ง must_complete_by_image ให้ user กำหนดเองได้
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_must_complete_by_image"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."track_content_read"("p_user_id" "uuid", "p_topic_id" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_progress_id UUID;
BEGIN
  v_progress_id := get_or_create_progress(p_user_id, p_topic_id);
  
  UPDATE training_user_progress SET
    content_read_at = COALESCE(content_read_at, NOW()),
    content_read_count = content_read_count + 1,
    updated_at = NOW()
  WHERE id = v_progress_id;
END;
$$;


ALTER FUNCTION "public"."track_content_read"("p_user_id" "uuid", "p_topic_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_update_daysofweek"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW."recurrenceType" = 'สัปดาห์'
     AND (NEW."daysOfWeek" IS NULL OR NEW."daysOfWeek" = '{}') THEN
    
    NEW."daysOfWeek" = ARRAY[
      CASE EXTRACT(DOW FROM NEW."start_Date")
        WHEN 0 THEN 'อาทิตย์'
        WHEN 1 THEN 'จันทร์'
        WHEN 2 THEN 'อังคาร'
        WHEN 3 THEN 'พุธ'
        WHEN 4 THEN 'พฤหัส'
        WHEN 5 THEN 'ศุกร์'
        WHEN 6 THEN 'เสาร์'
      END
    ];
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_update_daysofweek"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_daysofweek"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE public."A_Repeated_Task"
  SET "daysOfWeek" = ARRAY[
    CASE EXTRACT(DOW FROM "start_Date")
      WHEN 0 THEN 'อาทิตย์'
      WHEN 1 THEN 'จันทร์'
      WHEN 2 THEN 'อังคาร'
      WHEN 3 THEN 'พุธ'
      WHEN 4 THEN 'พฤหัส'
      WHEN 5 THEN 'ศุกร์'
      WHEN 6 THEN 'เสาร์'
    END
  ],
  update_status = TRUE
  WHERE "recurrenceType" = 'สัปดาห์' 
    AND ("daysOfWeek" IS NULL OR ARRAY_LENGTH("daysOfWeek", 1) = 0);
END;
$$;


ALTER FUNCTION "public"."update_daysofweek"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_index"() RETURNS "void"
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  UPDATE public.resident_caution_manual rcm
  SET index = sub.new_index
  FROM (
    SELECT id,
           row_number() OVER (
             PARTITION BY resident_id
             ORDER BY created_at
           ) - 1 AS new_index
    FROM public.resident_caution_manual
  ) AS sub
  WHERE rcm.id = sub.id;
$$;


ALTER FUNCTION "public"."update_index"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_notification_on_like"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
    contentCreatorId uuid;
    likerNickname text;
    notificationContent text;
BEGIN
    -- Fetch nickname of the liker
    SELECT ui.nickname
    INTO likerNickname
    FROM public.user_info ui
    WHERE ui.id = NEW.user_id;

    -- Handle Post like
    IF NEW."Post_id" IS NOT NULL THEN
        SELECT p.user_id
        INTO contentCreatorId
        FROM public."Post" p
        WHERE p.id = NEW."Post_id";

        notificationContent := COALESCE(likerNickname, 'ผู้ใช้') || ' รับทราบข่าวสารของคุณ';

    -- Handle Comment like
    ELSIF NEW."Comment_id" IS NOT NULL THEN
        SELECT c.user_id
        INTO contentCreatorId
        FROM public."CommentPost" c
        WHERE c.id = NEW."Comment_id";

        notificationContent := COALESCE(likerNickname, 'ผู้ใช้') || ' รับทราบความเห็นของคุณ';
    END IF;

    -- Insert notification if liker is not the creator
    IF contentCreatorId IS NOT NULL AND NEW.user_id <> contentCreatorId THEN
        INSERT INTO public."Notification_Center" (
            post_id,
            comment_id,
            user_id,
            content,
            seen,
            originate
        )
        VALUES (
            NEW."Post_id",
            NEW."Comment_id",
            contentCreatorId,
            notificationContent,
            FALSE,
            CASE
                WHEN NEW."Post_id" IS NOT NULL THEN 'from post liked'
                WHEN NEW."Comment_id" IS NOT NULL THEN 'from comment liked'
            END
        );
    END IF;

    -- Mark own like as seen
    UPDATE public."Notification_Center" nc
    SET seen = TRUE
    WHERE (nc.post_id = NEW."Post_id" OR nc.comment_id = NEW."Comment_id")
      AND nc.user_id = NEW.user_id;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_notification_on_like"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_notification_on_unlike"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- เคส unlike: ปรับสถานะ seen = FALSE ทั้งกรณี post และ comment ในคำสั่งเดียว
  UPDATE public."Notification_Center" nc
  SET seen = FALSE
  WHERE nc.user_id = OLD.user_id
    AND (
      (OLD."Post_id"    IS NOT NULL AND nc.post_id    = OLD."Post_id")
      OR
      (OLD."Comment_id" IS NOT NULL AND nc.comment_id = OLD."Comment_id")
    );

  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."update_notification_on_unlike"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_progress_on_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
    -- === POSTTEST ===
    IF NEW.quiz_type = 'posttest' THEN
      UPDATE training_user_progress SET 
        posttest_attempts = posttest_attempts + 1,
        posttest_score = GREATEST(COALESCE(posttest_score, 0), NEW.score),
        posttest_completed_at = COALESCE(posttest_completed_at, NEW.completed_at),
        is_passed = (is_passed OR (NEW.score >= NEW.passing_score)),
        updated_at = NOW()
      WHERE id = NEW.progress_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_progress_on_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_resident_report_relation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- ลบความสัมพันธ์เดิมทั้งหมดของ resident นี้
  DELETE FROM public."Resident_Report_Relation"
  WHERE resident_id = NEW.id;

  -- แทรกเวรเช้าแบบ set-based
  IF NEW."Report_Scale_Day" IS NOT NULL THEN
    INSERT INTO public."Resident_Report_Relation"(resident_id, subject_id, shift)
    SELECT NEW.id, unnest(NEW."Report_Scale_Day") AS subject_id, 'เวรเช้า'
    ON CONFLICT (resident_id, subject_id, shift) DO NOTHING;
  END IF;

  -- แทรกเวรดึกแบบ set-based
  IF NEW."Report_Scale_Night" IS NOT NULL THEN
    INSERT INTO public."Resident_Report_Relation"(resident_id, subject_id, shift)
    SELECT NEW.id, unnest(NEW."Report_Scale_Night") AS subject_id, 'เวรดึก'
    ON CONFLICT (resident_id, subject_id, shift) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_resident_report_relation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_streak"("p_user_id" "uuid", "p_season_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_streak RECORD;
  v_today DATE := CURRENT_DATE;
  v_is_weekend BOOLEAN := EXTRACT(DOW FROM v_today) IN (0, 6);
BEGIN
  SELECT * INTO v_streak
  FROM training_streaks
  WHERE user_id = p_user_id AND season_id = p_season_id;
  
  IF NOT FOUND THEN
    INSERT INTO training_streaks (user_id, season_id, current_streak, longest_streak, last_activity_date)
    VALUES (p_user_id, p_season_id, 1, 1, v_today);
  ELSE
    IF v_streak.last_activity_date = v_today THEN
      -- ทำไปแล้ววันนี้
      NULL;
    ELSIF v_streak.last_activity_date = v_today - 1 THEN
      -- ต่อเนื่องจากเมื่อวาน
      UPDATE training_streaks SET
        current_streak = current_streak + 1,
        longest_streak = GREATEST(longest_streak, current_streak + 1),
        last_activity_date = v_today
      WHERE user_id = p_user_id AND season_id = p_season_id;
    ELSE
      -- ขาดไป เริ่มนับใหม่
      UPDATE training_streaks SET
        current_streak = 1,
        last_activity_date = v_today
      WHERE user_id = p_user_id AND season_id = p_season_id;
    END IF;
    
    -- Track weekend activity
    IF v_is_weekend AND (v_streak.last_activity_date IS NULL OR 
       EXTRACT(WEEK FROM v_streak.last_activity_date) != EXTRACT(WEEK FROM v_today)) THEN
      UPDATE training_streaks SET
        weeks_with_weekend_activity = weeks_with_weekend_activity + 1
      WHERE user_id = p_user_id AND season_id = p_season_id;
    END IF;
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_user_streak"("p_user_id" "uuid", "p_season_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_zone_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.zone_text IS NOT NULL THEN
    -- เลือกแบบ subquery เดียว อ่านง่าย
    NEW.s_zone := (
      SELECT nz.id
      FROM public.nursinghome_zone nz
      WHERE nz.zone = NEW.zone_text
        AND nz.nursinghome_id = NEW.nursinghome_id
      LIMIT 1
    );

    -- ล้างข้อความเพื่อกันสับสนในอนาคต
    NEW.zone_text := NULL;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_zone_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_zone_id_based_on_text"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
    NEW.s_zone := (
        SELECT nz.id
        FROM public.nursinghome_zone AS nz
        WHERE nz.zone = NEW.zone_text
    );
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_zone_id_based_on_text"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_zone_id_based_on_text"("resident_id_input" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
  UPDATE public.residents AS r
  SET s_zone = nz.id
  FROM public.nursinghome_zone AS nz
  WHERE r.id = resident_id_input
    AND nz.zone = r.zone_text;
END;
$$;


ALTER FUNCTION "public"."update_zone_id_based_on_text"("resident_id_input" bigint) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."A_Med_Error_Log" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "meal" "text",
    "list_of_med" "text"[],
    "reason" "text" DEFAULT '-'::"text",
    "resident_id" bigint,
    "user_id" "uuid",
    "CalendarDate" "date",
    "admin" boolean,
    "2CPicture" boolean,
    "3CPicture" boolean,
    "reply_nurseMark" "text"
);


ALTER TABLE "public"."A_Med_Error_Log" OWNER TO "postgres";


ALTER TABLE "public"."A_Med_Error_Log" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Med_Error_Log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Med_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "2C_completed_by" "uuid",
    "Created_Date" "date",
    "SecondCPictureUrl" "text",
    "meal" "text",
    "resident_id" bigint,
    "ThirdCPictureUrl" "text",
    "3C_Compleated_by" "uuid",
    "3C_time_stamps" timestamp with time zone,
    "medList_id_List" bigint[],
    "ArrangeMed_by" "uuid",
    "SecondCImgHash" "text",
    "ThirdCImgHash" "text",
    "task_id" bigint
);


ALTER TABLE "public"."A_Med_logs" OWNER TO "postgres";


COMMENT ON COLUMN "public"."A_Med_logs"."task_id" IS 'ถ้ามี';



ALTER TABLE "public"."A_Med_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Med_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Repeated_Task" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "task_id" bigint,
    "recurrenceType" "text",
    "recurrenceInterval" bigint,
    "start_Date" "date",
    "end_Date" "date",
    "startTme" time without time zone,
    "endTime" time without time zone,
    "timeBlock" "text",
    "daysOfWeek" "text"[],
    "recurNote" "text",
    "update_status" boolean DEFAULT false,
    "recurring_dates" smallint[],
    "sampleImageURL" "text",
    "must_complete_by_image" boolean
);


ALTER TABLE "public"."A_Repeated_Task" OWNER TO "postgres";


ALTER TABLE "public"."A_Repeated_Task" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Repeated_Task_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Task_History_Seen" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "old.title" "text",
    "new.title" "text",
    "old.description" "text",
    "new.description" "text",
    "old.link" "text",
    "new.link" "text",
    "relatedTaskId" bigint
);


ALTER TABLE "public"."A_Task_History_Seen" OWNER TO "postgres";


ALTER TABLE "public"."A_Task_History_Seen" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Task_History_Seen_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Task_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "task_id" bigint,
    "completed_by" "uuid",
    "Created_Date" "date",
    "status" "text",
    "Descript" "text",
    "Task_Repeat_Id" bigint
);


ALTER TABLE "public"."A_Task_logs" OWNER TO "postgres";


ALTER TABLE "public"."A_Task_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Task_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Task_logs_ver2" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "task_id" bigint,
    "completed_by" "uuid",
    "Created_Date" "date",
    "status" "text",
    "Descript" "text",
    "Task_Repeat_Id" bigint,
    "ExpectedDateTime" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "confirmImage" "text",
    "postpone_to" bigint,
    "postpone_from" bigint,
    "c_task_id" bigint,
    "line_group_id" "text",
    "post_id" bigint
);


ALTER TABLE "public"."A_Task_logs_ver2" OWNER TO "postgres";


COMMENT ON TABLE "public"."A_Task_logs_ver2" IS 'This is a duplicate of A_Task_logs';



ALTER TABLE "public"."A_Task_logs_ver2" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Task_logs_ver2_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Task_logs_ver2_n8n" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "task_id" bigint,
    "completed_by" "uuid",
    "Created_Date" "date",
    "status" "text",
    "Descript" "text",
    "Task_Repeat_Id" bigint,
    "ExpectedDateTime" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "confirmImage" "text",
    "postpone_to" bigint,
    "postpone_from" bigint
);


ALTER TABLE "public"."A_Task_logs_ver2_n8n" OWNER TO "postgres";


COMMENT ON TABLE "public"."A_Task_logs_ver2_n8n" IS 'This is a duplicate of A_Task_logs_ver2';



ALTER TABLE "public"."A_Task_logs_ver2_n8n" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Task_logs_ver2_n8n_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Task_with_Post" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "task_id" bigint,
    "post_id" bigint
);


ALTER TABLE "public"."A_Task_with_Post" OWNER TO "postgres";


ALTER TABLE "public"."A_Task_with_Post" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Task_with_Post_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."A_Tasks" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "resident_id" bigint,
    "creator_id" "uuid",
    "completed_by" "uuid",
    "due_date" timestamp with time zone,
    "nursinghome_id" bigint,
    "Subtask_of" bigint,
    "assign_to" "uuid",
    "taskType" "text" DEFAULT ''::"text" NOT NULL,
    "completed_at" timestamp with time zone,
    "calendar_id" bigint,
    "reaquire_image" boolean DEFAULT false,
    "sampleImageURL" "text",
    "form_url" "text",
    "mustCompleteByPost" boolean DEFAULT false
);


ALTER TABLE "public"."A_Tasks" OWNER TO "postgres";


ALTER TABLE "public"."A_Tasks" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."A_Tasks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."B_Ticket" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ticket_Title" "text",
    "ticket_Description" "text",
    "nursinghome_id" bigint,
    "created_by" "uuid",
    "assignee" "uuid"[],
    "source" "text",
    "follow_Up_Date" "date",
    "status" "text",
    "priority" boolean,
    "meeting_Agenda" boolean,
    "template_ticket_id" bigint,
    "med_list_id" bigint,
    "template_task_id" bigint[],
    "resident_id" bigint
);


ALTER TABLE "public"."B_Ticket" OWNER TO "postgres";


ALTER TABLE "public"."B_Ticket" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."B_Ticket_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."C_Tasks" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "resident_id" bigint,
    "creator_id" "uuid",
    "completed_by" "uuid",
    "due_date" timestamp with time zone,
    "nursinghome_id" bigint,
    "Subtask_of" bigint,
    "assign_to" "uuid",
    "taskType" "text" DEFAULT ''::"text" NOT NULL,
    "completed_at" timestamp with time zone,
    "calendar_id" bigint,
    "self_ticket_id" bigint,
    "process_id" bigint,
    "recurrenceType" "text" DEFAULT 'วัน'::"text",
    "recurrenceInterval" bigint DEFAULT '1'::bigint,
    "start_Date" "date",
    "end_Date" "date",
    "startTme" time without time zone,
    "endTime" time without time zone,
    "timeBlock" "text",
    "recurNote" "text"
);


ALTER TABLE "public"."C_Tasks" OWNER TO "postgres";


COMMENT ON TABLE "public"."C_Tasks" IS 'This is a duplicate of A_Tasks';



CREATE TABLE IF NOT EXISTS "public"."residents" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "i_Name_Surname" "text",
    "i_National_ID_num" "text",
    "i_DOB" "date",
    "i_gender" "text",
    "i_picture_url" "text",
    "m_past_history" "text",
    "m_dietary" "text",
    "m_fooddrug_allergy" "text",
    "s_zone" bigint,
    "s_bed" "text",
    "s_reason_being_here" "text",
    "s_contract_date" "date",
    "s_status" "text",
    "s_special_status" "text",
    "zone_text" "text",
    "underlying_disease_list" "text"[],
    "DTX/insulin" boolean DEFAULT false,
    "Report_Amount" bigint DEFAULT '2'::bigint,
    "Report_Scale_Day" bigint[],
    "Report_Scale_Night" bigint[],
    "medResponsible" "text" DEFAULT 'ญาติ'::"text" NOT NULL,
    "โรงพยาบาล" "text",
    "SocialSecuruty" "text",
    "is_processed" boolean DEFAULT false,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."residents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_info" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "full_name" "text",
    "nickname" "text",
    "photo_url" "text",
    "phone_number" "text",
    "prefix" "text",
    "nursinghome_id" bigint,
    "about_me" "text",
    "bank" "text",
    "bank_account" "text",
    "english_name" "text",
    "line_ID" "text",
    "DOB_staff" "date",
    "gender" "text",
    "underlying_disease_staff" "text",
    "education_degree" "text",
    "national_ID_staff" "text",
    "user_role" "public"."user_role",
    "boardSubscription" boolean DEFAULT true,
    "snooze" boolean DEFAULT false NOT NULL,
    "cancel_snooze" boolean DEFAULT false NOT NULL,
    "fcm_token" "text",
    "position" "text",
    "email" "text",
    "appVersion" "text",
    "buildNumber" "text",
    "packageName" "text",
    "platform" "text",
    "group" bigint
);


ALTER TABLE "public"."user_info" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."B_Ticket_view" WITH ("security_invoker"='on') AS
 WITH "latest_tasks" AS (
         SELECT "ct"."id",
            "ct"."created_at",
            "ct"."title",
            "ct"."description",
            "ct"."resident_id",
            "ct"."creator_id",
            "ct"."completed_by",
            "ct"."due_date",
            "ct"."nursinghome_id",
            "ct"."Subtask_of",
            "ct"."assign_to",
            "ct"."taskType",
            "ct"."completed_at",
            "ct"."calendar_id",
            "ct"."self_ticket_id",
            "ct"."process_id",
            "row_number"() OVER (PARTITION BY "ct"."self_ticket_id" ORDER BY "ct"."id" DESC) AS "rn"
           FROM "public"."C_Tasks" "ct"
        )
 SELECT "bt"."id" AS "ticket_id",
    "bt"."id",
    "bt"."created_at",
    "bt"."ticket_Title",
    "bt"."ticket_Description",
    "bt"."nursinghome_id",
    "bt"."created_by",
    "bt"."assignee",
    "bt"."source",
    "bt"."follow_Up_Date",
    "bt"."status",
    "bt"."priority",
    "bt"."meeting_Agenda",
    "bt"."template_ticket_id",
    "bt"."med_list_id",
    "bt"."template_task_id",
    "bt"."resident_id",
    "lt"."id" AS "task_id",
    "lt"."title",
    "lt"."description",
    "lt"."due_date",
    "lt"."completed_at",
    "lt"."process_id",
    "r"."i_Name_Surname" AS "resident_name",
    "u"."id" AS "creator_id",
    "u"."full_name" AS "creator_name",
    "u"."nickname" AS "creator_nickname"
   FROM ((("public"."B_Ticket" "bt"
     LEFT JOIN "latest_tasks" "lt" ON ((("bt"."id" = "lt"."self_ticket_id") AND ("lt"."rn" = 1))))
     LEFT JOIN "public"."residents" "r" ON (("bt"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "u" ON (("lt"."creator_id" = "u"."id")));


ALTER TABLE "public"."B_Ticket_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."C_Calendar" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Title" "text",
    "Description" "text",
    "Type" "text",
    "dateTime" timestamp with time zone,
    "nursinghome_id" bigint,
    "resident_id" bigint,
    "creator_id" "uuid",
    "isRequireNA" boolean,
    "NA_assign" "text",
    "assignNA" "uuid",
    "isNPO" boolean,
    "hospital" "text",
    "isRelativePaidIn" boolean,
    "relativePaidDate" timestamp with time zone,
    "isDocumentPrepared" boolean,
    "isPostOnBoardAfter" boolean,
    "url" "text"
);


ALTER TABLE "public"."C_Calendar" OWNER TO "postgres";


ALTER TABLE "public"."C_Calendar" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."C_Calendar_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."C_Calendar_with_Post" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "CalendarId" bigint,
    "PostId" bigint
);


ALTER TABLE "public"."C_Calendar_with_Post" OWNER TO "postgres";


ALTER TABLE "public"."C_Calendar_with_Post" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."C_Calendar_with_Post_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."C_Tasks" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."C_Tasks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Calendar_Subject" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "subject" "text",
    "color" "text"
);


ALTER TABLE "public"."Calendar_Subject" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clock_in_out_ver2" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "nursinghome_id" bigint,
    "supervisor_id" "uuid",
    "isAuto" boolean DEFAULT false NOT NULL,
    "Incharge" boolean,
    "zones" bigint[],
    "isSupport" boolean,
    "clock_in_timestamp" timestamp with time zone,
    "clock_out_timestamp" timestamp with time zone,
    "isChecked" boolean DEFAULT false,
    "duty_buyer" "uuid",
    "shift" "text",
    "selected_resident_id_list" bigint[],
    "selected_break_time" bigint[],
    "shift_survey" "text",
    "bug_survey" "text",
    "shift_score" bigint,
    "self_score" bigint
);


ALTER TABLE "public"."clock_in_out_ver2" OWNER TO "postgres";


COMMENT ON TABLE "public"."clock_in_out_ver2" IS 'This is a duplicate of Clock In Out';



COMMENT ON COLUMN "public"."clock_in_out_ver2"."shift" IS 'user ขึ้นเวรอะไร เวรเช้า หรือ เวรดึก';



ALTER TABLE "public"."clock_in_out_ver2" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Clock In Out_ver2_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Clock Special Record" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "type" "text",
    "nursinghome_id" bigint,
    "timestamp" timestamp with time zone DEFAULT "now"(),
    "supervisor_id" "uuid",
    "isAuto" boolean DEFAULT false NOT NULL,
    "Incharge" boolean,
    "zones" bigint[],
    "isAbsent" boolean DEFAULT false,
    "sick_evident" "text",
    "sick_reason" "text",
    "isSupport" boolean DEFAULT false,
    "Additional" bigint DEFAULT '0'::bigint,
    "additional_reason" "text",
    "Deduction" double precision DEFAULT '0'::double precision,
    "deduction_reason" "text",
    "isChecked" boolean DEFAULT false
);


ALTER TABLE "public"."Clock Special Record" OWNER TO "postgres";


COMMENT ON TABLE "public"."Clock Special Record" IS 'This is a duplicate of Clock In Out';



COMMENT ON COLUMN "public"."Clock Special Record"."type" IS 'in,out';



COMMENT ON COLUMN "public"."Clock Special Record"."sick_evident" IS 'สำหรับใบลาป่วย';



ALTER TABLE "public"."Clock Special Record" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Clock Special Record_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."CommentPost" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "comment" "text" NOT NULL,
    "user_id" "uuid",
    "Post_id" bigint
);


ALTER TABLE "public"."CommentPost" OWNER TO "postgres";


ALTER TABLE "public"."CommentPost" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."CommentPost_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."DD_Record_Clock" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "aproover_id" "uuid",
    "calendar_appointment_id" bigint,
    "calendar_bill_id" bigint,
    "isChecked" boolean DEFAULT false
);


ALTER TABLE "public"."DD_Record_Clock" OWNER TO "postgres";


ALTER TABLE "public"."DD_Record_Clock" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."DD_Record_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Doc_Bowel_Movement" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "BristolScore" bigint,
    "Amount" bigint,
    "nursinghome_id" bigint,
    "user_id" "uuid",
    "latest_Update_at" timestamp with time zone,
    "latest_Update_by" "uuid",
    "task_log_id" bigint
);


ALTER TABLE "public"."Doc_Bowel_Movement" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."Doc_Bowel_Movement_View" WITH ("security_invoker"='on') AS
 SELECT "dbm"."id",
    "dbm"."created_at",
    "dbm"."resident_id",
    "dbm"."nursinghome_id",
    "dbm"."user_id",
    "ui"."nickname" AS "user_nickname",
    "dbm"."BristolScore",
        CASE
            WHEN ("dbm"."BristolScore" = 1) THEN 'ก้อนแข็งคล้ายขี้แพะ'::"text"
            WHEN ("dbm"."BristolScore" = 2) THEN 'ก้อนยาวขรุขระมาก'::"text"
            WHEN ("dbm"."BristolScore" = 3) THEN 'ก้อนยาว ผิวจะมีรอยแยกเล็กน้อย'::"text"
            WHEN ("dbm"."BristolScore" = 4) THEN 'ก้อนยาวผิวเรียบคล้ายกล้วยหอม'::"text"
            WHEN ("dbm"."BristolScore" = 5) THEN 'ก้อนแตกๆ แต่ยังเป็นชิ้นอยู่'::"text"
            WHEN ("dbm"."BristolScore" = 6) THEN 'อุจจาระเป็นแบบกึ่งแข็งกึ่งเหลว'::"text"
            WHEN ("dbm"."BristolScore" = 7) THEN 'อุจจาระเหลวเป็นน้ำ'::"text"
            ELSE 'ไม่ทราบประเภท'::"text"
        END AS "StoolDescription",
    "dbm"."Amount",
        CASE
            WHEN ("dbm"."Amount" = 1) THEN 'กะปริดกะปรอย'::"text"
            WHEN ("dbm"."Amount" = 2) THEN 'น้อย'::"text"
            WHEN ("dbm"."Amount" = 3) THEN 'ปานกลาง'::"text"
            WHEN ("dbm"."Amount" = 4) THEN 'มาก'::"text"
            ELSE 'ไม่ทราบจำนวน'::"text"
        END AS "AmountDescription",
        CASE
            WHEN ("dbm"."BristolScore" = 1) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/azrejqixea7z/S1.png'::"text"
            WHEN ("dbm"."BristolScore" = 2) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/45fsvzxrq13q/S2.png'::"text"
            WHEN ("dbm"."BristolScore" = 3) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/nnim5iphtls9/S3.png'::"text"
            WHEN ("dbm"."BristolScore" = 4) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/faqxbtokj9k1/S4.png'::"text"
            WHEN ("dbm"."BristolScore" = 5) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/r59nqx57yn0v/S5.png'::"text"
            WHEN ("dbm"."BristolScore" = 6) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/kho2u6bzhdmw/S6.png'::"text"
            WHEN ("dbm"."BristolScore" = 7) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/4l152ny84mpq/S7.png'::"text"
            ELSE NULL::"text"
        END AS "BristolScoreImage",
        CASE
            WHEN ("dbm"."Amount" = 1) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/mslfatr6b6jy/XS_1.png'::"text"
            WHEN ("dbm"."Amount" = 2) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/uaecikyo3lwm/S_2.png'::"text"
            WHEN ("dbm"."Amount" = 3) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/7gur7x9241ht/M_3.png'::"text"
            WHEN ("dbm"."Amount" = 4) THEN 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/oa3azvhqvdtm/L_4.png'::"text"
            ELSE NULL::"text"
        END AS "AmountImage",
    "dbm"."latest_Update_at",
    "dbm"."latest_Update_by",
    "dbm"."task_log_id",
    "date"("dbm"."created_at") AS "created_date"
   FROM ("public"."Doc_Bowel_Movement" "dbm"
     LEFT JOIN "public"."user_info" "ui" ON (("dbm"."user_id" = "ui"."id")));


ALTER TABLE "public"."Doc_Bowel_Movement_View" OWNER TO "postgres";


ALTER TABLE "public"."Doc_Bowel_Movement" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Doc_Bowel_Movement_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Duty_Transaction_Clock" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_1" "uuid",
    "transactionType" "text",
    "user_2" "uuid",
    "price" bigint,
    "purchasingStatus" "text",
    "date" timestamp with time zone,
    "shift" "text",
    "isClockIn" boolean DEFAULT false
);


ALTER TABLE "public"."Duty_Transaction_Clock" OWNER TO "postgres";


ALTER TABLE "public"."Duty_Transaction_Clock" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Duty_Transaction_Clock_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."F_timeBlock" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "time" "text",
    "nursinghome_id" bigint
);


ALTER TABLE "public"."F_timeBlock" OWNER TO "postgres";


ALTER TABLE "public"."F_timeBlock" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."F_timeBlock_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Inbox" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "desc" "text",
    "user_id" "uuid",
    "post_id" bigint
);


ALTER TABLE "public"."Inbox" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."med_DB" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "brand_name" "text",
    "generic_name" "text",
    "str" "text",
    "route" "text",
    "unit" "text",
    "info" "text",
    "group" "text",
    "pillpic_url" "text",
    "Front-Foiled" "text",
    "Back-Foiled" "text",
    "Front-Nude" "text",
    "Back-Nude" "text"
);


ALTER TABLE "public"."med_DB" OWNER TO "postgres";


ALTER TABLE "public"."med_DB" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Med_DB_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Medication Error Rate" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "total_dose" bigint,
    "total_error" bigint
);


ALTER TABLE "public"."Medication Error Rate" OWNER TO "postgres";


ALTER TABLE "public"."Medication Error Rate" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Medication Error Rate_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."New_Manual" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "created_by" "uuid",
    "resident_id" bigint,
    "refered_post_id" bigint,
    "type" "text",
    "modified_by" "uuid",
    "last_modified_at" timestamp with time zone
);


ALTER TABLE "public"."New_Manual" OWNER TO "postgres";


ALTER TABLE "public"."New_Manual" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."New_Manual_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."Inbox" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Notification_Center_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Point_Transaction" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "point_change" integer,
    "transaction_type" "text",
    "DateClaim" "date"
);


ALTER TABLE "public"."Point_Transaction" OWNER TO "postgres";


ALTER TABLE "public"."Point_Transaction" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Point_Transaction_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Post" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "vitalSign_id" bigint,
    "Text" "text",
    "youtubeUrl" "text",
    "imgUrl" "text",
    "nursinghome_id" bigint,
    "tagged_user" "uuid"[],
    "Tag_Topics" "text"[],
    "multi_img_url" "text"[],
    "user_group_edit" "text"[],
    "user_group_id_edit" "text"[],
    "last_modified_at" timestamp with time zone,
    "visible_to_relative" boolean,
    "reply_to" bigint,
    "DD_id" bigint,
    "title" "text",
    "qa_id" bigint
);


ALTER TABLE "public"."Post" OWNER TO "postgres";


COMMENT ON COLUMN "public"."Post"."title" IS 'เพื่อให้ user มองแวบเดียว แล้วเข้าใจ context';



CREATE TABLE IF NOT EXISTS "public"."Post_Quest_Accept" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "post_id" bigint,
    "user_id" "uuid"
);


ALTER TABLE "public"."Post_Quest_Accept" OWNER TO "postgres";


ALTER TABLE "public"."Post_Quest_Accept" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_Quest_Accept_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Post_Resident_id" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Post_id" bigint,
    "resident_id" bigint NOT NULL
);


ALTER TABLE "public"."Post_Resident_id" OWNER TO "postgres";


ALTER TABLE "public"."Post_Resident_id" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_Resident_id_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Post_Tags" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Post_id" bigint,
    "Tag_id" bigint
);


ALTER TABLE "public"."Post_Tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TagsLabel" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "tagName" "text",
    "Importent" boolean DEFAULT false NOT NULL,
    "tab" "text"
);


ALTER TABLE "public"."TagsLabel" OWNER TO "postgres";


ALTER TABLE "public"."TagsLabel" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_Tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."Post_Tags" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_Tags_id_seq1"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."Post" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Post_likes" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "Post_id" bigint,
    "Comment_id" bigint
);


ALTER TABLE "public"."Post_likes" OWNER TO "postgres";


ALTER TABLE "public"."Post_likes" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Post_likes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."QATable" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "question" "text",
    "choiceA" "text",
    "choiceB" "text",
    "choiceC" "text",
    "answer" "text"
);


ALTER TABLE "public"."QATable" OWNER TO "postgres";


ALTER TABLE "public"."QATable" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."QATable_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Relation_TagTopic_UserGroup" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tagTopic" bigint,
    "userGroup" bigint
);


ALTER TABLE "public"."Relation_TagTopic_UserGroup" OWNER TO "postgres";


ALTER TABLE "public"."Relation_TagTopic_UserGroup" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Relation_TagTopic_UserGroup_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."relatives" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "r_name_surname" "text",
    "r_phone" "text",
    "r_detail" "text",
    "key_person" boolean DEFAULT false,
    "r_nickname" "text",
    "lineUserId" "text"
);


ALTER TABLE "public"."relatives" OWNER TO "postgres";


ALTER TABLE "public"."relatives" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Relatives_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Report_Choice" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Choice" "text",
    "Scale" smallint,
    "Subject" bigint,
    "represent_url" "text"
);


ALTER TABLE "public"."Report_Choice" OWNER TO "postgres";


ALTER TABLE "public"."Report_Choice" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Report_Choice_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Report_Subject" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Subject" "text",
    "Description" "text",
    "nursinghome_id" bigint
);


ALTER TABLE "public"."Report_Subject" OWNER TO "postgres";


ALTER TABLE "public"."Report_Subject" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Report_Subject_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."resident_caution_manual" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "text" "text",
    "user_id" "uuid",
    "modified_at" timestamp with time zone,
    "active" boolean DEFAULT true,
    "type" "text",
    "index" bigint,
    "priority" "text"
);


ALTER TABLE "public"."resident_caution_manual" OWNER TO "postgres";


ALTER TABLE "public"."resident_caution_manual" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Resident_Caution_Manual_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Resident_Report_Relation" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "subject_id" bigint,
    "shift" "text"
);


ALTER TABLE "public"."Resident_Report_Relation" OWNER TO "postgres";


ALTER TABLE "public"."Resident_Report_Relation" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Resident_Report_Relation_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Resident_Template_Gen_Report" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "template_D" "text" DEFAULT '- อื่นๆ : '::"text" NOT NULL,
    "template_N" "text" DEFAULT '- อื่นๆ : '::"text" NOT NULL
);


ALTER TABLE "public"."Resident_Template_Gen_Report" OWNER TO "postgres";


ALTER TABLE "public"."Resident_Template_Gen_Report" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Resident_Template_Gen_Report_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."SOAPNote" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "Subjective" "text",
    "Objective" "text",
    "Assessment" "text",
    "Plan" "text",
    "user_id" "uuid",
    "resident_id" bigint,
    "time" "text",
    "date" timestamp with time zone,
    "type" "text",
    "modified_at" timestamp with time zone,
    "descriptive_Note" "text",
    "ai_summary" "text",
    "automation_status" "text",
    "progression_2_times" "text",
    "progression_7_days" "text"
);


ALTER TABLE "public"."SOAPNote" OWNER TO "postgres";


COMMENT ON COLUMN "public"."SOAPNote"."descriptive_Note" IS 'Such as nurse note';



ALTER TABLE "public"."SOAPNote" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."SOAPNote_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Scale_Report_Log" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vital_sign_id" bigint,
    "Subject_id" bigint,
    "Choice_id" bigint,
    "Relation_id" bigint,
    "resident_id" bigint,
    "index" bigint,
    "report_description" "text"
);


ALTER TABLE "public"."Scale_Report_Log" OWNER TO "postgres";


ALTER TABLE "public"."Scale_Report_Log" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Scale_Report_Log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."Calendar_Subject" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."SubjectCalendarType_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Task_Type" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "label" "text",
    "description" "text"
);


ALTER TABLE "public"."Task_Type" OWNER TO "postgres";


ALTER TABLE "public"."Task_Type" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Task_Type_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Template_Tasks" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "resident_id" bigint,
    "creator_id" "uuid",
    "completed_by" "uuid",
    "due_date" timestamp with time zone,
    "nursinghome_id" bigint,
    "Subtask_of" bigint,
    "assign_to" "uuid",
    "taskType" "text" DEFAULT ''::"text" NOT NULL,
    "completed_at" timestamp with time zone,
    "calendar_id" bigint,
    "ass_template_Ticket" bigint
);


ALTER TABLE "public"."Template_Tasks" OWNER TO "postgres";


COMMENT ON TABLE "public"."Template_Tasks" IS 'This is a duplicate of C_Tasks';



CREATE TABLE IF NOT EXISTS "public"."Template_Ticket" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ticket_Title" "text",
    "ticket_Description" "text",
    "nursinghome_id" bigint,
    "created_by" "uuid",
    "assignee" "uuid"[],
    "source" "text",
    "follow_Up_Date" "date",
    "status" "text",
    "priority" boolean,
    "meeting_Agenda" boolean DEFAULT false
);


ALTER TABLE "public"."Template_Ticket" OWNER TO "postgres";


COMMENT ON TABLE "public"."Template_Ticket" IS 'This is a duplicate of B_Ticket';



ALTER TABLE "public"."Template_Ticket" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Template_Ticket_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."Template_Tasks" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Ticket_Template_Tasks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."Workday" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "WD" bigint,
    "nursinghome_id" bigint,
    "month" bigint,
    "year" bigint,
    "monthThai" "text"
);


ALTER TABLE "public"."Workday" OWNER TO "postgres";


COMMENT ON TABLE "public"."Workday" IS 'กำหนด workday ของ NA ในแต่ละเดือน';



ALTER TABLE "public"."Workday" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Workday_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."a_med_error_log_view" WITH ("security_invoker"='on') AS
 SELECT "log"."id",
    "log"."created_at",
    "log"."meal",
    "log"."list_of_med",
    "log"."reason",
    "log"."resident_id",
    "log"."CalendarDate" AS "created_at_date",
    "log"."admin",
    "log"."2CPicture",
    "log"."3CPicture",
    "log"."reply_nurseMark",
    "usr"."id" AS "user_id",
    "usr"."nickname" AS "user_nickname"
   FROM ("public"."A_Med_Error_Log" "log"
     LEFT JOIN "public"."user_info" "usr" ON (("log"."user_id" = "usr"."id")));


ALTER TABLE "public"."a_med_error_log_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."abnormal_value_Dashboard" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "abnormal_value" "text",
    "nursinghome_id" bigint,
    "seen_user_id" "uuid",
    "status" "text"
);


ALTER TABLE "public"."abnormal_value_Dashboard" OWNER TO "postgres";


ALTER TABLE "public"."abnormal_value_Dashboard" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."abnormal_value_Dashboard_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."abnormal_value_and_Ticket_Calendar" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "abnormal_value_id" bigint,
    "calendar_id" bigint
);


ALTER TABLE "public"."abnormal_value_and_Ticket_Calendar" OWNER TO "postgres";


ALTER TABLE "public"."abnormal_value_and_Ticket_Calendar" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."abnormal_value_and_Ticket_Calendar_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."nursinghomes" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text",
    "report_times" smallint,
    "pic_url" "text",
    "app_version" bigint
);


ALTER TABLE "public"."nursinghomes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."abnormal_value_dashboard_view" WITH ("security_invoker"='on') AS
 SELECT "avd"."id",
    "avd"."created_at",
    "avd"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "avd"."abnormal_value",
    "r"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "avd"."status",
    "atc"."calendar_id" AS "ticket_calendar_id"
   FROM ((("public"."abnormal_value_Dashboard" "avd"
     LEFT JOIN "public"."residents" "r" ON (("avd"."resident_id" = "r"."id")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("r"."nursinghome_id" = "nh"."id")))
     LEFT JOIN "public"."abnormal_value_and_Ticket_Calendar" "atc" ON (("avd"."id" = "atc"."abnormal_value_id")));


ALTER TABLE "public"."abnormal_value_dashboard_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nursinghome_zone" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "zone" "text"
);


ALTER TABLE "public"."nursinghome_zone" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."programs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "name" "text",
    "program_pastel_color" "text"
);


ALTER TABLE "public"."programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."resident_programs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "program_id" bigint
);


ALTER TABLE "public"."resident_programs" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."api_resident_details_view" WITH ("security_invoker"='on') AS
 SELECT COALESCE("r"."id", ('-1'::integer)::bigint) AS "resident_id",
    COALESCE(NULLIF("r"."i_Name_Surname", ''::"text"), '-'::"text") AS "i_Name_Surname",
    COALESCE(NULLIF("r"."i_gender", ''::"text"), '-'::"text") AS "i_gender",
    COALESCE("to_char"(("r"."i_DOB")::timestamp with time zone, 'DD/MM/YYYY'::"text"), '-'::"text") AS "i_DOB",
    COALESCE((EXTRACT(year FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."i_DOB")::timestamp with time zone)))::"text", '-'::"text") AS "age",
    COALESCE(NULLIF("r"."i_National_ID_num", ''::"text"), '-'::"text") AS "i_National_ID_num",
    COALESCE(NULLIF("r"."m_dietary", ''::"text"), '-'::"text") AS "m_dietary",
    COALESCE(NULLIF("r"."m_fooddrug_allergy", ''::"text"), '-'::"text") AS "m_fooddrug_allergy",
    COALESCE(NULLIF("r"."s_status", ''::"text"), '-'::"text") AS "s_status",
    "r"."nursinghome_id",
    COALESCE(( SELECT "nursinghomes"."name"
           FROM "public"."nursinghomes"
          WHERE ("nursinghomes"."id" = "r"."nursinghome_id")), '-'::"text") AS "nursinghome_name",
    COALESCE(( SELECT "nursinghome_zone"."zone"
           FROM "public"."nursinghome_zone"
          WHERE ("nursinghome_zone"."id" = "r"."s_zone")), '-'::"text") AS "s_zone",
    COALESCE("to_char"(("r"."s_contract_date")::timestamp with time zone, 'DD/MM/YYYY'::"text"), '-'::"text") AS "s_contract_date",
    COALESCE(NULLIF("array_to_string"("r"."underlying_disease_list", ' / '::"text"), ''::"text"), '-'::"text") AS "underlying_diseases_list",
    COALESCE(( SELECT "string_agg"("p"."name", ' / '::"text" ORDER BY "p"."id") AS "string_agg"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")), '-'::"text") AS "programs_list",
    COALESCE(NULLIF("r"."m_past_history", ''::"text"), '-'::"text") AS "m_past_history"
   FROM "public"."residents" "r";


ALTER TABLE "public"."api_resident_details_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vitalSign" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "DTX" bigint,
    "Defecation" boolean,
    "Input" bigint,
    "O2" bigint,
    "PR" bigint,
    "Temp" numeric,
    "constipation" numeric,
    "dBP" bigint,
    "generalReport" "text",
    "napkin" bigint,
    "output" "text",
    "resident_id" bigint,
    "sBP" bigint,
    "user_id" "uuid",
    "shift" "text",
    "Insulin" bigint,
    "isFullReport" boolean,
    "RR" bigint,
    "Sent" boolean DEFAULT false,
    "nursinghome_id" bigint
);


ALTER TABLE "public"."vitalSign" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."api_vitalsign" WITH ("security_invoker"='on') AS
 SELECT COALESCE(("vs"."created_at")::"text", '-'::"text") AS "created_at",
    COALESCE(NULLIF("vs"."shift", ''::"text"), '-'::"text") AS "shift",
    COALESCE("vs"."Temp", (0)::numeric) AS "Temp",
    COALESCE("vs"."sBP", (0)::bigint) AS "sBP",
    COALESCE("vs"."dBP", (0)::bigint) AS "dBP",
    COALESCE("vs"."PR", (0)::bigint) AS "PR",
    COALESCE("vs"."RR", (0)::bigint) AS "RR",
    COALESCE("vs"."O2", (0)::bigint) AS "O2",
    COALESCE("vs"."constipation", (0)::numeric) AS "constipation",
    COALESCE("vs"."DTX", (0)::bigint) AS "DTX",
    COALESCE("vs"."Insulin", (0)::bigint) AS "Insulin",
    COALESCE("vs"."Input", (0)::bigint) AS "Input",
    COALESCE(NULLIF("vs"."output", ''::"text"), '-'::"text") AS "output",
    COALESCE("replace"(NULLIF("vs"."generalReport", ''::"text"), '
'::"text", '/'::"text"), '-'::"text") AS "generalreport",
    COALESCE(NULLIF("ui"."nickname", ''::"text"), '-'::"text") AS "user_nickname",
    COALESCE(("vs"."resident_id")::"text", '-'::"text") AS "resident_id"
   FROM ("public"."vitalSign" "vs"
     LEFT JOIN "public"."user_info" "ui" ON (("vs"."user_id" = "ui"."id")));


ALTER TABLE "public"."api_vitalsign" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clock_break_time_nursinghome" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "breakTime" "text",
    "nursinghome_id" bigint,
    "quota" bigint,
    "shift" "text",
    "break_name" "text",
    "index" bigint
);


ALTER TABLE "public"."clock_break_time_nursinghome" OWNER TO "postgres";


COMMENT ON TABLE "public"."clock_break_time_nursinghome" IS 'เวลาพักของพนักงานใน nursinghome นั้นไ โดยแบ่งตามช่วงเวลา';



ALTER TABLE "public"."clock_break_time_nursinghome" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."break_time_nursinghome_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."byDate_Doc_Bowel_Movement_Summary_View" WITH ("security_invoker"='on') AS
 SELECT "Doc_Bowel_Movement_View"."created_date",
    "Doc_Bowel_Movement_View"."nursinghome_id",
    "Doc_Bowel_Movement_View"."resident_id",
    "count"(*) AS "daily_count"
   FROM "public"."Doc_Bowel_Movement_View"
  GROUP BY "Doc_Bowel_Movement_View"."created_date", "Doc_Bowel_Movement_View"."nursinghome_id", "Doc_Bowel_Movement_View"."resident_id"
  ORDER BY "Doc_Bowel_Movement_View"."created_date", "Doc_Bowel_Movement_View"."nursinghome_id", "Doc_Bowel_Movement_View"."resident_id";


ALTER TABLE "public"."byDate_Doc_Bowel_Movement_Summary_View" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."bydate_c_calendar_summary_view" WITH ("security_invoker"='on') AS
 WITH "aggregated_data" AS (
         SELECT ("C_Calendar"."dateTime")::"date" AS "event_date",
            "C_Calendar"."nursinghome_id",
            "count"(*) AS "daily_count",
            "array_agg"(DISTINCT "C_Calendar"."resident_id") FILTER (WHERE ("C_Calendar"."resident_id" IS NOT NULL)) AS "resident_list",
            "array_agg"(DISTINCT "C_Calendar"."Type") FILTER (WHERE ("C_Calendar"."Type" IS NOT NULL)) AS "type_list"
           FROM "public"."C_Calendar"
          GROUP BY (("C_Calendar"."dateTime")::"date"), "C_Calendar"."nursinghome_id"
        )
 SELECT "aggregated_data"."event_date",
    "aggregated_data"."nursinghome_id",
    "aggregated_data"."daily_count",
    "aggregated_data"."resident_list",
    "aggregated_data"."type_list",
    "row_number"() OVER (PARTITION BY "aggregated_data"."nursinghome_id", ("date_trunc"('month'::"text", ("aggregated_data"."event_date")::timestamp with time zone)) ORDER BY "aggregated_data"."event_date") AS "monthly_index"
   FROM "aggregated_data"
  ORDER BY "aggregated_data"."event_date", "aggregated_data"."nursinghome_id";


ALTER TABLE "public"."bydate_c_calendar_summary_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_tasks_only_without_repeat" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "task_id",
    "t"."created_at",
    "t"."title",
    "t"."description",
    "t"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_zone" AS "zone_id",
    "t"."creator_id",
    "t"."completed_by",
    "t"."due_date",
    ("date_trunc"('day'::"text", "t"."due_date"))::"date" AS "due_date_only",
    "t"."completed_at",
    "ui"."nickname" AS "log_done_nickname",
    "t"."nursinghome_id",
    "t"."Subtask_of",
    "t"."assign_to",
    "t"."taskType",
    COALESCE("r"."s_status", 'zone'::"text") AS "resident_status",
    COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
        CASE
            WHEN ("min"("rt"."end_Date") IS NOT NULL) THEN 'inactive'::"text"
            ELSE 'active'::"text"
        END AS "status",
    "ui_assign"."nickname" AS "assign_to_nickname",
        CASE
            WHEN ("t"."completed_by" IS NOT NULL) THEN true
            ELSE false
        END AS "is_completed",
    "concat"('(', "ui_assign"."nickname", ') ', "ui_assign"."prefix", ' ', "ui_assign"."full_name") AS "assign_to_concatname",
    "t"."calendar_id",
    "t"."self_ticket_id",
    "t"."process_id",
    "log"."id" AS "log_id"
   FROM ((((("public"."C_Tasks" "t"
     LEFT JOIN "public"."residents" "r" ON (("t"."resident_id" = "r"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "rt" ON (("t"."id" = "rt"."task_id")))
     LEFT JOIN "public"."user_info" "ui" ON (("t"."completed_by" = "ui"."id")))
     LEFT JOIN "public"."user_info" "ui_assign" ON (("t"."assign_to" = "ui_assign"."id")))
     LEFT JOIN "public"."A_Task_logs_ver2" "log" ON (("t"."id" = "log"."task_id")))
  GROUP BY "t"."id", "t"."created_at", "t"."title", "t"."description", "t"."resident_id", "r"."i_Name_Surname", "r"."s_zone", "t"."creator_id", "t"."completed_by", "t"."due_date", "t"."completed_at", "ui"."nickname", "t"."nursinghome_id", "t"."Subtask_of", "t"."assign_to", "t"."taskType", "r"."s_status", "r"."s_special_status", "ui_assign"."nickname", "ui_assign"."prefix", "ui_assign"."full_name", "t"."calendar_id", "t"."self_ticket_id", "t"."process_id", "log"."id";


ALTER TABLE "public"."v_tasks_only_without_repeat" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."cCalendarCounts" WITH ("security_invoker"='on') AS
 SELECT "concat"(COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), '_', COALESCE("cc"."nursinghome_id", "t"."nursinghome_id")) AS "id",
    COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only") AS "calendarDate",
    COALESCE("cc"."nursinghome_id", "t"."nursinghome_id") AS "nursinghomeId",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Appointment'::"text") THEN 1
            ELSE NULL::integer
        END) AS "appointmentCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Treatment'::"text") THEN 1
            ELSE NULL::integer
        END) AS "treatmentCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Bill'::"text") THEN 1
            ELSE NULL::integer
        END) AS "billCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Ticket'::"text") THEN 1
            ELSE NULL::integer
        END) AS "ticketCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Incident'::"text") THEN 1
            ELSE NULL::integer
        END) AS "incidentCount",
    "count"(DISTINCT "t"."task_id") AS "TaskCount",
    "array_agg"(DISTINCT COALESCE("cc"."resident_id", "t"."resident_id")) AS "residentIdList"
   FROM ("public"."C_Calendar" "cc"
     FULL JOIN "public"."v_tasks_only_without_repeat" "t" ON (((("date_trunc"('day'::"text", "cc"."dateTime"))::"date" = "t"."due_date_only") AND ("cc"."nursinghome_id" = "t"."nursinghome_id"))))
  GROUP BY COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), COALESCE("cc"."nursinghome_id", "t"."nursinghome_id")
  ORDER BY COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), COALESCE("cc"."nursinghome_id", "t"."nursinghome_id");


ALTER TABLE "public"."cCalendarCounts" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."cCalendarCounts2" WITH ("security_invoker"='on') AS
 SELECT "concat"(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", '_', "cc"."nursinghome_id", '_', COALESCE("cc"."resident_id", (0)::bigint), '_', "cs"."subject") AS "id",
    ("date_trunc"('day'::"text", "cc"."dateTime"))::"date" AS "calendarDate",
    "cc"."nursinghome_id" AS "nursinghomeId",
    COALESCE("cc"."resident_id", (0)::bigint) AS "residentId",
    "cs"."subject" AS "type",
    "cs"."color",
    1 AS "typeCount"
   FROM ("public"."C_Calendar" "cc"
     JOIN "public"."Calendar_Subject" "cs" ON (("cc"."Type" = "cs"."subject")))
  ORDER BY (("date_trunc"('day'::"text", "cc"."dateTime"))::"date"), "cc"."nursinghome_id", COALESCE("cc"."resident_id", (0)::bigint), "cs"."subject";


ALTER TABLE "public"."cCalendarCounts2" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."cCalendarWithDate" WITH ("security_invoker"='on') AS
 SELECT "cc"."id",
    "cc"."created_at",
    "cc"."Title",
    "cc"."Description",
    "cc"."Type",
    "cc"."dateTime",
    "cc"."nursinghome_id",
    "cc"."resident_id",
    "cc"."creator_id",
    "concat"("ui"."prefix", ' ', "ui"."full_name", ' (', "ui"."nickname", ')') AS "created_by",
    "cc"."isRequireNA",
    "cc"."NA_assign",
    "cc"."assignNA",
    "cc"."isNPO",
    "cc"."hospital",
    "cc"."isRelativePaidIn",
    "cc"."relativePaidDate",
    "cc"."isDocumentPrepared",
    "cc"."isPostOnBoardAfter",
    "ddr"."id" AS "DD_id",
    "ddr"."user_id" AS "dd_user_id",
    "dd_ui"."full_name" AS "dd_user_fullname",
    "dd_ui"."nickname" AS "dd_user_nickname",
    "dd_ui"."photo_url" AS "dd_user_photo",
    "dd_bill"."user_id" AS "dd_bill_user_id",
    "dd_bill_ui"."full_name" AS "dd_bill_user_fullname",
    "dd_bill_ui"."nickname" AS "dd_bill_user_nickname",
    "dd_bill_ui"."photo_url" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "cc"."dateTime"))::"date" AS "date",
    EXTRACT(month FROM "cc"."dateTime") AS "month",
    EXTRACT(year FROM "cc"."dateTime") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    "cs"."color" AS "type_color",
    "cs"."subject" AS "type_order",
    'C_Calendar'::"text" AS "whereTheRowComeFrom",
    "cc"."id" AS "source_table_id",
    NULL::"text"[] AS "image_urls"
   FROM ((((((("public"."C_Calendar" "cc"
     LEFT JOIN "public"."residents" "r" ON (("cc"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("cc"."creator_id" = "ui"."id")))
     LEFT JOIN "public"."Calendar_Subject" "cs" ON (("cc"."Type" = "cs"."subject")))
     LEFT JOIN "public"."DD_Record_Clock" "ddr" ON (("cc"."id" = "ddr"."calendar_appointment_id")))
     LEFT JOIN "public"."user_info" "dd_ui" ON (("ddr"."user_id" = "dd_ui"."id")))
     LEFT JOIN "public"."DD_Record_Clock" "dd_bill" ON (("cc"."id" = "dd_bill"."calendar_bill_id")))
     LEFT JOIN "public"."user_info" "dd_bill_ui" ON (("dd_bill"."user_id" = "dd_bill_ui"."id")))
UNION ALL
 SELECT "sn"."id",
    "sn"."created_at",
    "sn"."type" AS "Title",
    "concat_ws"('
'::"text",
        CASE
            WHEN (("sn"."Subjective" IS NOT NULL) AND ("sn"."Subjective" <> ''::"text")) THEN "sn"."Subjective"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("sn"."Objective" IS NOT NULL) AND ("sn"."Objective" <> ''::"text")) THEN "sn"."Objective"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("sn"."Assessment" IS NOT NULL) AND ("sn"."Assessment" <> ''::"text")) THEN "sn"."Assessment"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("sn"."Plan" IS NOT NULL) AND ("sn"."Plan" <> ''::"text")) THEN "sn"."Plan"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("sn"."descriptive_Note" IS NOT NULL) AND ("sn"."descriptive_Note" <> ''::"text")) THEN "sn"."descriptive_Note"
            ELSE NULL::"text"
        END) AS "Description",
    "sn"."type" AS "Type",
    "sn"."created_at" AS "dateTime",
    "r"."nursinghome_id",
    "sn"."resident_id",
    "sn"."user_id" AS "creator_id",
    "concat"("ui"."prefix", ' ', "ui"."full_name", ' (', "ui"."nickname", ')') AS "created_by",
    NULL::boolean AS "isRequireNA",
    NULL::"text" AS "NA_assign",
    NULL::"uuid" AS "assignNA",
    NULL::boolean AS "isNPO",
    NULL::"text" AS "hospital",
    NULL::boolean AS "isRelativePaidIn",
    NULL::timestamp with time zone AS "relativePaidDate",
    NULL::boolean AS "isDocumentPrepared",
    NULL::boolean AS "isPostOnBoardAfter",
    NULL::bigint AS "DD_id",
    NULL::"uuid" AS "dd_user_id",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    NULL::"uuid" AS "dd_bill_user_id",
    NULL::"text" AS "dd_bill_user_fullname",
    NULL::"text" AS "dd_bill_user_nickname",
    NULL::"text" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "sn"."created_at"))::"date" AS "date",
    EXTRACT(month FROM "sn"."created_at") AS "month",
    EXTRACT(year FROM "sn"."created_at") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    NULL::"text" AS "type_color",
    "sn"."type" AS "type_order",
    'SOAPNote'::"text" AS "whereTheRowComeFrom",
    "sn"."id" AS "source_table_id",
    NULL::"text"[] AS "image_urls"
   FROM (("public"."SOAPNote" "sn"
     LEFT JOIN "public"."residents" "r" ON (("sn"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("sn"."user_id" = "ui"."id")))
UNION ALL
 SELECT "p"."id",
    "p"."created_at",
    'Post'::"text" AS "Title",
    NULLIF("p"."Text", ''::"text") AS "Description",
        CASE
            WHEN ("p"."Tag_Topics" IS NOT NULL) THEN "array_to_string"("p"."Tag_Topics", ', '::"text")
            ELSE 'Post'::"text"
        END AS "Type",
    "p"."created_at" AS "dateTime",
    "p"."nursinghome_id",
    "pr"."resident_id",
    "p"."user_id" AS "creator_id",
    "concat"(COALESCE("ui"."prefix", ''::"text"), ' ', COALESCE("ui"."full_name", ''::"text"), ' (', COALESCE("ui"."nickname", ''::"text"), ')') AS "created_by",
    NULL::boolean AS "isRequireNA",
    NULL::"text" AS "NA_assign",
    NULL::"uuid" AS "assignNA",
    NULL::boolean AS "isNPO",
    NULL::"text" AS "hospital",
    NULL::boolean AS "isRelativePaidIn",
    NULL::timestamp with time zone AS "relativePaidDate",
    NULL::boolean AS "isDocumentPrepared",
    NULL::boolean AS "isPostOnBoardAfter",
    NULL::bigint AS "DD_id",
    NULL::"uuid" AS "dd_user_id",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    NULL::"uuid" AS "dd_bill_user_id",
    NULL::"text" AS "dd_bill_user_fullname",
    NULL::"text" AS "dd_bill_user_nickname",
    NULL::"text" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "p"."created_at"))::"date" AS "date",
    EXTRACT(month FROM "p"."created_at") AS "month",
    EXTRACT(year FROM "p"."created_at") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    NULL::"text" AS "type_color",
        CASE
            WHEN ("p"."Tag_Topics" IS NOT NULL) THEN "array_to_string"("p"."Tag_Topics", ', '::"text")
            ELSE 'Post'::"text"
        END AS "type_order",
    'Post'::"text" AS "whereTheRowComeFrom",
    "p"."id" AS "source_table_id",
    "p"."multi_img_url" AS "image_urls"
   FROM ((("public"."Post" "p"
     LEFT JOIN "public"."Post_Resident_id" "pr" ON (("p"."id" = "pr"."Post_id")))
     LEFT JOIN "public"."residents" "r" ON (("pr"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("p"."user_id" = "ui"."id")));


ALTER TABLE "public"."cCalendarWithDate" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."cCalendarWithDateNew" WITH ("security_invoker"='on') AS
 SELECT "cc"."id",
    "cc"."created_at",
    "cc"."Title",
    "cc"."Description",
    "cc"."Type",
    "cc"."dateTime",
    "cc"."nursinghome_id",
    "cc"."resident_id",
    "cc"."creator_id",
    "concat"("ui"."prefix", ' ', "ui"."full_name", ' (', "ui"."nickname", ')') AS "created_by",
    "cc"."isRequireNA",
    "cc"."NA_assign",
    "cc"."assignNA",
    "cc"."isNPO",
    "cc"."hospital",
    "cc"."isRelativePaidIn",
    "cc"."relativePaidDate",
    "cc"."isDocumentPrepared",
    "cc"."isPostOnBoardAfter",
    "ddr"."id" AS "DD_id",
    "ddr"."user_id" AS "dd_user_id",
    "dd_ui"."full_name" AS "dd_user_fullname",
    "dd_ui"."nickname" AS "dd_user_nickname",
    "dd_ui"."photo_url" AS "dd_user_photo",
    "dd_bill"."user_id" AS "dd_bill_user_id",
    "dd_bill_ui"."full_name" AS "dd_bill_user_fullname",
    "dd_bill_ui"."nickname" AS "dd_bill_user_nickname",
    "dd_bill_ui"."photo_url" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "cc"."dateTime"))::"date" AS "date",
    EXTRACT(month FROM "cc"."dateTime") AS "month",
    EXTRACT(year FROM "cc"."dateTime") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_status" AS "resident_status",
    "cs"."color" AS "type_color",
    "cs"."subject" AS "type_order",
    'C_Calendar'::"text" AS "whereTheRowComeFrom",
    "cc"."id" AS "source_table_id",
    "cc"."url",
    NULL::"text"[] AS "image_urls"
   FROM ((((((("public"."C_Calendar" "cc"
     LEFT JOIN "public"."residents" "r" ON (("cc"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("cc"."creator_id" = "ui"."id")))
     LEFT JOIN "public"."Calendar_Subject" "cs" ON (("cc"."Type" = "cs"."subject")))
     LEFT JOIN "public"."DD_Record_Clock" "ddr" ON (("cc"."id" = "ddr"."calendar_appointment_id")))
     LEFT JOIN "public"."user_info" "dd_ui" ON (("ddr"."user_id" = "dd_ui"."id")))
     LEFT JOIN "public"."DD_Record_Clock" "dd_bill" ON (("cc"."id" = "dd_bill"."calendar_bill_id")))
     LEFT JOIN "public"."user_info" "dd_bill_ui" ON (("dd_bill"."user_id" = "dd_bill_ui"."id")))
UNION ALL
 SELECT "sn"."id",
    "sn"."created_at",
    "sn"."type" AS "Title",
    "concat_ws"('
'::"text", NULLIF("sn"."Subjective", ''::"text"), NULLIF("sn"."Objective", ''::"text"), NULLIF("sn"."Assessment", ''::"text"), NULLIF("sn"."Plan", ''::"text"), NULLIF("sn"."descriptive_Note", ''::"text")) AS "Description",
    "sn"."type" AS "Type",
    "sn"."created_at" AS "dateTime",
    "r"."nursinghome_id",
    "sn"."resident_id",
    "sn"."user_id" AS "creator_id",
    "concat"("ui"."prefix", ' ', "ui"."full_name", ' (', "ui"."nickname", ')') AS "created_by",
    NULL::boolean AS "isRequireNA",
    NULL::"text" AS "NA_assign",
    NULL::"uuid" AS "assignNA",
    NULL::boolean AS "isNPO",
    NULL::"text" AS "hospital",
    NULL::boolean AS "isRelativePaidIn",
    NULL::timestamp with time zone AS "relativePaidDate",
    NULL::boolean AS "isDocumentPrepared",
    NULL::boolean AS "isPostOnBoardAfter",
    NULL::bigint AS "DD_id",
    NULL::"uuid" AS "dd_user_id",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    NULL::"uuid" AS "dd_bill_user_id",
    NULL::"text" AS "dd_bill_user_fullname",
    NULL::"text" AS "dd_bill_user_nickname",
    NULL::"text" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "sn"."created_at"))::"date" AS "date",
    EXTRACT(month FROM "sn"."created_at") AS "month",
    EXTRACT(year FROM "sn"."created_at") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_status" AS "resident_status",
    NULL::"text" AS "type_color",
    "sn"."type" AS "type_order",
    'SOAPNote'::"text" AS "whereTheRowComeFrom",
    "sn"."id" AS "source_table_id",
    NULL::"text" AS "url",
    NULL::"text"[] AS "image_urls"
   FROM (("public"."SOAPNote" "sn"
     LEFT JOIN "public"."residents" "r" ON (("sn"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("sn"."user_id" = "ui"."id")))
UNION ALL
 SELECT "p"."id",
    "p"."created_at",
    'Post'::"text" AS "Title",
    NULLIF("p"."Text", ''::"text") AS "Description",
        CASE
            WHEN ("p"."Tag_Topics" IS NOT NULL) THEN "array_to_string"("p"."Tag_Topics", ', '::"text")
            ELSE 'Post'::"text"
        END AS "Type",
    "p"."created_at" AS "dateTime",
    "p"."nursinghome_id",
    "pr"."resident_id",
    "p"."user_id" AS "creator_id",
    "concat"(COALESCE("ui"."prefix", ''::"text"), ' ', COALESCE("ui"."full_name", ''::"text"), ' (', COALESCE("ui"."nickname", ''::"text"), ')') AS "created_by",
    NULL::boolean AS "isRequireNA",
    NULL::"text" AS "NA_assign",
    NULL::"uuid" AS "assignNA",
    NULL::boolean AS "isNPO",
    NULL::"text" AS "hospital",
    NULL::boolean AS "isRelativePaidIn",
    NULL::timestamp with time zone AS "relativePaidDate",
    NULL::boolean AS "isDocumentPrepared",
    NULL::boolean AS "isPostOnBoardAfter",
    NULL::bigint AS "DD_id",
    NULL::"uuid" AS "dd_user_id",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    NULL::"uuid" AS "dd_bill_user_id",
    NULL::"text" AS "dd_bill_user_fullname",
    NULL::"text" AS "dd_bill_user_nickname",
    NULL::"text" AS "dd_bill_user_photo",
    ("date_trunc"('day'::"text", "p"."created_at"))::"date" AS "date",
    EXTRACT(month FROM "p"."created_at") AS "month",
    EXTRACT(year FROM "p"."created_at") AS "year",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_status" AS "resident_status",
    NULL::"text" AS "type_color",
        CASE
            WHEN ("p"."Tag_Topics" IS NOT NULL) THEN "array_to_string"("p"."Tag_Topics", ', '::"text")
            ELSE 'Post'::"text"
        END AS "type_order",
    'Post'::"text" AS "whereTheRowComeFrom",
    "p"."id" AS "source_table_id",
    NULL::"text" AS "url",
    "p"."multi_img_url" AS "image_urls"
   FROM ((("public"."Post" "p"
     LEFT JOIN "public"."Post_Resident_id" "pr" ON (("p"."id" = "pr"."Post_id")))
     LEFT JOIN "public"."residents" "r" ON (("pr"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("p"."user_id" = "ui"."id")));


ALTER TABLE "public"."cCalendarWithDateNew" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."calendar_basic_view" WITH ("security_invoker"='on') AS
 SELECT "cc"."id" AS "calendar_id",
    "cc"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "cc"."Title",
    "cc"."Description",
    "cc"."Type",
    "cc"."dateTime",
    ("date_trunc"('day'::"text", "cc"."dateTime"))::"date" AS "date_only",
    "dd_ui"."full_name" AS "dd_user_fullname",
    "dd_ui"."nickname" AS "dd_user_nickname",
    "dd_ui"."photo_url" AS "dd_user_photo",
    NULL::"text"[] AS "image_urls"
   FROM ((("public"."C_Calendar" "cc"
     LEFT JOIN "public"."residents" "r" ON (("cc"."resident_id" = "r"."id")))
     LEFT JOIN "public"."DD_Record_Clock" "ddr" ON (("cc"."id" = "ddr"."calendar_appointment_id")))
     LEFT JOIN "public"."user_info" "dd_ui" ON (("ddr"."user_id" = "dd_ui"."id")))
  WHERE ("cc"."dateTime" >= CURRENT_DATE)
UNION ALL
 SELECT "sn"."id" AS "calendar_id",
    "sn"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "sn"."type" AS "Title",
    "concat_ws"('
'::"text", NULLIF("sn"."Subjective", ''::"text"), NULLIF("sn"."Objective", ''::"text"), NULLIF("sn"."Assessment", ''::"text"), NULLIF("sn"."Plan", ''::"text"), NULLIF("sn"."descriptive_Note", ''::"text")) AS "Description",
    "sn"."type" AS "Type",
    "sn"."created_at" AS "dateTime",
    ("date_trunc"('day'::"text", "sn"."created_at"))::"date" AS "date_only",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    NULL::"text"[] AS "image_urls"
   FROM ("public"."SOAPNote" "sn"
     LEFT JOIN "public"."residents" "r" ON (("sn"."resident_id" = "r"."id")))
  WHERE ("sn"."created_at" >= CURRENT_DATE)
UNION ALL
 SELECT "p"."id" AS "calendar_id",
    "pr"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    'Post'::"text" AS "Title",
    NULLIF("p"."Text", ''::"text") AS "Description",
    COALESCE("array_to_string"("p"."Tag_Topics", ', '::"text"), 'Post'::"text") AS "Type",
    "p"."created_at" AS "dateTime",
    ("date_trunc"('day'::"text", "p"."created_at"))::"date" AS "date_only",
    NULL::"text" AS "dd_user_fullname",
    NULL::"text" AS "dd_user_nickname",
    NULL::"text" AS "dd_user_photo",
    "p"."multi_img_url" AS "image_urls"
   FROM (("public"."Post" "p"
     LEFT JOIN "public"."Post_Resident_id" "pr" ON (("p"."id" = "pr"."Post_id")))
     LEFT JOIN "public"."residents" "r" ON (("pr"."resident_id" = "r"."id")))
  WHERE ("p"."created_at" >= CURRENT_DATE);


ALTER TABLE "public"."calendar_basic_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ccalendarcountsbyresident" WITH ("security_invoker"='on') AS
 SELECT "concat"(COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), '_', COALESCE("cc"."nursinghome_id", "t"."nursinghome_id"), '_', COALESCE("cc"."resident_id", "t"."resident_id")) AS "id",
    COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only") AS "calendarDate",
    COALESCE("cc"."nursinghome_id", "t"."nursinghome_id") AS "nursinghomeId",
    COALESCE("cc"."resident_id", "t"."resident_id") AS "residentId",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Appointment'::"text") THEN 1
            ELSE NULL::integer
        END) AS "appointmentCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Treatment'::"text") THEN 1
            ELSE NULL::integer
        END) AS "treatmentCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Bill'::"text") THEN 1
            ELSE NULL::integer
        END) AS "billCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Ticket'::"text") THEN 1
            ELSE NULL::integer
        END) AS "ticketCount",
    "count"(
        CASE
            WHEN ("cc"."Type" = 'Incident'::"text") THEN 1
            ELSE NULL::integer
        END) AS "incidentCount",
    "count"(DISTINCT "t"."task_id") AS "TaskCount"
   FROM ("public"."C_Calendar" "cc"
     FULL JOIN "public"."v_tasks_only_without_repeat" "t" ON (((("date_trunc"('day'::"text", "cc"."dateTime"))::"date" = "t"."due_date_only") AND ("cc"."nursinghome_id" = "t"."nursinghome_id") AND (COALESCE("cc"."resident_id", "t"."resident_id") IS NOT NULL))))
  GROUP BY COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), COALESCE("cc"."nursinghome_id", "t"."nursinghome_id"), COALESCE("cc"."resident_id", "t"."resident_id")
  ORDER BY COALESCE(("date_trunc"('day'::"text", "cc"."dateTime"))::"date", "t"."due_date_only"), COALESCE("cc"."nursinghome_id", "t"."nursinghome_id"), COALESCE("cc"."resident_id", "t"."resident_id");


ALTER TABLE "public"."ccalendarcountsbyresident" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cleanup_snooze_log" (
    "log_id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "snooze_status" boolean NOT NULL,
    "log_timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "additional_info" "text"
);


ALTER TABLE "public"."cleanup_snooze_log" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."cleanup_snooze_log_log_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."cleanup_snooze_log_log_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cleanup_snooze_log_log_id_seq" OWNED BY "public"."cleanup_snooze_log"."log_id";



CREATE OR REPLACE VIEW "public"."clock_in_out_summary" WITH ("security_invoker"='on') AS
 WITH "clock_data" AS (
         SELECT "c"."id",
            "c"."user_id",
            "c"."nursinghome_id",
            "c"."created_at",
            "c"."clock_in_timestamp",
            "c"."clock_out_timestamp",
            "c"."supervisor_id",
            "c"."isAuto",
            "c"."Incharge",
            "c"."zones",
            "c"."isSupport",
            "c"."isChecked",
            "c"."duty_buyer",
            "c"."shift",
            "c"."selected_resident_id_list",
            "c"."selected_break_time",
            "c"."shift_score",
            "c"."self_score",
            "c"."shift_survey",
            "c"."bug_survey"
           FROM "public"."clock_in_out_ver2" "c"
        ), "paired_data" AS (
         SELECT "cd"."user_id",
            "cd"."nursinghome_id",
            "cd"."clock_in_timestamp" AS "clock_in_time",
            "cd"."clock_out_timestamp" AS "clock_out_time",
            "cd"."id" AS "clock_in_id",
            "cd"."id" AS "clock_out_id",
            "cd"."supervisor_id" AS "clock_in_supervisor_id",
            "cd"."supervisor_id" AS "clock_out_supervisor_id",
            "cd"."isAuto" AS "clock_in_is_auto",
            "cd"."isAuto" AS "clock_out_is_auto",
            "cd"."Incharge",
            "cd"."zones",
            "cd"."shift",
            NULL::boolean AS "isAbsent",
            NULL::"text" AS "sick_evident",
            NULL::"text" AS "sick_reason",
            false AS "isSick",
            "cd"."isSupport",
            NULL::bigint AS "Additional",
            NULL::"text" AS "additional_reason",
            NULL::double precision AS "Deduction",
            NULL::"text" AS "deduction_reason",
            NULL::bigint AS "special_record_id",
            NULL::bigint AS "dd_record_id",
            NULL::bigint AS "dd_post_id",
            false AS "is_manual_add_deduct",
            "cd"."created_at",
            "cd"."isChecked",
            "cd"."duty_buyer",
            "cd"."selected_resident_id_list",
            "cd"."selected_break_time",
            "cd"."shift_score",
            "cd"."self_score",
            "cd"."shift_survey",
            "cd"."bug_survey"
           FROM "clock_data" "cd"
          WHERE ("cd"."clock_in_timestamp" IS NOT NULL)
        ), "special_data" AS (
         SELECT "csr"."user_id",
            "csr"."nursinghome_id",
            "csr"."timestamp" AS "clock_in_time",
            NULL::timestamp without time zone AS "clock_out_time",
            NULL::bigint AS "clock_in_id",
            NULL::bigint AS "clock_out_id",
            "csr"."supervisor_id" AS "clock_in_supervisor_id",
            NULL::"uuid" AS "clock_out_supervisor_id",
            "csr"."isAuto" AS "clock_in_is_auto",
            NULL::boolean AS "clock_out_is_auto",
            "csr"."Incharge",
            "csr"."zones",
            NULL::"text" AS "shift",
            "csr"."isAbsent",
            "csr"."sick_evident",
            "csr"."sick_reason",
            ("csr"."sick_evident" IS NOT NULL) AS "isSick",
            "csr"."isSupport",
            "csr"."Additional",
            "csr"."additional_reason",
            "csr"."Deduction",
            "csr"."deduction_reason",
            "csr"."id" AS "special_record_id",
            NULL::bigint AS "dd_record_id",
            NULL::bigint AS "dd_post_id",
            true AS "is_manual_add_deduct",
            "csr"."created_at",
            "csr"."isChecked",
            NULL::"uuid" AS "duty_buyer",
            NULL::bigint[] AS "selected_resident_id_list",
            NULL::bigint[] AS "selected_break_time",
            NULL::bigint AS "shift_score",
            NULL::bigint AS "self_score",
            NULL::"text" AS "shift_survey",
            NULL::"text" AS "bug_survey"
           FROM "public"."Clock Special Record" "csr"
        ), "dd_data" AS (
         SELECT "ddr"."user_id",
            "cca"."nursinghome_id",
            COALESCE("cca"."dateTime", "ddr"."created_at") AS "clock_in_time",
            NULL::timestamp without time zone AS "clock_out_time",
            NULL::bigint AS "clock_in_id",
            NULL::bigint AS "clock_out_id",
            NULL::"uuid" AS "clock_in_supervisor_id",
            NULL::"uuid" AS "clock_out_supervisor_id",
            false AS "clock_in_is_auto",
            NULL::boolean AS "clock_out_is_auto",
            false AS "Incharge",
            NULL::bigint[] AS "zones",
            NULL::"text" AS "shift",
            false AS "isAbsent",
            NULL::"text" AS "sick_evident",
            NULL::"text" AS "sick_reason",
            false AS "isSick",
            false AS "isSupport",
            NULL::bigint AS "Additional",
            NULL::"text" AS "additional_reason",
            NULL::double precision AS "Deduction",
            NULL::"text" AS "deduction_reason",
            NULL::bigint AS "special_record_id",
            "ddr"."id" AS "dd_record_id",
            "p"."id" AS "dd_post_id",
            true AS "is_manual_add_deduct",
            "ddr"."created_at",
            "ddr"."isChecked",
            NULL::"uuid" AS "duty_buyer",
            NULL::bigint[] AS "selected_resident_id_list",
            NULL::bigint[] AS "selected_break_time",
            NULL::bigint AS "shift_score",
            NULL::bigint AS "self_score",
            NULL::"text" AS "shift_survey",
            NULL::"text" AS "bug_survey"
           FROM (("public"."DD_Record_Clock" "ddr"
             LEFT JOIN "public"."C_Calendar" "cca" ON (("ddr"."calendar_appointment_id" = "cca"."id")))
             LEFT JOIN "public"."Post" "p" ON (("p"."DD_id" = "ddr"."id")))
        ), "all_data" AS (
         SELECT "paired_data"."user_id",
            "paired_data"."nursinghome_id",
            "paired_data"."clock_in_time",
            "paired_data"."clock_out_time",
            "paired_data"."clock_in_id",
            "paired_data"."clock_out_id",
            "paired_data"."clock_in_supervisor_id",
            "paired_data"."clock_out_supervisor_id",
            "paired_data"."clock_in_is_auto",
            "paired_data"."clock_out_is_auto",
            "paired_data"."Incharge",
            "paired_data"."zones",
            "paired_data"."shift",
            "paired_data"."isAbsent",
            "paired_data"."sick_evident",
            "paired_data"."sick_reason",
            "paired_data"."isSick",
            "paired_data"."isSupport",
            "paired_data"."Additional",
            "paired_data"."additional_reason",
            "paired_data"."Deduction",
            "paired_data"."deduction_reason",
            "paired_data"."special_record_id",
            "paired_data"."dd_record_id",
            "paired_data"."dd_post_id",
            "paired_data"."is_manual_add_deduct",
            "paired_data"."created_at",
            "paired_data"."isChecked",
            "paired_data"."duty_buyer",
            "paired_data"."selected_resident_id_list",
            "paired_data"."selected_break_time",
            "paired_data"."shift_score",
            "paired_data"."self_score",
            "paired_data"."shift_survey",
            "paired_data"."bug_survey"
           FROM "paired_data"
        UNION ALL
         SELECT "special_data"."user_id",
            "special_data"."nursinghome_id",
            "special_data"."clock_in_time",
            "special_data"."clock_out_time",
            "special_data"."clock_in_id",
            "special_data"."clock_out_id",
            "special_data"."clock_in_supervisor_id",
            "special_data"."clock_out_supervisor_id",
            "special_data"."clock_in_is_auto",
            "special_data"."clock_out_is_auto",
            "special_data"."Incharge",
            "special_data"."zones",
            "special_data"."shift",
            "special_data"."isAbsent",
            "special_data"."sick_evident",
            "special_data"."sick_reason",
            "special_data"."isSick",
            "special_data"."isSupport",
            "special_data"."Additional",
            "special_data"."additional_reason",
            "special_data"."Deduction",
            "special_data"."deduction_reason",
            "special_data"."special_record_id",
            "special_data"."dd_record_id",
            "special_data"."dd_post_id",
            "special_data"."is_manual_add_deduct",
            "special_data"."created_at",
            "special_data"."isChecked",
            "special_data"."duty_buyer",
            "special_data"."selected_resident_id_list",
            "special_data"."selected_break_time",
            "special_data"."shift_score",
            "special_data"."self_score",
            "special_data"."shift_survey",
            "special_data"."bug_survey"
           FROM "special_data"
        UNION ALL
         SELECT "dd_data"."user_id",
            "dd_data"."nursinghome_id",
            "dd_data"."clock_in_time",
            "dd_data"."clock_out_time",
            "dd_data"."clock_in_id",
            "dd_data"."clock_out_id",
            "dd_data"."clock_in_supervisor_id",
            "dd_data"."clock_out_supervisor_id",
            "dd_data"."clock_in_is_auto",
            "dd_data"."clock_out_is_auto",
            "dd_data"."Incharge",
            "dd_data"."zones",
            "dd_data"."shift",
            "dd_data"."isAbsent",
            "dd_data"."sick_evident",
            "dd_data"."sick_reason",
            "dd_data"."isSick",
            "dd_data"."isSupport",
            "dd_data"."Additional",
            "dd_data"."additional_reason",
            "dd_data"."Deduction",
            "dd_data"."deduction_reason",
            "dd_data"."special_record_id",
            "dd_data"."dd_record_id",
            "dd_data"."dd_post_id",
            "dd_data"."is_manual_add_deduct",
            "dd_data"."created_at",
            "dd_data"."isChecked",
            "dd_data"."duty_buyer",
            "dd_data"."selected_resident_id_list",
            "dd_data"."selected_break_time",
            "dd_data"."shift_score",
            "dd_data"."self_score",
            "dd_data"."shift_survey",
            "dd_data"."bug_survey"
           FROM "dd_data"
        ), "shift_data" AS (
         SELECT "all_data"."user_id",
            "all_data"."nursinghome_id",
            "all_data"."clock_in_time",
            "all_data"."clock_out_time",
            "all_data"."clock_in_id",
            "all_data"."clock_out_id",
            "all_data"."clock_in_supervisor_id",
            "all_data"."clock_out_supervisor_id",
            "all_data"."clock_in_is_auto",
            "all_data"."clock_out_is_auto",
            "all_data"."Incharge",
            "all_data"."zones",
            "all_data"."shift",
            "all_data"."isAbsent",
            "all_data"."sick_evident",
            "all_data"."sick_reason",
            "all_data"."isSick",
            "all_data"."isSupport",
            "all_data"."Additional",
            "all_data"."additional_reason",
            "all_data"."Deduction",
            "all_data"."deduction_reason",
            "all_data"."special_record_id",
            "all_data"."dd_record_id",
            "all_data"."dd_post_id",
            "all_data"."is_manual_add_deduct",
            "all_data"."created_at",
            "all_data"."isChecked",
            "all_data"."duty_buyer",
            "all_data"."selected_resident_id_list",
            "all_data"."selected_break_time",
            "all_data"."shift_score",
            "all_data"."self_score",
            "all_data"."shift_survey",
            "all_data"."bug_survey",
            COALESCE("all_data"."shift",
                CASE
                    WHEN (("all_data"."clock_in_time")::time without time zone < '12:00:00'::time without time zone) THEN 'เวรเช้า'::"text"
                    ELSE 'เวรดึก'::"text"
                END) AS "shift_type",
                CASE
                    WHEN (EXTRACT(day FROM "all_data"."clock_in_time") >= (26)::numeric) THEN ("date_trunc"('month'::"text", "all_data"."clock_in_time") + '1 mon'::interval)
                    ELSE "date_trunc"('month'::"text", "all_data"."clock_in_time")
                END AS "payroll_base_month",
            "all_data"."Deduction" AS "final_deduction",
            "all_data"."deduction_reason" AS "final_deduction_reason"
           FROM "all_data"
        ), "enriched_data" AS (
         SELECT "sd"."user_id",
            "sd"."nursinghome_id",
            "sd"."clock_in_time",
            "sd"."clock_out_time",
            "sd"."clock_in_id",
            "sd"."clock_out_id",
            "sd"."clock_in_supervisor_id",
            "sd"."clock_out_supervisor_id",
            "sd"."clock_in_is_auto",
            "sd"."clock_out_is_auto",
            "sd"."Incharge",
            "sd"."zones",
            "sd"."shift",
            "sd"."isAbsent",
            "sd"."sick_evident",
            "sd"."sick_reason",
            "sd"."isSick",
            "sd"."isSupport",
            "sd"."Additional",
            "sd"."additional_reason",
            "sd"."Deduction",
            "sd"."deduction_reason",
            "sd"."special_record_id",
            "sd"."dd_record_id",
            "sd"."dd_post_id",
            "sd"."is_manual_add_deduct",
            "sd"."created_at",
            "sd"."isChecked",
            "sd"."duty_buyer",
            "sd"."selected_resident_id_list",
            "sd"."selected_break_time",
            "sd"."shift_score",
            "sd"."self_score",
            "sd"."shift_survey",
            "sd"."bug_survey",
            "sd"."shift_type",
            "sd"."payroll_base_month",
            "sd"."final_deduction",
            "sd"."final_deduction_reason",
            "array_agg"(DISTINCT "nz"."zone" ORDER BY "nz"."zone") AS "zone_names"
           FROM (("shift_data" "sd"
             LEFT JOIN LATERAL "unnest"("sd"."zones") "z"("zone_id") ON (true))
             LEFT JOIN "public"."nursinghome_zone" "nz" ON (("nz"."id" = "z"."zone_id")))
          GROUP BY "sd"."user_id", "sd"."nursinghome_id", "sd"."clock_in_id", "sd"."clock_out_id", "sd"."special_record_id", "sd"."dd_record_id", "sd"."dd_post_id", "sd"."clock_in_time", "sd"."clock_out_time", "sd"."clock_in_supervisor_id", "sd"."clock_out_supervisor_id", "sd"."clock_in_is_auto", "sd"."clock_out_is_auto", "sd"."Incharge", "sd"."isAbsent", "sd"."isSick", "sd"."isSupport", "sd"."sick_evident", "sd"."sick_reason", "sd"."zones", "sd"."shift", "sd"."selected_resident_id_list", "sd"."selected_break_time", "sd"."shift_type", "sd"."payroll_base_month", "sd"."Additional", "sd"."additional_reason", "sd"."Deduction", "sd"."deduction_reason", "sd"."final_deduction", "sd"."final_deduction_reason", "sd"."is_manual_add_deduct", "sd"."created_at", "sd"."isChecked", "sd"."duty_buyer", "sd"."shift_score", "sd"."self_score", "sd"."shift_survey", "sd"."bug_survey"
        )
 SELECT "ed"."user_id",
    "ed"."nursinghome_id",
    "ed"."clock_in_time",
    "ed"."clock_out_time",
    "ed"."clock_in_id",
    "ed"."clock_out_id",
    "ed"."clock_in_supervisor_id",
    "ed"."clock_out_supervisor_id",
    "ed"."clock_in_is_auto",
    "ed"."clock_out_is_auto",
    "ed"."Incharge",
    "ed"."zones",
    "ed"."shift",
    "ed"."isAbsent",
    "ed"."sick_evident",
    "ed"."sick_reason",
    "ed"."isSick",
    "ed"."isSupport",
    "ed"."Additional",
    "ed"."additional_reason",
    "ed"."Deduction",
    "ed"."deduction_reason",
    "ed"."special_record_id",
    "ed"."dd_record_id",
    "ed"."dd_post_id",
    "ed"."is_manual_add_deduct",
    "ed"."created_at",
    "ed"."isChecked",
    "ed"."duty_buyer",
    "ed"."selected_resident_id_list",
    "ed"."selected_break_time",
    "ed"."shift_score",
    "ed"."self_score",
    "ed"."shift_survey",
    "ed"."bug_survey",
    "ed"."shift_type",
    "ed"."payroll_base_month",
    "ed"."final_deduction",
    "ed"."final_deduction_reason",
    "ed"."zone_names",
        CASE
            WHEN (("ed"."selected_resident_id_list" IS NULL) OR ("array_length"("ed"."selected_resident_id_list", 1) = 0)) THEN NULL::"text"[]
            ELSE ( SELECT "array_agg"("r"."i_Name_Surname" ORDER BY "r"."id") AS "array_agg"
               FROM "public"."residents" "r"
              WHERE ("r"."id" = ANY ("ed"."selected_resident_id_list")))
        END AS "selected_resident_names",
    "ui"."nickname" AS "user_nickname",
    "ui"."full_name" AS "user_fullname",
    "ui"."photo_url" AS "user_photo_url",
    "nh"."name" AS "nursinghome_name",
    "sui"."nickname" AS "clock_in_supervisor_nickname",
    "sui"."full_name" AS "clock_in_supervisor_fullname",
    "sui"."photo_url" AS "clock_in_supervisor_photo_url",
    "suo"."nickname" AS "clock_out_supervisor_nickname",
    "suo"."full_name" AS "clock_out_supervisor_fullname",
    "suo"."photo_url" AS "clock_out_supervisor_photo_url",
    "db"."nickname" AS "duty_buyer_nickname",
    "db"."full_name" AS "duty_buyer_fullname",
    "db"."photo_url" AS "duty_buyer_photo_url",
    "db"."prefix" AS "duty_buyer_prefix",
    EXTRACT(year FROM "ed"."payroll_base_month") AS "year",
    EXTRACT(month FROM "ed"."payroll_base_month") AS "month",
    (EXTRACT(epoch FROM
        CASE
            WHEN ("ed"."clock_out_time" IS NULL) THEN (CURRENT_TIMESTAMP - "ed"."clock_in_time")
            ELSE ("ed"."clock_out_time" - "ed"."clock_in_time")
        END) / 3600.0) AS "in_time",
    (("ed"."clock_in_time" AT TIME ZONE 'Asia/Bangkok'::"text"))::"date" AS "clock_in_date"
   FROM ((((("enriched_data" "ed"
     LEFT JOIN "public"."user_info" "ui" ON (("ui"."id" = "ed"."user_id")))
     LEFT JOIN "public"."user_info" "sui" ON (("sui"."id" = "ed"."clock_in_supervisor_id")))
     LEFT JOIN "public"."user_info" "suo" ON (("suo"."id" = "ed"."clock_out_supervisor_id")))
     LEFT JOIN "public"."user_info" "db" ON (("db"."id" = "ed"."duty_buyer")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("nh"."id" = "ed"."nursinghome_id")))
  ORDER BY "ed"."clock_in_time", "ed"."user_id", "ed"."nursinghome_id";


ALTER TABLE "public"."clock_in_out_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."clock_in_out_monthly_summary" WITH ("security_invoker"='on') AS
 WITH "base_months" AS (
         SELECT "clock_in_out_summary"."user_id",
            "clock_in_out_summary"."nursinghome_id",
            "clock_in_out_summary"."clock_in_time",
            "clock_in_out_summary"."shift_type",
            "clock_in_out_summary"."clock_out_time",
            "clock_in_out_summary"."isAbsent",
            "clock_in_out_summary"."isSick",
            "clock_in_out_summary"."isSupport",
            "clock_in_out_summary"."Incharge",
            "clock_in_out_summary"."Additional",
            "clock_in_out_summary"."final_deduction",
            "clock_in_out_summary"."is_manual_add_deduct",
                CASE
                    WHEN (EXTRACT(day FROM "clock_in_out_summary"."clock_in_time") >= (26)::numeric) THEN ("date_trunc"('month'::"text", "clock_in_out_summary"."clock_in_time") + '1 mon'::interval)
                    ELSE "date_trunc"('month'::"text", "clock_in_out_summary"."clock_in_time")
                END AS "payroll_base_month",
            "round"((EXTRACT(epoch FROM
                CASE
                    WHEN ("clock_in_out_summary"."clock_out_time" IS NOT NULL) THEN ("clock_in_out_summary"."clock_out_time" - "clock_in_out_summary"."clock_in_time")
                    ELSE '00:00:00'::interval
                END) / 3600.0), 2) AS "hours_worked"
           FROM "public"."clock_in_out_summary"
        ), "summarized_data" AS (
         SELECT "bm"."user_id",
            "ui"."nickname" AS "user_nickname",
            "ui"."full_name" AS "user_fullname",
            "ui"."photo_url" AS "user_photo_url",
            "ui"."buildNumber" AS "build_number",
            "bm"."nursinghome_id",
            "nh"."name" AS "nursinghome_name",
            (EXTRACT(month FROM "bm"."payroll_base_month"))::bigint AS "month",
            (EXTRACT(year FROM "bm"."payroll_base_month"))::bigint AS "year",
            "count"(*) FILTER (WHERE (((COALESCE("bm"."is_manual_add_deduct", false) = false) AND ((COALESCE("bm"."isAbsent", false) = false) OR ((COALESCE("bm"."isAbsent", false) = true) AND (COALESCE("bm"."isSick", false) = true)))) OR ((COALESCE("bm"."is_manual_add_deduct", false) = true) AND (COALESCE("bm"."isSick", false) = true)))) AS "total_shifts",
            "count"(*) FILTER (WHERE (("bm"."shift_type" = 'เวรเช้า'::"text") AND (COALESCE("bm"."isAbsent", false) = false) AND (COALESCE("bm"."is_manual_add_deduct", false) = false))) AS "total_day_shifts",
            "count"(*) FILTER (WHERE (("bm"."shift_type" = 'เวรดึก'::"text") AND (COALESCE("bm"."isAbsent", false) = false) AND (COALESCE("bm"."is_manual_add_deduct", false) = false))) AS "total_night_shifts",
            "count"(*) FILTER (WHERE ((COALESCE("bm"."isAbsent", false) = true) AND (COALESCE("bm"."isSick", false) = false))) AS "absent_count_26_to_25",
            "count"(*) FILTER (WHERE (COALESCE("bm"."isSick", false) = true)) AS "sick_count_26_to_25",
            "count"(*) FILTER (WHERE (COALESCE("bm"."Incharge", false) = true)) AS "incharge_count_26_to_25",
            "count"(*) FILTER (WHERE (COALESCE("bm"."isSupport", false) = true)) AS "support_count_26_to_25",
            "sum"("bm"."Additional") AS "total_additional",
            "sum"("bm"."final_deduction") AS "total_deduction"
           FROM (("base_months" "bm"
             LEFT JOIN "public"."user_info" "ui" ON (("ui"."id" = "bm"."user_id")))
             LEFT JOIN "public"."nursinghomes" "nh" ON (("nh"."id" = "bm"."nursinghome_id")))
          GROUP BY "bm"."user_id", "ui"."nickname", "ui"."full_name", "ui"."photo_url", "ui"."buildNumber", "bm"."nursinghome_id", "nh"."name", "bm"."payroll_base_month"
        ), "dd_count_26_to_25" AS (
         SELECT "sub"."user_id",
            "sub"."payroll_base_month",
            "count"(*) FILTER (WHERE ("sub"."dd_post_id" IS NOT NULL)) AS "dd_count_26_to_25"
           FROM ( SELECT "clock_in_out_summary"."user_id",
                        CASE
                            WHEN (EXTRACT(day FROM "clock_in_out_summary"."clock_in_time") >= (26)::numeric) THEN ("date_trunc"('month'::"text", "clock_in_out_summary"."clock_in_time") + '1 mon'::interval)
                            ELSE "date_trunc"('month'::"text", "clock_in_out_summary"."clock_in_time")
                        END AS "payroll_base_month",
                    "clock_in_out_summary"."dd_post_id"
                   FROM "public"."clock_in_out_summary"
                  WHERE ("clock_in_out_summary"."dd_record_id" IS NOT NULL)) "sub"
          GROUP BY "sub"."user_id", "sub"."payroll_base_month"
        ), "workday_26_to_25" AS (
         SELECT "Workday"."nursinghome_id",
            "Workday"."month",
            "Workday"."year",
            "Workday"."WD" AS "required_workdays_26_to_25"
           FROM "public"."Workday"
        )
 SELECT "sd"."user_id",
    "sd"."user_nickname",
    "sd"."user_fullname",
    "sd"."user_photo_url",
    "sd"."build_number",
    "sd"."nursinghome_id",
    "sd"."nursinghome_name",
    "sd"."month",
    "sd"."year",
    "sd"."total_shifts",
    "sd"."total_day_shifts",
    "sd"."total_night_shifts",
    "sd"."absent_count_26_to_25",
    "sd"."sick_count_26_to_25",
    "sd"."incharge_count_26_to_25",
    "sd"."support_count_26_to_25",
    "sd"."total_additional",
    "sd"."total_deduction",
    COALESCE("dd"."dd_count_26_to_25", (0)::bigint) AS "dd_count_26_to_25",
    COALESCE("wd"."required_workdays_26_to_25", (0)::bigint) AS "required_workdays_26_to_25",
    "lag"("sd"."total_shifts") OVER (PARTITION BY "sd"."user_id", "sd"."nursinghome_id" ORDER BY "sd"."year", "sd"."month") AS "last_month_shifts",
    "lag"("wd"."required_workdays_26_to_25") OVER (PARTITION BY "sd"."user_id", "sd"."nursinghome_id" ORDER BY "sd"."year", "sd"."month") AS "last_month_wd",
    GREATEST(COALESCE(("lag"("sd"."total_shifts") OVER (PARTITION BY "sd"."user_id", "sd"."nursinghome_id" ORDER BY "sd"."year", "sd"."month") - "lag"("wd"."required_workdays_26_to_25") OVER (PARTITION BY "sd"."user_id", "sd"."nursinghome_id" ORDER BY "sd"."year", "sd"."month")), (0)::bigint), (0)::bigint) AS "pot",
    "lag"("dd"."dd_count_26_to_25") OVER (PARTITION BY "sd"."user_id", "sd"."nursinghome_id" ORDER BY "sd"."year", "sd"."month") AS "pdd"
   FROM (("summarized_data" "sd"
     LEFT JOIN "dd_count_26_to_25" "dd" ON ((("dd"."user_id" = "sd"."user_id") AND ("dd"."payroll_base_month" = "make_date"(("sd"."year")::integer, ("sd"."month")::integer, 1)))))
     LEFT JOIN "workday_26_to_25" "wd" ON ((("wd"."nursinghome_id" = "sd"."nursinghome_id") AND ("wd"."year" = "sd"."year") AND ("wd"."month" = "sd"."month"))))
  ORDER BY "sd"."year", "sd"."month", "sd"."user_id", "sd"."nursinghome_id";


ALTER TABLE "public"."clock_in_out_monthly_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."clock_shift_headcount_na_2m" WITH ("security_invoker"='on') AS
 WITH "cutoff" AS (
         SELECT ((CURRENT_DATE - '2 mons'::interval))::"date" AS "start_date"
        )
 SELECT "s"."nursinghome_id",
    "s"."clock_in_date" AS "Date",
    "s"."shift_type" AS "Shift",
    "count"(DISTINCT "s"."user_id") AS "manPower"
   FROM ("public"."clock_in_out_summary" "s"
     JOIN "public"."user_info" "ui" ON (("ui"."id" = "s"."user_id")))
  WHERE (("s"."clock_in_date" >= ( SELECT "cutoff"."start_date"
           FROM "cutoff")) AND (COALESCE("s"."is_manual_add_deduct", false) = false) AND (COALESCE("s"."isAbsent", false) = false) AND (COALESCE("s"."Incharge", false) = false) AND ("ui"."group" = 4))
  GROUP BY "s"."nursinghome_id", "s"."clock_in_date", "s"."shift_type";


ALTER TABLE "public"."clock_shift_headcount_na_2m" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."clock_shift_roster_na_2m" WITH ("security_invoker"='on') AS
 WITH "cutoff" AS (
         SELECT ((CURRENT_DATE - '2 mons'::interval))::"date" AS "start_date"
        ), "base" AS (
         SELECT DISTINCT "s"."nursinghome_id",
            "s"."clock_in_date" AS "Date",
            "s"."shift_type" AS "Shift",
            "s"."user_id"
           FROM ("public"."clock_in_out_summary" "s"
             JOIN "public"."user_info" "ui_1" ON (("ui_1"."id" = "s"."user_id")))
          WHERE (("s"."clock_in_date" >= ( SELECT "cutoff"."start_date"
                   FROM "cutoff")) AND (COALESCE("s"."is_manual_add_deduct", false) = false) AND (COALESCE("s"."isAbsent", false) = false) AND (COALESCE("s"."Incharge", false) = false) AND ("ui_1"."group" = 4))
        )
 SELECT "b"."nursinghome_id",
    "b"."Date",
    "b"."Shift",
    "jsonb_agg"("jsonb_build_object"('id', "ui"."id", 'full_name', "ui"."full_name", 'nickname', "ui"."nickname", 'email', COALESCE("ui"."email", ("au"."email")::"text")) ORDER BY "ui"."nickname") AS "roster_json"
   FROM (("base" "b"
     JOIN "public"."user_info" "ui" ON (("ui"."id" = "b"."user_id")))
     LEFT JOIN "auth"."users" "au" ON (("au"."id" = "b"."user_id")))
  GROUP BY "b"."nursinghome_id", "b"."Date", "b"."Shift";


ALTER TABLE "public"."clock_shift_roster_na_2m" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."resident_underlying_disease" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "underlying_id" bigint
);


ALTER TABLE "public"."resident_underlying_disease" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."underlying_disease" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nursinghome_id" bigint,
    "name" "text",
    "pastel_color" "text"
);


ALTER TABLE "public"."underlying_disease" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."combined_vitalsign_details_view" WITH ("security_invoker"='on') AS
 SELECT "vs"."id",
    "vs"."created_at",
    "to_char"("vs"."created_at", 'DD/MM/YYYY HH24:MI น.'::"text") AS "formatted_created_at",
    COALESCE("vs"."DTX", (0)::bigint) AS "DTX",
    COALESCE("vs"."Defecation", false) AS "Defecation",
    COALESCE("vs"."Input", (0)::bigint) AS "Input",
    COALESCE("vs"."O2", (0)::bigint) AS "O2",
    COALESCE("vs"."PR", (0)::bigint) AS "PR",
    COALESCE("vs"."Temp", (0)::numeric) AS "Temp",
    COALESCE("vs"."constipation", (0)::numeric) AS "constipation",
    COALESCE("vs"."dBP", (0)::bigint) AS "dBP",
    COALESCE("vs"."generalReport", '-'::"text") AS "generalReport",
    COALESCE("vs"."napkin", (0)::bigint) AS "napkin",
    COALESCE("vs"."output", '-'::"text") AS "output",
    "vs"."resident_id",
    "vs"."Sent",
    COALESCE("vs"."sBP", (0)::bigint) AS "sBP",
    "vs"."user_id",
    COALESCE("vs"."shift", '-'::"text") AS "shift",
    COALESCE("vs"."Insulin", (0)::bigint) AS "Insulin",
    COALESCE("vs"."isFullReport", false) AS "isFullReport",
    COALESCE("vs"."RR", (0)::bigint) AS "RR",
    "ui"."nickname" AS "user_nickname",
    "ui"."photo_url" AS "user_photo_url",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."i_picture_url" AS "resident_photo_url",
        CASE
            WHEN ("vs"."constipation" > (2)::numeric) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "constipation_color",
    ("vs"."constipation" > (2)::numeric) AS "is_constipation_abnormal",
        CASE
            WHEN (("vs"."Temp" < (36)::numeric) OR ("vs"."Temp" > 37.4)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "temp_color",
    (("vs"."Temp" < (36)::numeric) OR ("vs"."Temp" > 37.4)) AS "is_temp_abnormal",
        CASE
            WHEN (("vs"."PR" < 60) OR ("vs"."PR" > 120)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "pr_color",
    (("vs"."PR" < 60) OR ("vs"."PR" > 120)) AS "is_pr_abnormal",
        CASE
            WHEN (("vs"."RR" < 16) OR ("vs"."RR" > 26)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "rr_color",
    (("vs"."RR" < 16) OR ("vs"."RR" > 26)) AS "is_rr_abnormal",
        CASE
            WHEN (("vs"."sBP" < 90) OR ("vs"."sBP" > 140) OR ("vs"."dBP" < 60) OR ("vs"."dBP" > 90)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "bp_color",
    (("vs"."sBP" < 90) OR ("vs"."sBP" > 140) OR ("vs"."dBP" < 60) OR ("vs"."dBP" > 90)) AS "is_bp_abnormal",
        CASE
            WHEN (("vs"."O2" < 95) OR ("vs"."O2" > 100)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "o2_color",
    (("vs"."O2" < 95) OR ("vs"."O2" > 100)) AS "is_o2_abnormal",
        CASE
            WHEN (("vs"."DTX" < 80) OR ("vs"."DTX" > 140)) THEN '#E65454'::"text"
            ELSE '#12151C'::"text"
        END AS "dtx_color",
    (("vs"."DTX" < 80) OR ("vs"."DTX" > 140)) AS "is_dtx_abnormal",
        CASE
            WHEN ("concat_ws"(', '::"text",
            CASE
                WHEN (("vs"."Temp" > (0)::numeric) AND (("vs"."Temp" < (36)::numeric) OR ("vs"."Temp" > 37.4))) THEN (('T '::"text" || "vs"."Temp") ||
                CASE
                    WHEN ("vs"."Temp" < (36)::numeric) THEN ' ต่ำ'::"text"
                    ELSE ' มีไข้'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."PR" > 0) AND (("vs"."PR" < 60) OR ("vs"."PR" > 120))) THEN (('PR '::"text" || "vs"."PR") ||
                CASE
                    WHEN ("vs"."PR" < 60) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."RR" > 0) AND (("vs"."RR" < 16) OR ("vs"."RR" > 26))) THEN (('RR '::"text" || "vs"."RR") ||
                CASE
                    WHEN ("vs"."RR" < 16) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."sBP" > 0) AND (("vs"."sBP" < 90) OR ("vs"."sBP" > 140))) THEN (('sBP '::"text" || "vs"."sBP") ||
                CASE
                    WHEN ("vs"."sBP" < 90) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."dBP" > 0) AND (("vs"."dBP" < 60) OR ("vs"."dBP" > 90))) THEN (('dBP '::"text" || "vs"."dBP") ||
                CASE
                    WHEN ("vs"."dBP" < 60) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."O2" > 0) AND (("vs"."O2" < 95) OR ("vs"."O2" > 100))) THEN (('O2 '::"text" || "vs"."O2") ||
                CASE
                    WHEN ("vs"."O2" < 95) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."DTX" > 0) AND (("vs"."DTX" < 80) OR ("vs"."DTX" > 140))) THEN (('DTX '::"text" || "vs"."DTX") ||
                CASE
                    WHEN ("vs"."DTX" < 80) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN ("vs"."constipation" > (2)::numeric) THEN (('Constipation '::"text" || "vs"."constipation") || ' ท้องผูก'::"text")
                ELSE NULL::"text"
            END) <> ''::"text") THEN "concat_ws"(', '::"text",
            CASE
                WHEN (("vs"."Temp" > (0)::numeric) AND (("vs"."Temp" < (36)::numeric) OR ("vs"."Temp" > 37.4))) THEN (('T '::"text" || "vs"."Temp") ||
                CASE
                    WHEN ("vs"."Temp" < (36)::numeric) THEN ' ต่ำ'::"text"
                    ELSE ' มีไข้'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."PR" > 0) AND (("vs"."PR" < 60) OR ("vs"."PR" > 120))) THEN (('PR '::"text" || "vs"."PR") ||
                CASE
                    WHEN ("vs"."PR" < 60) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."RR" > 0) AND (("vs"."RR" < 16) OR ("vs"."RR" > 26))) THEN (('RR '::"text" || "vs"."RR") ||
                CASE
                    WHEN ("vs"."RR" < 16) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."sBP" > 0) AND (("vs"."sBP" < 90) OR ("vs"."sBP" > 140))) THEN (('sBP '::"text" || "vs"."sBP") ||
                CASE
                    WHEN ("vs"."sBP" < 90) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."dBP" > 0) AND (("vs"."dBP" < 60) OR ("vs"."dBP" > 90))) THEN (('dBP '::"text" || "vs"."dBP") ||
                CASE
                    WHEN ("vs"."dBP" < 60) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."O2" > 0) AND (("vs"."O2" < 95) OR ("vs"."O2" > 100))) THEN (('O2 '::"text" || "vs"."O2") ||
                CASE
                    WHEN ("vs"."O2" < 95) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN (("vs"."DTX" > 0) AND (("vs"."DTX" < 80) OR ("vs"."DTX" > 140))) THEN (('DTX '::"text" || "vs"."DTX") ||
                CASE
                    WHEN ("vs"."DTX" < 80) THEN ' ต่ำ'::"text"
                    ELSE ' สูง'::"text"
                END)
                ELSE NULL::"text"
            END,
            CASE
                WHEN ("vs"."constipation" > (2)::numeric) THEN (('ท้องผูก '::"text" || "vs"."constipation") || ' วัน'::"text")
                ELSE NULL::"text"
            END)
            ELSE 'สัญญาณชีพล่าสุดปกติ'::"text"
        END AS "vital_signs_status",
    ( SELECT "array_agg"("rc"."Scale" ORDER BY "srl"."Subject_id") AS "array_agg"
           FROM ("public"."Scale_Report_Log" "srl"
             JOIN "public"."Report_Choice" "rc" ON (("srl"."Choice_id" = "rc"."id")))
          WHERE ("srl"."vital_sign_id" = "vs"."id")
          GROUP BY "srl"."vital_sign_id") AS "choice_scales",
    ( SELECT "array_agg"("srl"."Subject_id" ORDER BY "srl"."Subject_id") AS "array_agg"
           FROM "public"."Scale_Report_Log" "srl"
          WHERE ("srl"."vital_sign_id" = "vs"."id")
          GROUP BY "srl"."vital_sign_id") AS "subject_ids",
    ( SELECT "array_agg"("srl"."Relation_id" ORDER BY "srl"."Subject_id") AS "array_agg"
           FROM "public"."Scale_Report_Log" "srl"
          WHERE ("srl"."vital_sign_id" = "vs"."id")
          GROUP BY "srl"."vital_sign_id") AS "relation_ids",
    ( SELECT "array_agg"("srl"."report_description" ORDER BY "srl"."Subject_id") AS "array_agg"
           FROM "public"."Scale_Report_Log" "srl"
          WHERE ("srl"."vital_sign_id" = "vs"."id")
          GROUP BY "srl"."vital_sign_id") AS "report_descriptions",
    ( SELECT "array_agg"("ud"."name" ORDER BY "ud"."name") AS "array_agg"
           FROM ("public"."resident_underlying_disease" "rud"
             JOIN "public"."underlying_disease" "ud" ON (("rud"."underlying_id" = "ud"."id")))
          WHERE ("rud"."resident_id" = "vs"."resident_id")) AS "underlying_diseases",
    "concat"('#', "r"."i_Name_Surname", "chr"(10),
        CASE
            WHEN (("vs"."shift" = 'เวรเช้า'::"text") AND "vs"."isFullReport") THEN "concat"('เวรเช้า (ของวันที่ ', "to_char"("vs"."created_at", 'DD/MM/YYYY'::"text"), ') ', "chr"(10), 'ตั้งแต่ 07.00 - 19.00 น.', "chr"(10), "chr"(10))
            WHEN (("vs"."shift" = 'เวรดึก'::"text") AND "vs"."isFullReport") THEN "concat"('เวรดึก (ของวันที่ ', "to_char"(("vs"."created_at" - '1 day'::interval), 'DD/MM/YYYY'::"text"), ') ', "chr"(10), 'ตั้งแต่ 19.00 - 07.00 น.', "chr"(10), "chr"(10))
            ELSE ''::"text"
        END, 'สัญญาณชีพ', "chr"(10),
        CASE
            WHEN ("vs"."Temp" > (0)::numeric) THEN ((('T = '::"text" || "vs"."Temp") || ' °C'::"text") || "chr"(10))
            ELSE ''::"text"
        END,
        CASE
            WHEN ("vs"."PR" > 0) THEN ((('P = '::"text" || "vs"."PR") || ' bpm'::"text") || "chr"(10))
            ELSE ''::"text"
        END,
        CASE
            WHEN ("vs"."RR" > 0) THEN ((('R = '::"text" || "vs"."RR") || ' /min'::"text") || "chr"(10))
            ELSE ''::"text"
        END,
        CASE
            WHEN (("vs"."sBP" > 0) AND ("vs"."dBP" > 0)) THEN ((((('BP = '::"text" || "vs"."sBP") || '/'::"text") || "vs"."dBP") || ' mmHg'::"text") || "chr"(10))
            ELSE ''::"text"
        END,
        CASE
            WHEN ("vs"."O2" > 0) THEN ((('O2sat = '::"text" || "vs"."O2") || ' %'::"text") || "chr"(10))
            ELSE ''::"text"
        END, "chr"(10),
        CASE
            WHEN "vs"."isFullReport" THEN "concat"('🍃ปริมาณน้ำเข้า: ', COALESCE(("vs"."Input")::"text", ''::"text"), "chr"(10), '🍃ปริมาณน้ำออก (โดยประมาณ): ', COALESCE("vs"."output", ''::"text"), "chr"(10), '🍃การขับถ่าย = ',
            CASE
                WHEN "vs"."Defecation" THEN 'อุจจาระ'::"text"
                ELSE 'ไม่อุจจาระ'::"text"
            END, "chr"(10), '🍃นับรวมจำนวนวันที่ไม่ได้ถ่าย ', COALESCE(("vs"."constipation")::"text", ''::"text"), ' วัน', "chr"(10),
            CASE
                WHEN ("vs"."napkin" > 0) THEN "concat"('🍃ใช้ผ้าอ้อมจำนวน ', ("vs"."napkin")::"text", ' ผืน', "chr"(10))
                ELSE ''::"text"
            END,
            CASE
                WHEN ("vs"."DTX" > 0) THEN "concat"('🍃ค่าน้ำตาลปลายนิ้ว = ', ("vs"."DTX")::"text", ' mg/dl', "chr"(10))
                ELSE ''::"text"
            END,
            CASE
                WHEN ("vs"."Insulin" > 0) THEN "concat"('🍃ฉีดอินซูลิน =  ', ("vs"."Insulin")::"text", ' unit', "chr"(10))
                ELSE ''::"text"
            END, "chr"(10))
            ELSE ''::"text"
        END,
        CASE
            WHEN "vs"."isFullReport" THEN "concat"(( SELECT "string_agg"("concat"('- ', "rs"."Subject", ': ', "rc"."Scale", ' คะแนน (', "rc"."Choice", ')',
                    CASE
                        WHEN (("srl"."report_description" IS NOT NULL) AND ("srl"."report_description" <> ''::"text")) THEN "concat"("chr"(10), '* ', "srl"."report_description")
                        ELSE ''::"text"
                    END), "chr"(10) ORDER BY "srl"."index") AS "string_agg"
               FROM (("public"."Scale_Report_Log" "srl"
                 JOIN "public"."Report_Subject" "rs" ON (("srl"."Subject_id" = "rs"."id")))
                 JOIN "public"."Report_Choice" "rc" ON ((("srl"."Choice_id" = "rc"."Scale") AND ("srl"."Subject_id" = "rc"."Subject"))))
              WHERE ("srl"."vital_sign_id" = "vs"."id")), "chr"(10),
            CASE
                WHEN (("vs"."generalReport" IS NOT NULL) AND ("vs"."generalReport" <> ''::"text") AND ("vs"."generalReport" <> '-'::"text")) THEN "concat"("vs"."generalReport", "chr"(10))
                ELSE ''::"text"
            END, "chr"(10), '👧ผู้ดูแล ', COALESCE("ui"."full_name", ''::"text"), ' (', COALESCE("ui"."nickname", ''::"text"), ')', "chr"(10), "to_char"("vs"."created_at", 'DD/MM/YYYY HH24:MI'::"text"), ' น.', "chr"(10), '❤️THANK YOU🙏')
            ELSE "concat"('👧ผู้ดูแล ', COALESCE("ui"."full_name", ''::"text"), ' (', COALESCE("ui"."nickname", ''::"text"), ')', "chr"(10), "to_char"("vs"."created_at", 'DD/MM/YYYY HH24:MI'::"text"), ' น.', "chr"(10), '❤️THANK YOU🙏')
        END) AS "formatted_vital_signs"
   FROM (("public"."vitalSign" "vs"
     LEFT JOIN "public"."user_info" "ui" ON (("vs"."user_id" = "ui"."id")))
     LEFT JOIN "public"."residents" "r" ON (("vs"."resident_id" = "r"."id")));


ALTER TABLE "public"."combined_vitalsign_details_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."med_history" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "med_list_id" bigint,
    "on_date" "date",
    "off_date" "date",
    "note" "text",
    "user_id" "uuid",
    "reconcile" double precision,
    "new_setting" "text"
);


ALTER TABLE "public"."med_history" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."med_logs_with_nickname" WITH ("security_invoker"='on') AS
 SELECT "m"."id",
    "m"."created_at",
    "m"."2C_completed_by",
    "m"."Created_Date",
    "m"."SecondCPictureUrl" AS "2C_picture_url",
    "m"."meal",
    "m"."resident_id",
    "m"."ThirdCPictureUrl" AS "3C_picture_url",
    "m"."3C_Compleated_by",
    "m"."3C_time_stamps",
    "m"."ArrangeMed_by",
    "ui2"."nickname" AS "user_nickname_2c",
    "ui3"."nickname" AS "user_nickname_3c",
    "uia"."nickname" AS "user_nickname_arrangemed",
    "m"."task_id"
   FROM ((("public"."A_Med_logs" "m"
     LEFT JOIN "public"."user_info" "ui2" ON (("m"."2C_completed_by" = "ui2"."id")))
     LEFT JOIN "public"."user_info" "ui3" ON (("m"."3C_Compleated_by" = "ui3"."id")))
     LEFT JOIN "public"."user_info" "uia" ON (("m"."ArrangeMed_by" = "uia"."id")))
  WHERE ("m"."created_at" >= ("now"() - '1 mon'::interval));


ALTER TABLE "public"."med_logs_with_nickname" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medicine_List" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "med_DB_id" bigint,
    "resident_id" bigint,
    "take_tab" numeric,
    "BLDB" "text"[],
    "BeforeAfter" "text"[],
    "every_hr" bigint,
    "underlying_disease_tag" "text"[],
    "prn" boolean DEFAULT false,
    "typeOfTime" "text",
    "DaysOfWeek" "text"[],
    "MedString" bigint,
    "med_amout_status" "text"
);


ALTER TABLE "public"."medicine_List" OWNER TO "postgres";


COMMENT ON COLUMN "public"."medicine_List"."typeOfTime" IS 'hr, day, week, month';



CREATE TABLE IF NOT EXISTS "public"."medicine_tag" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "med_list_id" bigint,
    "tag" "text",
    "resident_id" bigint
);


ALTER TABLE "public"."medicine_tag" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."medicine_summary" WITH ("security_invoker"='on') AS
 WITH "med_status" AS (
         SELECT "ml"."id" AS "medicine_list_id",
            "ml"."created_at" AS "medicine_list_created_at",
            "ml"."med_DB_id",
            "ml"."resident_id",
            "ml"."take_tab",
            COALESCE("ml"."BLDB", '{}'::"text"[]) AS "BLDB",
            COALESCE("ml"."BeforeAfter", '{}'::"text"[]) AS "BeforeAfter",
            COALESCE("ml"."every_hr", (1)::bigint) AS "every_hr",
            "ml"."underlying_disease_tag",
            "ml"."prn",
                CASE
                    WHEN (("ml"."DaysOfWeek" IS NOT NULL) AND ("ml"."DaysOfWeek" <> '{}'::"text"[])) THEN 'สัปดาห์'::"text"
                    ELSE COALESCE("ml"."typeOfTime", 'วัน'::"text")
                END AS "typeOfTime",
            COALESCE("ml"."DaysOfWeek", '{}'::"text"[]) AS "DaysOfWeek",
            "ml"."MedString",
            "ml"."med_amout_status",
            "mdb"."brand_name",
            "mdb"."generic_name",
            "mdb"."str",
            "mdb"."route",
            "mdb"."unit",
            "mdb"."info",
            "mdb"."group",
            "mdb"."pillpic_url",
            COALESCE("mdb"."Front-Foiled", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Front-Foiled",
            COALESCE("mdb"."Back-Foiled", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Back-Foiled",
            COALESCE("mdb"."Front-Nude", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Front-Nude",
            COALESCE("mdb"."Back-Nude", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Back-Nude",
            "first_mh"."on_date" AS "first_med_history_on_date",
            "last_mh"."off_date" AS "last_med_history_off_date",
            "last_mh"."id" AS "last_med_history_id",
            "last_mh"."created_at" AS "last_med_history_created_at",
            "last_mh"."note" AS "last_med_history_note",
            "last_mh"."user_id" AS "last_med_history_user_id",
            "last_mh"."reconcile" AS "last_med_history_reconcile",
            "last_mh"."new_setting" AS "last_med_history_new_setting",
            ( SELECT "array_agg"("mt"."tag") AS "array_agg"
                   FROM "public"."medicine_tag" "mt"
                  WHERE ("mt"."med_list_id" = "ml"."id")) AS "tags",
                CASE
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("first_mh"."on_date" > CURRENT_DATE)) THEN (('เริ่มในอีก '::"text" || ("first_mh"."on_date" - CURRENT_DATE)) || ' วัน'::"text")
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NULL)) THEN ((((CURRENT_DATE - "first_mh"."on_date") || ' วัน'::"text") || "chr"(10)) || "to_char"(("first_mh"."on_date")::timestamp with time zone, 'DD/MM/YY'::"text"))
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NOT NULL) AND ("last_mh"."off_date" < CURRENT_DATE)) THEN (((((('('::"text" || (("last_mh"."off_date" - "first_mh"."on_date") + 1)) || ' วัน)'::"text") || "chr"(10)) || "to_char"(("first_mh"."on_date")::timestamp with time zone, 'DD/MM/YY'::"text")) || "chr"(10)) || "to_char"(("last_mh"."off_date")::timestamp with time zone, 'DD/MM/YY'::"text"))
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NOT NULL) AND ("last_mh"."off_date" >= CURRENT_DATE)) THEN (((((((((CURRENT_DATE - "first_mh"."on_date") + 1) || '/'::"text") || (("last_mh"."off_date" - "first_mh"."on_date") + 1)) || ' วัน'::"text") || "chr"(10)) || "to_char"(("first_mh"."on_date")::timestamp with time zone, 'DD/MM/YY'::"text")) || "chr"(10)) || "to_char"(("last_mh"."off_date")::timestamp with time zone, 'DD/MM/YY'::"text"))
                    ELSE NULL::"text"
                END AS "status_info",
                CASE
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("first_mh"."on_date" > CURRENT_DATE)) THEN 'waiting'::"text"
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NULL)) THEN 'on'::"text"
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NOT NULL) AND ("last_mh"."off_date" < CURRENT_DATE)) THEN 'off'::"text"
                    WHEN (("first_mh"."on_date" IS NOT NULL) AND ("last_mh"."off_date" IS NOT NULL) AND ("last_mh"."off_date" >= CURRENT_DATE)) THEN 'on'::"text"
                    ELSE NULL::"text"
                END AS "status",
                CASE
                    WHEN ("ml"."prn" AND ("ml"."every_hr" IS NOT NULL) AND ("ml"."every_hr" > 0) AND ("ml"."typeOfTime" IS NOT NULL) AND ("ml"."typeOfTime" <> ''::"text")) THEN ((('เมื่อมีอาการ, ทุก '::"text" || "ml"."every_hr") || ' '::"text") || "ml"."typeOfTime")
                    WHEN "ml"."prn" THEN 'เมื่อมีอาการ'::"text"
                    WHEN (("ml"."every_hr" IS NOT NULL) AND ("ml"."every_hr" > 0) AND ("ml"."typeOfTime" IS NOT NULL) AND ("ml"."typeOfTime" <> ''::"text") AND ("ml"."DaysOfWeek" IS NOT NULL) AND ("ml"."DaysOfWeek" <> '{}'::"text"[])) THEN ((((('ทุก '::"text" || "ml"."every_hr") || ' '::"text") || "ml"."typeOfTime") || ', เฉพาะวัน'::"text") || "array_to_string"("ml"."DaysOfWeek", ', '::"text"))
                    WHEN (("ml"."every_hr" IS NOT NULL) AND ("ml"."every_hr" > 0) AND ("ml"."typeOfTime" IS NOT NULL) AND ("ml"."typeOfTime" <> ''::"text")) THEN ((('ทุก '::"text" || "ml"."every_hr") || ' '::"text") || "ml"."typeOfTime")
                    WHEN (("ml"."typeOfTime" IS NOT NULL) AND ("ml"."typeOfTime" <> ''::"text") AND ("ml"."DaysOfWeek" IS NOT NULL) AND ("ml"."DaysOfWeek" <> '{}'::"text"[])) THEN ((('ทุก '::"text" || "ml"."typeOfTime") || ', เฉพาะวัน'::"text") || "array_to_string"("ml"."DaysOfWeek", ', '::"text"))
                    WHEN (("ml"."DaysOfWeek" IS NOT NULL) AND ("ml"."DaysOfWeek" <> '{}'::"text"[])) THEN ('เฉพาะวัน'::"text" || "array_to_string"("ml"."DaysOfWeek", ', '::"text"))
                    ELSE ("array_length"("ml"."BLDB", 1) || ' เวลา'::"text")
                END AS "dosage_frequency",
            "last_info_mh"."created_at" AS "last_info_update_at",
            "last_reconcile_mh"."created_at" AS "last_reconcile_update_at"
           FROM ((((("public"."medicine_List" "ml"
             LEFT JOIN "public"."med_DB" "mdb" ON (("ml"."med_DB_id" = "mdb"."id")))
             LEFT JOIN LATERAL ( SELECT "mh1"."id",
                    "mh1"."created_at",
                    "mh1"."med_list_id",
                    "mh1"."on_date",
                    "mh1"."off_date",
                    "mh1"."note",
                    "mh1"."user_id",
                    "mh1"."reconcile",
                    "mh1"."new_setting"
                   FROM "public"."med_history" "mh1"
                  WHERE (("mh1"."med_list_id" = "ml"."id") AND ("mh1"."on_date" IS NOT NULL))
                  ORDER BY "mh1"."on_date" DESC, "mh1"."created_at" DESC
                 LIMIT 1) "first_mh" ON (true))
             LEFT JOIN LATERAL ( SELECT "mh2"."id",
                    "mh2"."created_at",
                    "mh2"."med_list_id",
                    "mh2"."on_date",
                    "mh2"."off_date",
                    "mh2"."note",
                    "mh2"."user_id",
                    "mh2"."reconcile",
                    "mh2"."new_setting"
                   FROM "public"."med_history" "mh2"
                  WHERE ("mh2"."med_list_id" = "ml"."id")
                  ORDER BY "mh2"."created_at" DESC
                 LIMIT 1) "last_mh" ON (true))
             LEFT JOIN LATERAL ( SELECT "mh3"."id",
                    "mh3"."created_at",
                    "mh3"."med_list_id",
                    "mh3"."on_date",
                    "mh3"."off_date",
                    "mh3"."note",
                    "mh3"."user_id",
                    "mh3"."reconcile",
                    "mh3"."new_setting"
                   FROM "public"."med_history" "mh3"
                  WHERE (("mh3"."med_list_id" = "ml"."id") AND ("mh3"."reconcile" IS NULL))
                  ORDER BY "mh3"."created_at" DESC
                 LIMIT 1) "last_info_mh" ON (true))
             LEFT JOIN LATERAL ( SELECT "mh4"."id",
                    "mh4"."created_at",
                    "mh4"."med_list_id",
                    "mh4"."on_date",
                    "mh4"."off_date",
                    "mh4"."note",
                    "mh4"."user_id",
                    "mh4"."reconcile",
                    "mh4"."new_setting"
                   FROM "public"."med_history" "mh4"
                  WHERE (("mh4"."med_list_id" = "ml"."id") AND ("mh4"."reconcile" IS NOT NULL))
                  ORDER BY "mh4"."created_at" DESC
                 LIMIT 1) "last_reconcile_mh" ON (true))
        ), "usage_calc" AS (
         SELECT "ms_1"."medicine_list_id",
                CASE
                    WHEN (("ms_1"."typeOfTime" = 'สัปดาห์'::"text") OR ("ms_1"."typeOfTime" = 'เดือน'::"text")) THEN NULL::numeric
                    ELSE ("ms_1"."take_tab" * (COALESCE("array_length"("ms_1"."BLDB", 1), 1))::numeric)
                END AS "daily_usage",
                CASE
                    WHEN ("ms_1"."typeOfTime" = 'สัปดาห์'::"text") THEN (("ms_1"."take_tab" * (COALESCE("array_length"("ms_1"."BLDB", 1), 1))::numeric) * (COALESCE("array_length"("ms_1"."DaysOfWeek", 1), 1))::numeric)
                    ELSE NULL::numeric
                END AS "weekly_usage",
                CASE
                    WHEN ("ms_1"."typeOfTime" = 'เดือน'::"text") THEN ("ms_1"."take_tab" * (COALESCE("array_length"("ms_1"."BLDB", 1), 1))::numeric)
                    ELSE NULL::numeric
                END AS "monthly_usage"
           FROM "med_status" "ms_1"
        )
 SELECT "ms"."medicine_list_id",
    "ms"."medicine_list_created_at",
    "ms"."med_DB_id",
    "ms"."resident_id",
    "ms"."take_tab",
    "ms"."BLDB",
    "ms"."BeforeAfter",
    "ms"."every_hr",
    "ms"."underlying_disease_tag",
    "ms"."prn",
    "ms"."typeOfTime",
    "ms"."DaysOfWeek",
    "ms"."brand_name",
    "ms"."generic_name",
    "ms"."str",
    "ms"."route",
    "ms"."unit",
    "ms"."info",
    "ms"."group",
    "ms"."pillpic_url",
    "ms"."Front-Foiled",
    "ms"."Back-Foiled",
    "ms"."Front-Nude",
    "ms"."Back-Nude",
    "ms"."first_med_history_on_date",
    "ms"."last_med_history_off_date",
    "ms"."last_med_history_id",
    "ms"."last_med_history_created_at",
    "ms"."last_med_history_note",
    "ms"."last_med_history_user_id",
    "ms"."last_med_history_reconcile",
    "ms"."last_med_history_new_setting",
    "ms"."tags",
    "ms"."status_info",
    "ms"."status",
    "ms"."dosage_frequency",
    "uc"."daily_usage",
    "uc"."weekly_usage",
    "uc"."monthly_usage",
    "ms"."MedString",
    "ms"."med_amout_status",
    ((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer AS "days_since_start",
    ((((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer)::numeric * COALESCE("uc"."daily_usage",
        CASE
            WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
            ELSE NULL::numeric
        END,
        CASE
            WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
            ELSE NULL::numeric
        END, (0)::numeric)) AS "expected_used_pills",
    "floor"(GREATEST(("ms"."last_med_history_reconcile" - (((((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer)::numeric * COALESCE("uc"."daily_usage",
        CASE
            WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
            ELSE NULL::numeric
        END,
        CASE
            WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
            ELSE NULL::numeric
        END, (0)::numeric)))::double precision), (0)::double precision)) AS "remaining_pills",
    (CURRENT_DATE + ('1 day'::interval * (("round"((GREATEST(("ms"."last_med_history_reconcile" - (((((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer)::numeric * COALESCE("uc"."daily_usage",
        CASE
            WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
            ELSE NULL::numeric
        END,
        CASE
            WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
            ELSE NULL::numeric
        END, (0)::numeric)))::double precision), (0)::double precision) / (
        CASE
            WHEN ("uc"."daily_usage" IS NOT NULL) THEN "uc"."daily_usage"
            WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
            WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
            ELSE (1)::numeric
        END)::double precision)))::integer)::double precision)) AS "predicted_run_out_date",
        CASE
            WHEN (("ms"."status" = 'on'::"text") AND ((CURRENT_DATE + ('1 day'::interval * (("round"((GREATEST(("ms"."last_med_history_reconcile" - (((((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer)::numeric * COALESCE("uc"."daily_usage",
            CASE
                WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
                ELSE NULL::numeric
            END,
            CASE
                WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
                ELSE NULL::numeric
            END, (0)::numeric)))::double precision), (0)::double precision) / (
            CASE
                WHEN ("uc"."daily_usage" IS NOT NULL) THEN "uc"."daily_usage"
                WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
                WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
                ELSE (1)::numeric
            END)::double precision)))::integer)::double precision)) < (CURRENT_DATE + '15 days'::interval))) THEN true
            ELSE false
        END AS "run_out_within_15_days",
        CASE
            WHEN (("ms"."status" = 'on'::"text") AND ((CURRENT_DATE + ('1 day'::interval * (("round"((GREATEST(("ms"."last_med_history_reconcile" - (((((EXTRACT(epoch FROM (CURRENT_TIMESTAMP - "ms"."last_med_history_created_at")) / (86400)::numeric))::integer)::numeric * COALESCE("uc"."daily_usage",
            CASE
                WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
                ELSE NULL::numeric
            END,
            CASE
                WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
                ELSE NULL::numeric
            END, (0)::numeric)))::double precision), (0)::double precision) / (
            CASE
                WHEN ("uc"."daily_usage" IS NOT NULL) THEN "uc"."daily_usage"
                WHEN ("uc"."weekly_usage" IS NOT NULL) THEN ("uc"."weekly_usage" / (7)::numeric)
                WHEN ("uc"."monthly_usage" IS NOT NULL) THEN ("uc"."monthly_usage" / (30)::numeric)
                ELSE (1)::numeric
            END)::double precision)))::integer)::double precision)) < (CURRENT_DATE + '7 days'::interval))) THEN true
            ELSE false
        END AS "run_out_within_7_days",
    ( SELECT "string_agg"("sub"."subst", ''::"text" ORDER BY "sub"."subst") AS "string_agg"
           FROM ( SELECT
                        CASE
                            WHEN ("value"."value" = 'เช้า'::"text") THEN 'a'::"text"
                            WHEN ("value"."value" = 'กลางวัน'::"text") THEN 'b'::"text"
                            WHEN ("value"."value" = 'เย็น'::"text") THEN 'c'::"text"
                            WHEN ("value"."value" = 'ก่อนนอน'::"text") THEN 'd'::"text"
                            ELSE NULL::"text"
                        END AS "subst"
                   FROM "unnest"("ms"."BLDB") "value"("value")) "sub") AS "sorted_bldb",
    ( SELECT "string_agg"("sub"."subst", ''::"text" ORDER BY "sub"."subst") AS "string_agg"
           FROM ( SELECT
                        CASE
                            WHEN ("value"."value" = 'ก่อนอาหาร'::"text") THEN 'x'::"text"
                            WHEN ("value"."value" = 'หลังอาหาร'::"text") THEN 'y'::"text"
                            ELSE NULL::"text"
                        END AS "subst"
                   FROM "unnest"(COALESCE("ms"."BeforeAfter", ARRAY[''::"text"])) "value"("value")) "sub") AS "sorted_beforeafter",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_status",
        CASE
            WHEN (POSITION(('on'::"text") IN ("ms"."status")) > 0) THEN '#02985B'::"text"
            ELSE '#5A5C60'::"text"
        END AS "status_color",
    "concat"("ms"."generic_name", ' (', "ms"."brand_name", ') ', "ms"."str", ' ', "ms"."route", ' ', ("ms"."take_tab")::"text", ' ', "ms"."unit", ' ', "array_to_string"("ms"."BeforeAfter", ', '::"text"), ' ', "array_to_string"("ms"."BLDB", ', '::"text"), ' ', "ms"."dosage_frequency") AS "medication_details",
    "ms"."last_info_update_at",
    "ms"."last_reconcile_update_at",
    (EXISTS ( SELECT 1
           FROM "public"."B_Ticket" "bt"
          WHERE (("bt"."med_list_id" = "ms"."medicine_list_id") AND ("bt"."status" = 'open'::"text")))) AS "has_open_ticket",
    ( SELECT "bt"."id"
           FROM "public"."B_Ticket" "bt"
          WHERE (("bt"."med_list_id" = "ms"."medicine_list_id") AND ("bt"."status" = 'open'::"text"))
          ORDER BY "bt"."created_at" DESC
         LIMIT 1) AS "open_ticket_id",
    ( SELECT "ct"."title"
           FROM "public"."C_Tasks" "ct"
          WHERE ("ct"."self_ticket_id" = ( SELECT "bt"."id"
                   FROM "public"."B_Ticket" "bt"
                  WHERE (("bt"."med_list_id" = "ms"."medicine_list_id") AND ("bt"."status" = 'open'::"text"))
                  ORDER BY "bt"."created_at" DESC
                 LIMIT 1))
          ORDER BY "ct"."created_at" DESC
         LIMIT 1) AS "latest_task_status"
   FROM (("med_status" "ms"
     LEFT JOIN "usage_calc" "uc" ON (("ms"."medicine_list_id" = "uc"."medicine_list_id")))
     LEFT JOIN "public"."residents" "r" ON (("ms"."resident_id" = "r"."id")));


ALTER TABLE "public"."medicine_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."resident_diseases_view" WITH ("security_invoker"='on') AS
 SELECT "rud"."resident_id",
    "string_agg"("ud"."name", ', '::"text") AS "diseases"
   FROM ("public"."resident_underlying_disease" "rud"
     JOIN "public"."underlying_disease" "ud" ON (("rud"."underlying_id" = "ud"."id")))
  GROUP BY "rud"."resident_id";


ALTER TABLE "public"."resident_diseases_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."resident_line_group_id" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "line_group_id" "text"
);


ALTER TABLE "public"."resident_line_group_id" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."resident_programs_view" WITH ("security_invoker"='on') AS
 SELECT "rp"."resident_id",
    "string_agg"("p"."name", ', '::"text") AS "programs"
   FROM ("public"."resident_programs" "rp"
     JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
  GROUP BY "rp"."resident_id";


ALTER TABLE "public"."resident_programs_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."resident_relatives" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resident_id" bigint,
    "relatives_id" bigint
);


ALTER TABLE "public"."resident_relatives" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."combined_resident_details_view" WITH ("security_invoker"='on') AS
 WITH "subject_sets" AS (
         SELECT "rrr"."resident_id",
            "array_agg"(DISTINCT "rrr"."subject_id") FILTER (WHERE ("rrr"."shift" = 'เวรเช้า'::"text")) AS "subject_ids_morning_shift",
            "array_agg"(DISTINCT "rrr"."subject_id") FILTER (WHERE ("rrr"."shift" = 'เวรดึก'::"text")) AS "subject_ids_night_shift",
            "array_agg"(DISTINCT "rrr"."id") FILTER (WHERE ("rrr"."shift" = 'เวรเช้า'::"text")) AS "morning_shift_relation_ids",
            "array_agg"(DISTINCT "rrr"."id") FILTER (WHERE ("rrr"."shift" = 'เวรดึก'::"text")) AS "night_shift_relation_ids"
           FROM "public"."Resident_Report_Relation" "rrr"
          GROUP BY "rrr"."resident_id"
        )
 SELECT "r"."id" AS "resident_id",
    "r"."nursinghome_id",
    COALESCE("r"."i_Name_Surname", '-'::"text") AS "i_Name_Surname",
    COALESCE("r"."i_National_ID_num", '-'::"text") AS "i_National_ID_num",
    COALESCE("to_char"(("r"."i_DOB")::timestamp with time zone, 'DD/MM/YYYY'::"text"), '-'::"text") AS "i_DOB",
    "r"."i_DOB" AS "i_dob_datetime",
    COALESCE((EXTRACT(year FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."i_DOB")::timestamp with time zone)))::"text", '-'::"text") AS "age",
    COALESCE(NULLIF("r"."i_gender", ''::"text"), '-'::"text") AS "i_gender",
    COALESCE(NULLIF("r"."i_picture_url", ''::"text"), 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/sign/user_Profile_Pic/profile%20blank.png'::"text") AS "i_picture_url",
    COALESCE(NULLIF("r"."m_past_history", ''::"text"), '-'::"text") AS "m_past_history",
    COALESCE(NULLIF("r"."m_dietary", ''::"text"), '-'::"text") AS "m_dietary",
    COALESCE(NULLIF("r"."m_fooddrug_allergy", ''::"text"), '-'::"text") AS "m_fooddrug_allergy",
    COALESCE("r"."s_status", '-'::"text") AS "s_status",
    COALESCE(NULLIF("r"."s_bed", ''::"text"), '-'::"text") AS "s_bed",
    COALESCE(NULLIF("r"."s_reason_being_here", ''::"text"), '-'::"text") AS "s_reason_being_here",
    COALESCE("to_char"(("r"."s_contract_date")::timestamp with time zone, 'DD/MM/YYYY'::"text"), '-'::"text") AS "s_contract_date",
    "r"."s_contract_date" AS "s_contract_date_datetime",
    COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
    COALESCE("nh"."name", '-'::"text") AS "nursinghome_name",
    COALESCE("rdv"."diseases", '-'::"text") AS "diseases",
    COALESCE("rpv"."programs", '-'::"text") AS "programs",
    COALESCE("max"("first_rel"."relative_id"), ('-1'::integer)::bigint) AS "relative_id",
    COALESCE("first_rel"."r_name_surname", '-'::"text") AS "relative_name",
    COALESCE("first_rel"."r_phone", '-'::"text") AS "relative_phone",
    COALESCE("first_rel"."r_nickname", '-'::"text") AS "relative_nickname",
    COALESCE(( SELECT "json_agg"("json_build_object"('id', "rel_sub"."id", 'name_surname', "rel_sub"."r_name_surname", 'nickname', "rel_sub"."r_nickname", 'phone', "rel_sub"."r_phone", 'detail', "rel_sub"."r_detail", 'key_person', "rel_sub"."key_person", 'line_user_id', "rel_sub"."lineUserId") ORDER BY "rel_sub"."key_person" DESC NULLS LAST, "rel_sub"."r_name_surname") AS "json_agg"
           FROM ("public"."resident_relatives" "rr_sub"
             JOIN "public"."relatives" "rel_sub" ON (("rr_sub"."relatives_id" = "rel_sub"."id")))
          WHERE ("rr_sub"."resident_id" = "r"."id")), '[]'::"json") AS "relatives_list",
    COALESCE(( SELECT "count"(*) AS "count"
           FROM "public"."resident_relatives" "rr_count"
          WHERE ("rr_count"."resident_id" = "r"."id")), (0)::bigint) AS "relatives_count",
    COALESCE(ARRAY( SELECT "sub_1"."ud_name"
           FROM ( SELECT "rud_1"."id" AS "occurrence_order",
                    "ud_1"."name" AS "ud_name"
                   FROM ("public"."resident_underlying_disease" "rud_1"
                     JOIN "public"."underlying_disease" "ud_1" ON (("rud_1"."underlying_id" = "ud_1"."id")))
                  WHERE ("rud_1"."resident_id" = "r"."id")
                  ORDER BY "rud_1"."id") "sub_1"), '{}'::"text"[]) AS "underlying_diseases_list",
    COALESCE(ARRAY( SELECT "sub_2"."ud_id"
           FROM ( SELECT "rud_2"."id" AS "occurrence_order",
                    "ud_2"."id" AS "ud_id"
                   FROM ("public"."resident_underlying_disease" "rud_2"
                     JOIN "public"."underlying_disease" "ud_2" ON (("rud_2"."underlying_id" = "ud_2"."id")))
                  WHERE ("rud_2"."resident_id" = "r"."id")
                  ORDER BY "rud_2"."id") "sub_2"), '{}'::bigint[]) AS "underlying_disease_list_id",
    COALESCE(ARRAY( SELECT "sub_1"."pastel_color"
           FROM ( SELECT "rud_1"."id" AS "occurrence_order",
                    "ud_1"."pastel_color"
                   FROM ("public"."resident_underlying_disease" "rud_1"
                     JOIN "public"."underlying_disease" "ud_1" ON (("rud_1"."underlying_id" = "ud_1"."id")))
                  WHERE ("rud_1"."resident_id" = "r"."id")
                  ORDER BY "rud_1"."id") "sub_1"), '{}'::"text"[]) AS "disease_pastel_color",
    COALESCE("latest_arrangemed"."user_nickname_arrangemed", '-'::"text") AS "latest_user_nickname_arrangemed",
    COALESCE("med_error_summary"."error_summary", '-'::"text") AS "current_day_med_error_summary",
    COALESCE(NULLIF("tag_summary"."tag_summary", ''::"text"), '-'::"text") AS "current_day_med_tag_summary",
    COALESCE("arrange_med_today"."arrangement_details", '-'::"text") AS "arrange_med_nickname_today",
    COALESCE(ARRAY( SELECT "p"."id"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::bigint[]) AS "program_ids_list",
    COALESCE(ARRAY( SELECT "p"."name"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::"text"[]) AS "programs_list",
    COALESCE(ARRAY( SELECT "p"."program_pastel_color"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::"text"[]) AS "program_pastel_color_list",
    COALESCE("nz"."zone", '-'::"text") AS "s_zone",
    COALESCE("lmh"."latest_med_history_created_at", ('1970-01-01 00:00:00'::timestamp without time zone)::timestamp with time zone) AS "latest_med_history_created_at",
    "nz"."id" AS "zone_id",
        CASE
            WHEN ("r"."i_gender" = 'ชาย'::"text") THEN '#2F73FD'::"text"
            WHEN ("r"."i_gender" = 'หญิง'::"text") THEN '#CC5FB9'::"text"
            ELSE '#e0e3e7'::"text"
        END AS "gender_color",
        CASE
            WHEN ("age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone) < '1 mon'::interval) THEN (EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)) || 'ว'::"text")
            WHEN ("age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone) < '1 year'::interval) THEN (((EXTRACT(month FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)) || 'ด '::"text") || EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone))) || 'ว'::"text")
            ELSE (((((EXTRACT(year FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)) || 'ป '::"text") || EXTRACT(month FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone))) || 'ด '::"text") || EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone))) || ' ว'::"text")
        END AS "s_stay_period",
    "r"."DTX/insulin",
    "cvs"."vital_signs_status",
        CASE
            WHEN ("cvs"."vital_signs_status" <> 'สัญญาณชีพล่าสุดปกติ'::"text") THEN '#A90000'::"text"
            ELSE '#5A5C60'::"text"
        END AS "vital_signs_color",
    "r"."Report_Amount",
    "cvs"."latest_vital_sign_id",
    "cvs"."latest_vital_sign_date",
    "last_vs"."Sent" AS "latest_sent_status",
    "cvs"."user_nickname" AS "latest_vital_sign_creator_nickname",
    "max"(COALESCE("med_summary"."on_count", (0)::bigint)) AS "current_medication_count",
    "max"(COALESCE("med_summary"."total_count", (0)::bigint)) AS "total_medication_count",
    (("max"(COALESCE("med_summary"."on_count", (0)::bigint)) || '/'::"text") || "max"(COALESCE("med_summary"."total_count", (0)::bigint))) AS "medication_summary",
    COALESCE("max"("last_vs"."shift"), '-'::"text") AS "latest_shift",
    COALESCE("current_day_med_correct_summary"."correct_summary", '-'::"text") AS "current_day_med_correct_summary",
    COALESCE("med_summary"."run_out_within_15_days", false) AS "run_out_within_15_days",
    COALESCE("med_summary"."run_out_within_7_days", false) AS "run_out_within_7_days",
    COALESCE("ss"."subject_ids_morning_shift", '{}'::bigint[]) AS "subject_ids_morning_shift",
    COALESCE("ss"."subject_ids_night_shift", '{}'::bigint[]) AS "subject_ids_night_shift",
    COALESCE("ss"."morning_shift_relation_ids", '{}'::bigint[]) AS "morning_shift_relation_ids",
    COALESCE("ss"."night_shift_relation_ids", '{}'::bigint[]) AS "night_shift_relation_ids",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM "public"."A_Med_Error_Log"
              WHERE (("A_Med_Error_Log"."resident_id" = "r"."id") AND ("A_Med_Error_Log"."CalendarDate" = CURRENT_DATE) AND ("A_Med_Error_Log"."reply_nurseMark" = 'ไม่ถูกต้อง'::"text")))) THEN true
            ELSE false
        END AS "incorrect_nurse_mark",
    COALESCE("rlgi"."line_group_id", '-'::"text") AS "line_group_id"
   FROM (((((((((((((((("public"."residents" "r"
     LEFT JOIN ( SELECT "A_Med_Error_Log"."resident_id",
            "string_agg"("concat"("to_char"(("A_Med_Error_Log"."CalendarDate")::timestamp with time zone, 'DD/MM/YYYY'::"text"), ' ', "A_Med_Error_Log"."meal", ': ', "A_Med_Error_Log"."reply_nurseMark"), "chr"(10)) FILTER (WHERE ("A_Med_Error_Log"."reply_nurseMark" <> 'ถูกต้อง'::"text")) AS "error_summary"
           FROM "public"."A_Med_Error_Log"
          WHERE ("A_Med_Error_Log"."CalendarDate" = CURRENT_DATE)
          GROUP BY "A_Med_Error_Log"."resident_id") "med_error_summary" ON (("r"."id" = "med_error_summary"."resident_id")))
     LEFT JOIN ( SELECT "ml"."resident_id",
            "string_agg"("concat"(COALESCE("med_db"."generic_name", ''::"text"), ' (', COALESCE("med_db"."brand_name", ''::"text"), ') : ', COALESCE("tag_summary_1"."tags", ''::"text")), "chr"(10)) AS "tag_summary"
           FROM (("public"."medicine_List" "ml"
             LEFT JOIN "public"."med_DB" "med_db" ON (("ml"."med_DB_id" = "med_db"."id")))
             LEFT JOIN ( SELECT "mt"."med_list_id",
                    "string_agg"("mt"."tag", ', '::"text") AS "tags"
                   FROM "public"."medicine_tag" "mt"
                  GROUP BY "mt"."med_list_id") "tag_summary_1" ON (("tag_summary_1"."med_list_id" = "ml"."id")))
          WHERE ("tag_summary_1"."tags" IS NOT NULL)
          GROUP BY "ml"."resident_id") "tag_summary" ON (("r"."id" = "tag_summary"."resident_id")))
     LEFT JOIN ( SELECT "A_Med_logs"."resident_id",
            "string_agg"((("to_char"("A_Med_logs"."created_at", 'DD/MM HH24:MI'::"text") || ' - '::"text") || "user_info"."nickname"), '; '::"text") AS "arrangement_details"
           FROM ("public"."A_Med_logs"
             LEFT JOIN "public"."user_info" ON (("A_Med_logs"."ArrangeMed_by" = "user_info"."id")))
          WHERE ("A_Med_logs"."Created_Date" = CURRENT_DATE)
          GROUP BY "A_Med_logs"."resident_id") "arrange_med_today" ON (("r"."id" = "arrange_med_today"."resident_id")))
     LEFT JOIN LATERAL ( SELECT "rel"."id" AS "relative_id",
            "rel"."r_name_surname",
            "rel"."r_phone",
            "rel"."key_person",
            "rel"."r_nickname"
           FROM ("public"."resident_relatives" "rr"
             JOIN "public"."relatives" "rel" ON (("rr"."relatives_id" = "rel"."id")))
          WHERE ("rr"."resident_id" = "r"."id")
          ORDER BY "rel"."id"
         LIMIT 1) "first_rel" ON (true))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("r"."nursinghome_id" = "nh"."id")))
     LEFT JOIN "public"."resident_diseases_view" "rdv" ON (("r"."id" = "rdv"."resident_id")))
     LEFT JOIN "public"."resident_programs_view" "rpv" ON (("r"."id" = "rpv"."resident_id")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("r"."s_zone" = "nz"."id")))
     LEFT JOIN "subject_sets" "ss" ON (("ss"."resident_id" = "r"."id")))
     LEFT JOIN LATERAL ( SELECT "vs"."shift",
            "vs"."created_at",
            "vs"."Sent"
           FROM "public"."vitalSign" "vs"
          WHERE ("vs"."resident_id" = "r"."id")
          ORDER BY "vs"."created_at" DESC
         LIMIT 1) "last_vs" ON (true))
     LEFT JOIN LATERAL ( SELECT "vs"."vital_signs_status",
            "vs"."id" AS "latest_vital_sign_id",
            "vs"."created_at" AS "latest_vital_sign_date",
            "vs"."user_nickname"
           FROM "public"."combined_vitalsign_details_view" "vs"
          WHERE ("vs"."resident_id" = "r"."id")
          ORDER BY "vs"."created_at" DESC
         LIMIT 1) "cvs" ON (true))
     LEFT JOIN LATERAL ( SELECT "mh"."created_at" AS "latest_med_history_created_at"
           FROM ("public"."med_history" "mh"
             JOIN "public"."medicine_List" "ml" ON (("mh"."med_list_id" = "ml"."id")))
          WHERE ("ml"."resident_id" = "r"."id")
          ORDER BY "mh"."created_at" DESC
         LIMIT 1) "lmh" ON (true))
     LEFT JOIN LATERAL ( SELECT "mlwn"."user_nickname_arrangemed"
           FROM "public"."med_logs_with_nickname" "mlwn"
          WHERE (("mlwn"."resident_id" = "r"."id") AND (NULLIF("mlwn"."user_nickname_arrangemed", ''::"text") IS NOT NULL))
          ORDER BY "mlwn"."created_at" DESC
         LIMIT 1) "latest_arrangemed" ON (true))
     LEFT JOIN LATERAL ( SELECT "string_agg"("concat"("to_char"(("A_Med_Error_Log"."CalendarDate")::timestamp with time zone, 'DD/MM/YYYY'::"text"), ' ', "A_Med_Error_Log"."meal", ': ', "A_Med_Error_Log"."reply_nurseMark"), "chr"(10)) AS "correct_summary"
           FROM "public"."A_Med_Error_Log"
          WHERE ((("A_Med_Error_Log"."CalendarDate" >= (CURRENT_DATE - '1 day'::interval)) AND ("A_Med_Error_Log"."CalendarDate" <= (CURRENT_DATE + '1 day'::interval))) AND ("A_Med_Error_Log"."reply_nurseMark" = ANY (ARRAY['รูปไม่ตรง'::"text", 'ไม่มีรูป'::"text", 'ตำแหน่งสลับ'::"text"])) AND ("A_Med_Error_Log"."resident_id" = "r"."id"))) "current_day_med_correct_summary" ON (true))
     LEFT JOIN ( SELECT "ms"."resident_id",
            "count"(*) FILTER (WHERE ("ms"."status" = 'on'::"text")) AS "on_count",
            "count"(*) AS "total_count",
            "bool_or"("ms"."run_out_within_15_days") AS "run_out_within_15_days",
            "bool_or"("ms"."run_out_within_7_days") AS "run_out_within_7_days"
           FROM "public"."medicine_summary" "ms"
          GROUP BY "ms"."resident_id") "med_summary" ON (("r"."id" = "med_summary"."resident_id")))
     LEFT JOIN LATERAL ( SELECT "rlg"."line_group_id"
           FROM "public"."resident_line_group_id" "rlg"
          WHERE (("rlg"."resident_id" = "r"."id") AND ("rlg"."line_group_id" IS NOT NULL) AND ("btrim"("rlg"."line_group_id") <> ''::"text"))
          ORDER BY "rlg"."created_at" DESC, "rlg"."id" DESC
         LIMIT 1) "rlgi" ON (true))
  GROUP BY "r"."id", "r"."nursinghome_id", "r"."i_Name_Surname", "r"."i_National_ID_num", "r"."i_DOB", "r"."i_gender", "r"."i_picture_url", "r"."m_past_history", "r"."m_dietary", "r"."m_fooddrug_allergy", "r"."s_status", "r"."s_bed", "r"."s_reason_being_here", "r"."s_contract_date", "r"."s_special_status", "nh"."name", "rdv"."diseases", "rpv"."programs", "nz"."zone", "nz"."id", "cvs"."vital_signs_status", "r"."DTX/insulin", "r"."Report_Amount", "cvs"."latest_vital_sign_date", "cvs"."latest_vital_sign_id", "last_vs"."Sent", "cvs"."user_nickname", "lmh"."latest_med_history_created_at", "first_rel"."r_name_surname", "first_rel"."r_phone", "first_rel"."r_nickname", "latest_arrangemed"."user_nickname_arrangemed", "med_error_summary"."error_summary", "tag_summary"."tag_summary", "arrange_med_today"."arrangement_details", "current_day_med_correct_summary"."correct_summary", "med_summary"."run_out_within_15_days", "med_summary"."run_out_within_7_days", "ss"."subject_ids_morning_shift", "ss"."subject_ids_night_shift", "ss"."morning_shift_relation_ids", "ss"."night_shift_relation_ids", "rlgi"."line_group_id";


ALTER TABLE "public"."combined_resident_details_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ddRecordWithCalendar_Clock" WITH ("security_invoker"='on') AS
 SELECT "ddr"."id" AS "dd_id",
    "ddr"."created_at",
    "ddr"."user_id",
    "ui"."full_name" AS "dd_user_name",
    "ui"."nickname" AS "dd_user_nickname",
    "ui"."prefix" AS "dd_user_prefix",
    "ui"."photo_url" AS "dd_user_photo",
    "ddr"."aproover_id",
    "ddr"."calendar_appointment_id",
    "ddr"."calendar_bill_id",
    "cca"."Title" AS "appointment_title",
    "cca"."Description" AS "appointment_description",
    "cca"."Type" AS "appointment_type",
    "cca"."dateTime" AS "appointment_datetime",
    "cca"."nursinghome_id" AS "appointment_nursinghome_id",
    "cca"."resident_id" AS "appointment_resident_id",
    "cca"."creator_id" AS "appointment_creator_id",
    "cca"."isNPO" AS "appointment_isnpo",
    "cca"."hospital" AS "appointment_hospital",
    "cca"."isRelativePaidIn" AS "appointment_isrelativepaidin",
    "cca"."relativePaidDate" AS "appointment_relativepaiddate",
    "cca"."isDocumentPrepared" AS "appointment_isdocumentprepared",
    "cca"."isPostOnBoardAfter" AS "appointment_ispostonboardafter",
    "ccb"."Title" AS "bill_title",
    "ccb"."Type" AS "bill_type",
    "ccb"."dateTime" AS "bill_datetime",
    "ra"."i_Name_Surname" AS "appointment_resident_name",
    "rb"."i_Name_Surname" AS "bill_resident_name",
    "auca"."full_name" AS "appointment_creator_name",
    "auca"."nickname" AS "appointment_creator_nickname",
    "auca"."prefix" AS "appointment_creator_prefix",
    "auca"."photo_url" AS "appointment_creator_photo",
    "aucb"."full_name" AS "bill_creator_name",
    "aucb"."nickname" AS "bill_creator_nickname",
    "aucb"."prefix" AS "bill_creator_prefix",
    "aucb"."photo_url" AS "bill_creator_photo",
    "p"."id" AS "post_id",
    NULLIF("p"."Text", ''::"text") AS "post_title"
   FROM (((((((("public"."DD_Record_Clock" "ddr"
     LEFT JOIN "public"."user_info" "ui" ON (("ddr"."user_id" = "ui"."id")))
     LEFT JOIN "public"."C_Calendar" "cca" ON (("ddr"."calendar_appointment_id" = "cca"."id")))
     LEFT JOIN "public"."C_Calendar" "ccb" ON (("ddr"."calendar_bill_id" = "ccb"."id")))
     LEFT JOIN "public"."residents" "ra" ON (("cca"."resident_id" = "ra"."id")))
     LEFT JOIN "public"."residents" "rb" ON (("ccb"."resident_id" = "rb"."id")))
     LEFT JOIN "public"."user_info" "auca" ON (("cca"."creator_id" = "auca"."id")))
     LEFT JOIN "public"."user_info" "aucb" ON (("ccb"."creator_id" = "aucb"."id")))
     LEFT JOIN "public"."Post" "p" ON (("ddr"."id" = "p"."DD_id")));


ALTER TABLE "public"."ddRecordWithCalendar_Clock" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dummyFinishDutyTable" (
    "id" bigint NOT NULL,
    "start_time" timestamp with time zone,
    "title" "text",
    "duration_minutes" bigint
);


ALTER TABLE "public"."dummyFinishDutyTable" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invitations" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_email" "text",
    "nursinghome_ID" bigint
);


ALTER TABLE "public"."invitations" OWNER TO "postgres";


ALTER TABLE "public"."invitations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."invitations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."invitations_with_nursinghomes" WITH ("security_invoker"='on') AS
 SELECT "i"."id" AS "invitation_id",
    "i"."created_at" AS "invitation_created_at",
    "i"."user_email",
    "nh"."id" AS "nursinghome_id",
    "nh"."created_at" AS "nursinghome_created_at",
    "nh"."name" AS "nursinghome_name",
    "nh"."report_times" AS "nursinghome_report_times",
    "nh"."pic_url" AS "nursinghome_pic_url",
    ("ui_match"."id" IS NOT NULL) AS "accepted_user_info"
   FROM (("public"."invitations" "i"
     JOIN "public"."nursinghomes" "nh" ON (("i"."nursinghome_ID" = "nh"."id")))
     LEFT JOIN "public"."user_info" "ui_match" ON ((("ui_match"."nursinghome_id" = "nh"."id") AND ("ui_match"."email" IS NOT NULL) AND ("lower"("ui_match"."email") = "lower"("i"."user_email")))));


ALTER TABLE "public"."invitations_with_nursinghomes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medMadeChange" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "list_OldList" bigint[],
    "list_NewList" bigint[],
    "appointment_id" bigint,
    "post_id" bigint
);


ALTER TABLE "public"."medMadeChange" OWNER TO "postgres";


ALTER TABLE "public"."medMadeChange" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."medMadeChange_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."med_db_search_view" WITH ("security_invoker"='on') AS
 SELECT "med_DB"."id",
    "med_DB"."created_at",
    "med_DB"."nursinghome_id",
    "med_DB"."brand_name",
    "med_DB"."generic_name",
    "med_DB"."str",
    "med_DB"."route",
    "med_DB"."unit",
    "med_DB"."info",
    "med_DB"."group",
    "med_DB"."pillpic_url",
    "concat_ws"(' '::"text", "med_DB"."generic_name", "med_DB"."brand_name", "med_DB"."str", "med_DB"."route", "med_DB"."unit", "med_DB"."info", "med_DB"."group") AS "search_text"
   FROM "public"."med_DB";


ALTER TABLE "public"."med_db_search_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."med_db_with_placeholders" WITH ("security_invoker"='on') AS
 SELECT "med"."id",
    "med"."created_at",
    "med"."nursinghome_id",
    "med"."brand_name",
    "med"."generic_name",
    "med"."str",
    "med"."route",
    "med"."unit",
    "med"."info",
    "med"."group",
    "med"."pillpic_url",
    COALESCE("med"."Front-Foiled", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Front-Foiled",
    COALESCE("med"."Back-Foiled", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Back-Foiled",
    COALESCE("med"."Front-Nude", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Front-Nude",
    COALESCE("med"."Back-Nude", 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/l5fiyutocar2/placeholder.png'::"text") AS "Back-Nude",
    ARRAY( SELECT DISTINCT "res"."id"
           FROM ("public"."medicine_List" "ml"
             JOIN "public"."residents" "res" ON (("ml"."resident_id" = "res"."id")))
          WHERE ("ml"."med_DB_id" = "med"."id")
          ORDER BY "res"."id") AS "resident_id_list",
    ARRAY( SELECT DISTINCT "res"."i_Name_Surname"
           FROM ("public"."medicine_List" "ml"
             JOIN "public"."residents" "res" ON (("ml"."resident_id" = "res"."id")))
          WHERE ("ml"."med_DB_id" = "med"."id")
          ORDER BY "res"."i_Name_Surname") AS "resident_name_list",
    ARRAY( SELECT DISTINCT "res"."s_status"
           FROM ("public"."medicine_List" "ml"
             JOIN "public"."residents" "res" ON (("ml"."resident_id" = "res"."id")))
          WHERE ("ml"."med_DB_id" = "med"."id")
          ORDER BY "res"."s_status") AS "resident_status_list"
   FROM "public"."med_DB" "med"
  GROUP BY "med"."id", "med"."created_at", "med"."nursinghome_id", "med"."brand_name", "med"."generic_name", "med"."str", "med"."route", "med"."unit", "med"."info", "med"."group", "med"."pillpic_url", "med"."Front-Foiled", "med"."Back-Foiled", "med"."Front-Nude", "med"."Back-Nude";


ALTER TABLE "public"."med_db_with_placeholders" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."med_db_with_residents" WITH ("security_invoker"='on') AS
 SELECT "m"."id" AS "med_db_id",
    "m"."nursinghome_id",
    "m"."brand_name",
    "m"."generic_name",
    "m"."str",
    "m"."route",
    "m"."unit",
    "m"."info",
    "m"."group",
    "m"."pillpic_url",
    "m"."Front-Foiled",
    "m"."Back-Foiled",
    "m"."Front-Nude",
    "m"."Back-Nude",
    "count"(DISTINCT "ml"."id") AS "total_medicine_list_rows",
    "count"(DISTINCT "r"."id") AS "total_residents",
    COALESCE("array_remove"("array_agg"(DISTINCT "r"."id"), NULL::bigint), '{}'::bigint[]) AS "resident_id_list",
    COALESCE("array_remove"("array_agg"(DISTINCT "r"."i_Name_Surname"), NULL::"text"), '{}'::"text"[]) AS "resident_name_list",
    COALESCE("jsonb_agg"(DISTINCT
        CASE
            WHEN ("r"."id" IS NULL) THEN NULL::"jsonb"
            ELSE "jsonb_build_object"('resident_id', "r"."id", 'name', "r"."i_Name_Surname", 'status', "r"."s_status", 'zone_id', "r"."s_zone")
        END) FILTER (WHERE ("r"."id" IS NOT NULL)), '[]'::"jsonb") AS "residents_detail"
   FROM (("public"."med_DB" "m"
     LEFT JOIN "public"."medicine_List" "ml" ON (("ml"."med_DB_id" = "m"."id")))
     LEFT JOIN "public"."residents" "r" ON ((("r"."id" = "ml"."resident_id") AND ("r"."s_status" = 'Stay'::"text"))))
  GROUP BY "m"."id", "m"."nursinghome_id", "m"."brand_name", "m"."generic_name", "m"."str", "m"."route", "m"."unit", "m"."info", "m"."group", "m"."pillpic_url", "m"."Front-Foiled", "m"."Back-Foiled", "m"."Front-Nude", "m"."Back-Nude";


ALTER TABLE "public"."med_db_with_residents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."med_example" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "med_query_term" "text"[],
    "example_pic_url" "text",
    "resident_id" bigint,
    "meal" "text",
    "med_log_start_id" bigint,
    "user_id" "uuid"
);


ALTER TABLE "public"."med_example" OWNER TO "postgres";


ALTER TABLE "public"."med_example" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."med_example_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."med_history" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."med_history_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."med_history_summary" WITH ("security_invoker"='on') AS
 SELECT "mh"."id" AS "med_history_id",
    "mh"."created_at" AS "med_history_created_at",
    "mh"."on_date",
    "mh"."off_date",
    "mh"."new_setting",
    "mh"."note" AS "med_history_note",
    "mh"."user_id",
    "mh"."reconcile",
    "ml"."id" AS "medicine_list_id",
    "ml"."created_at" AS "medicine_list_created_at",
    "ml"."med_DB_id" AS "med_db_id",
    "mdb"."brand_name",
    "mdb"."generic_name",
    "mdb"."str",
    "ui"."nickname" AS "user_nickname",
    "ui"."photo_url" AS "user_photo_url",
        CASE
            WHEN ("mh"."off_date" IS NULL) THEN 'active'::"text"
            WHEN ("mh"."off_date" < CURRENT_DATE) THEN 'discontinued'::"text"
            ELSE 'review needed'::"text"
        END AS "status"
   FROM (((("public"."med_history" "mh"
     JOIN "public"."medicine_List" "ml" ON (("mh"."med_list_id" = "ml"."id")))
     JOIN "public"."med_DB" "mdb" ON (("ml"."med_DB_id" = "mdb"."id")))
     JOIN "auth"."users" "u" ON (("mh"."user_id" = "u"."id")))
     JOIN "public"."user_info" "ui" ON (("u"."id" = "ui"."id")));


ALTER TABLE "public"."med_history_summary" OWNER TO "postgres";


ALTER TABLE "public"."medicine_List" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."medicine_List_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."medicine_tag" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."medicine_tag_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."quickSnap_picture" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uuid" "uuid",
    "pic_url" "text",
    "caption" "text"
);


ALTER TABLE "public"."quickSnap_picture" OWNER TO "postgres";


ALTER TABLE "public"."quickSnap_picture" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."my_Picture_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."n8n_agent_resident_profile" AS
SELECT
    NULL::bigint AS "nursinghome_id",
    NULL::bigint AS "resident_id",
    NULL::"text" AS "full_name",
    NULL::"text" AS "gender",
    NULL::integer AS "age",
    NULL::"text" AS "i_picture_url",
    NULL::"text" AS "s_special_status",
    NULL::"text" AS "underlying_diseases",
    NULL::"text" AS "past_history",
    NULL::"text" AS "dietary",
    NULL::"text" AS "chief_reason",
    NULL::"text" AS "program_list",
    NULL::"text" AS "med_responsible",
    NULL::"text" AS "hospital",
    NULL::"text" AS "social_security",
    NULL::"text" AS "allergy",
    NULL::boolean AS "is_processed",
    NULL::"text" AS "line_group_id",
    NULL::"text" AS "zone",
    NULL::timestamp with time zone AS "last_update";


ALTER TABLE "public"."n8n_agent_resident_profile" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."n8n_medicine_summary" WITH ("security_invoker"='on') AS
 WITH "med_status" AS (
         SELECT "ml"."id" AS "medicine_list_id",
            "ml"."med_DB_id",
            "ml"."resident_id",
            "r"."nursinghome_id",
            "r"."i_Name_Surname" AS "resident_name",
            "mdb"."brand_name",
            "mdb"."generic_name",
            "mdb"."str",
            "ml"."take_tab",
            "mdb"."route",
            COALESCE("ml"."BLDB", '{}'::"text"[]) AS "BLDB",
            COALESCE("ml"."BeforeAfter", '{}'::"text"[]) AS "BeforeAfter",
            COALESCE("ml"."every_hr", (1)::bigint) AS "every_hr",
                CASE
                    WHEN (("ml"."DaysOfWeek" IS NOT NULL) AND ("ml"."DaysOfWeek" <> '{}'::"text"[])) THEN 'สัปดาห์'::"text"
                    ELSE COALESCE("ml"."typeOfTime", 'วัน'::"text")
                END AS "typeOfTime",
            COALESCE("ml"."DaysOfWeek", '{}'::"text"[]) AS "DaysOfWeek",
            "ml"."prn",
            "on_evt"."on_date" AS "first_med_history_on_date",
            "last_evt"."off_date" AS "last_med_history_off_date",
                CASE
                    WHEN (("on_evt"."on_date" IS NOT NULL) AND ("on_evt"."on_date" > CURRENT_DATE)) THEN 'waiting'::"text"
                    WHEN ("last_evt"."off_date" IS NULL) THEN 'on'::"text"
                    WHEN ("last_evt"."off_date" >= CURRENT_DATE) THEN 'on'::"text"
                    ELSE 'off'::"text"
                END AS "status"
           FROM (((("public"."medicine_List" "ml"
             LEFT JOIN "public"."med_DB" "mdb" ON (("ml"."med_DB_id" = "mdb"."id")))
             LEFT JOIN "public"."residents" "r" ON (("ml"."resident_id" = "r"."id")))
             LEFT JOIN LATERAL ( SELECT "med_history"."on_date"
                   FROM "public"."med_history"
                  WHERE (("med_history"."med_list_id" = "ml"."id") AND ("med_history"."on_date" IS NOT NULL))
                  ORDER BY "med_history"."created_at" DESC
                 LIMIT 1) "on_evt" ON (true))
             LEFT JOIN LATERAL ( SELECT "med_history"."off_date"
                   FROM "public"."med_history"
                  WHERE ("med_history"."med_list_id" = "ml"."id")
                  ORDER BY "med_history"."created_at" DESC
                 LIMIT 1) "last_evt" ON (true))
        )
 SELECT "med_status"."medicine_list_id",
    "med_status"."med_DB_id",
    "med_status"."resident_id",
    "med_status"."nursinghome_id",
    "med_status"."resident_name",
    "med_status"."brand_name",
    "med_status"."generic_name",
    "med_status"."str",
    "med_status"."take_tab",
    "med_status"."route",
    "med_status"."BLDB",
    "med_status"."BeforeAfter",
    "med_status"."every_hr",
    "med_status"."typeOfTime",
    "med_status"."DaysOfWeek",
    "med_status"."prn",
    "med_status"."first_med_history_on_date",
    "med_status"."last_med_history_off_date",
    "med_status"."status"
   FROM "med_status"
  WHERE (("med_status"."status" = 'on'::"text") AND ("med_status"."prn" IS DISTINCT FROM true) AND ("med_status"."resident_id" IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM "public"."residents" "r2"
          WHERE (("r2"."id" = "med_status"."resident_id") AND ("r2"."s_status" = 'Stay'::"text")))));


ALTER TABLE "public"."n8n_medicine_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."new_manual_with_nickname" WITH ("security_invoker"='on') AS
 SELECT "nm"."id",
    "nm"."created_at",
    "nm"."title",
    "nm"."type",
    "nm"."created_by",
    "nm"."resident_id",
    "nm"."modified_by",
    "nm"."last_modified_at",
    "ui"."nickname" AS "created_by_nickname",
    "ui2"."nickname" AS "modified_by_nickname",
    "r"."i_Name_Surname" AS "resident_name"
   FROM ((("public"."New_Manual" "nm"
     LEFT JOIN "public"."user_info" "ui" ON (("nm"."created_by" = "ui"."id")))
     LEFT JOIN "public"."user_info" "ui2" ON (("nm"."modified_by" = "ui2"."id")))
     LEFT JOIN "public"."residents" "r" ON (("nm"."resident_id" = "r"."id")));


ALTER TABLE "public"."new_manual_with_nickname" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "user_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "is_read" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


ALTER TABLE "public"."notifications" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."notifications_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."nursinghome_zone" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."nursinghome_zone_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."nursinghome_zone_not_done_task" WITH ("security_invoker"='on') AS
 SELECT "task"."nursinghome_id",
    "resident"."s_zone" AS "zone_id",
    "nz"."zone" AS "zone_name",
    ("log"."created_at")::"date" AS "adjust_date",
    "count"(*) AS "number_of_not_done_tasks"
   FROM ((("public"."A_Task_logs_ver2" "log"
     LEFT JOIN "public"."A_Tasks" "task" ON (("log"."task_id" = "task"."id")))
     LEFT JOIN "public"."residents" "resident" ON (("task"."resident_id" = "resident"."id")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("resident"."s_zone" = "nz"."id")))
  WHERE ("log"."status" IS NULL)
  GROUP BY "task"."nursinghome_id", "resident"."s_zone", "nz"."zone", (("log"."created_at")::"date");


ALTER TABLE "public"."nursinghome_zone_not_done_task" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."nursinghome_zone_resident_count" AS
SELECT
    NULL::bigint AS "zone_id",
    NULL::"text" AS "zone_name",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "nursinghome_name",
    NULL::bigint AS "resident_count";


ALTER TABLE "public"."nursinghome_zone_resident_count" OWNER TO "postgres";


ALTER TABLE "public"."nursinghomes" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."nursinghomes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."pastel_color" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "color" "text"
);


ALTER TABLE "public"."pastel_color" OWNER TO "postgres";


ALTER TABLE "public"."pastel_color" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."pastel color_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."patient_status" (
    "id" bigint NOT NULL,
    "resident_id" bigint NOT NULL,
    "info_type" "text" NOT NULL,
    "description" "text" NOT NULL,
    "source_table" "text",
    "source_id" bigint,
    "generated_by" "uuid" DEFAULT "auth"."uid"(),
    "generated_at" timestamp with time zone DEFAULT "now"(),
    "approved_by" "uuid",
    "approved_at" timestamp with time zone,
    "is_active" boolean DEFAULT true,
    "set_previous_variation_to_false" bigint
);


ALTER TABLE "public"."patient_status" OWNER TO "postgres";


ALTER TABLE "public"."patient_status" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."patient_status_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."postDoneBy" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "post_id" bigint,
    "user_id" "uuid"
);


ALTER TABLE "public"."postDoneBy" OWNER TO "postgres";


ALTER TABLE "public"."postDoneBy" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."postDoneBy_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."postReferenceId" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "post_id" bigint,
    "task_id" bigint
);


ALTER TABLE "public"."postReferenceId" OWNER TO "postgres";


ALTER TABLE "public"."postReferenceId" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."postReferenceId_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."post_tab_likes_14d" WITH ("security_invoker"='on') AS
 WITH "tags_agg" AS (
         SELECT "pt"."Post_id" AS "post_id",
            ("array_agg"("tl"."tab" ORDER BY
                CASE
                    WHEN ("lower"("tl"."tab") = 'announcements-critical'::"text") THEN 1
                    WHEN ("lower"("tl"."tab") = 'announcements-policy'::"text") THEN 2
                    WHEN ("lower"("tl"."tab") = 'announcements-info'::"text") THEN 3
                    WHEN ("lower"("tl"."tab") = 'calendar'::"text") THEN 4
                    WHEN ("lower"("tl"."tab") = 'fyi'::"text") THEN 5
                    ELSE 999
                END, "tl"."tab") FILTER (WHERE (("tl"."tab" IS NOT NULL) AND ("lower"("tl"."tab") <> 'request'::"text"))))[1] AS "prioritized_tab"
           FROM ("public"."Post_Tags" "pt"
             JOIN "public"."TagsLabel" "tl" ON (("tl"."id" = "pt"."Tag_id")))
          GROUP BY "pt"."Post_id"
        ), "likes_agg" AS (
         SELECT "pl"."Post_id",
            "array_agg"(DISTINCT "pl"."user_id") AS "like_user_ids"
           FROM "public"."Post_likes" "pl"
          GROUP BY "pl"."Post_id"
        )
 SELECT COALESCE("tg"."prioritized_tab", 'FYI'::"text") AS "tab",
    "la"."like_user_ids",
    "p"."id" AS "post_id",
    "p"."created_at" AS "post_created_at",
    "p"."nursinghome_id"
   FROM (("public"."Post" "p"
     LEFT JOIN "tags_agg" "tg" ON (("tg"."post_id" = "p"."id")))
     LEFT JOIN "likes_agg" "la" ON (("la"."Post_id" = "p"."id")))
  WHERE ("p"."created_at" >= ("now"() - '14 days'::interval));


ALTER TABLE "public"."post_tab_likes_14d" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prn_post_queue" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "post_id" bigint,
    "status" "text"
);


ALTER TABLE "public"."prn_post_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_log_line_queue" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "log_id" bigint NOT NULL,
    "status" "text" DEFAULT 'waiting'::"text"
);


ALTER TABLE "public"."task_log_line_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user-QA" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "QA_id" bigint
);


ALTER TABLE "public"."user-QA" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_group" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "group" "text",
    "nursinghome_id" bigint
);


ALTER TABLE "public"."user_group" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."postwithuserinfo" WITH ("security_invoker"='on') AS
 WITH "likes_dedup" AS (
         SELECT DISTINCT ON ("pl"."Post_id", "pl"."user_id") "pl"."Post_id",
            "pl"."user_id",
            "uinfo"."nickname",
            "uinfo"."photo_url",
            "pl"."created_at",
            "pl"."id" AS "like_row_id"
           FROM ("public"."Post_likes" "pl"
             LEFT JOIN "public"."user_info" "uinfo" ON (("uinfo"."id" = "pl"."user_id")))
          ORDER BY "pl"."Post_id", "pl"."user_id", "pl"."created_at" DESC, "pl"."id" DESC
        ), "likes_agg" AS (
         SELECT "d"."Post_id",
            "array_agg"("d"."user_id" ORDER BY "d"."created_at" DESC, "d"."like_row_id" DESC) AS "like_user_ids",
            "array_agg"("d"."nickname" ORDER BY "d"."created_at" DESC, "d"."like_row_id" DESC) AS "like_user_nicknames",
            "array_agg"("d"."photo_url" ORDER BY "d"."created_at" DESC, "d"."like_row_id" DESC) AS "like_user_photo_urls",
            "count"(*) AS "like_count",
            ("array_agg"("d"."nickname" ORDER BY "d"."created_at" DESC, "d"."like_row_id" DESC))[1] AS "last_like_nickname",
            ("array_agg"("d"."photo_url" ORDER BY "d"."created_at" DESC, "d"."like_row_id" DESC))[1] AS "last_like_photo_url"
           FROM "likes_dedup" "d"
          GROUP BY "d"."Post_id"
        ), "tags_agg" AS (
         SELECT "pt"."Post_id" AS "post_id",
            "array_agg"(DISTINCT "tl"."tagName") AS "post_tags",
            "array_to_string"("array_agg"(DISTINCT "tl"."tagName"), ','::"text") AS "post_tags_string",
            COALESCE("bool_or"("tl"."Importent"), false) AS "Importent",
            "array_agg"(DISTINCT "tl"."tab") FILTER (WHERE (("tl"."tab" IS NOT NULL) AND ("lower"("tl"."tab") <> 'request'::"text"))) AS "post_tabs_raw",
            ("array_agg"("tl"."tab" ORDER BY
                CASE
                    WHEN ("lower"("tl"."tab") = 'announcements-critical'::"text") THEN 1
                    WHEN ("lower"("tl"."tab") = 'announcements-policy'::"text") THEN 2
                    WHEN ("lower"("tl"."tab") = 'announcements-info'::"text") THEN 3
                    WHEN ("lower"("tl"."tab") = 'calendar'::"text") THEN 4
                    WHEN ("lower"("tl"."tab") = 'fyi'::"text") THEN 5
                    ELSE 999
                END, "tl"."tab") FILTER (WHERE (("tl"."tab" IS NOT NULL) AND ("lower"("tl"."tab") <> 'request'::"text"))))[1] AS "prioritized_tab"
           FROM ("public"."Post_Tags" "pt"
             JOIN "public"."TagsLabel" "tl" ON (("tl"."id" = "pt"."Tag_id")))
          GROUP BY "pt"."Post_id"
        ), "calendar_agg" AS (
         SELECT "C_Calendar_with_Post"."PostId" AS "post_id",
            "array_agg"(DISTINCT "C_Calendar_with_Post"."CalendarId") AS "calendar_ids"
           FROM "public"."C_Calendar_with_Post"
          GROUP BY "C_Calendar_with_Post"."PostId"
        ), "tagged_agg" AS (
         SELECT "p_1"."id" AS "post_id",
            COALESCE("array_length"("p_1"."tagged_user", 1), 0) AS "number_of_tagged_users",
            "array_agg"(DISTINCT "ui_tagged"."nickname") FILTER (WHERE ("ui_tagged"."nickname" IS NOT NULL)) AS "tagged_user_nicknames"
           FROM (("public"."Post" "p_1"
             LEFT JOIN LATERAL "unnest"("p_1"."tagged_user") "tu"("tagged_user_id") ON (true))
             LEFT JOIN "public"."user_info" "ui_tagged" ON (("ui_tagged"."id" = "tu"."tagged_user_id")))
          GROUP BY "p_1"."id", "p_1"."tagged_user"
        ), "last_log" AS (
         SELECT DISTINCT ON ("A_Task_logs_ver2"."post_id") "A_Task_logs_ver2"."post_id",
            "A_Task_logs_ver2"."id",
            "A_Task_logs_ver2"."created_at"
           FROM "public"."A_Task_logs_ver2"
          WHERE ("A_Task_logs_ver2"."post_id" IS NOT NULL)
          ORDER BY "A_Task_logs_ver2"."post_id", "A_Task_logs_ver2"."created_at" DESC, "A_Task_logs_ver2"."id" DESC
        ), "task_done_by_one" AS (
         SELECT DISTINCT ON ("pdb"."post_id") "pdb"."post_id",
            "ui_1"."nickname" AS "task_done_by_nickname",
            "ui_1"."id" AS "task_done_by_id"
           FROM ("public"."postDoneBy" "pdb"
             JOIN "public"."user_info" "ui_1" ON (("ui_1"."id" = "pdb"."user_id")))
          ORDER BY "pdb"."post_id", "pdb"."id" DESC
        ), "quest_accept_one" AS (
         SELECT DISTINCT ON ("pqa"."post_id") "pqa"."post_id",
            "ui_1"."nickname" AS "quest_accept_user_nickname",
            "ui_1"."id" AS "quest_accept_user_id"
           FROM ("public"."Post_Quest_Accept" "pqa"
             JOIN "public"."user_info" "ui_1" ON (("ui_1"."id" = "pqa"."user_id")))
          ORDER BY "pqa"."post_id", "pqa"."id" DESC
        ), "prn_queue_one" AS (
         SELECT DISTINCT ON ("pq_1"."post_id") "pq_1"."post_id",
            "pq_1"."status" AS "prn_status",
            "pq_1"."created_at" AS "prn_status_created_at",
            "pq_1"."id" AS "prn_queue_id"
           FROM "public"."prn_post_queue" "pq_1"
          ORDER BY "pq_1"."post_id", "pq_1"."created_at" DESC, "pq_1"."id" DESC
        ), "log_line_queue_one" AS (
         SELECT DISTINCT ON ("tq"."log_id") "tq"."log_id",
            "tq"."status" AS "log_line_status",
            "tq"."created_at" AS "log_line_status_created_at",
            "tq"."id" AS "log_line_queue_id"
           FROM "public"."task_log_line_queue" "tq"
          ORDER BY "tq"."log_id", "tq"."created_at" DESC, "tq"."id" DESC
        ), "qa_users_agg" AS (
         SELECT "uq"."QA_id" AS "qa_id",
            "array_agg"(DISTINCT "ui_1"."id") AS "qa_user_ids",
            "array_agg"(DISTINCT "ui_1"."full_name") FILTER (WHERE ("ui_1"."full_name" IS NOT NULL)) AS "qa_user_full_names",
            "array_agg"(DISTINCT "ui_1"."nickname") FILTER (WHERE ("ui_1"."nickname" IS NOT NULL)) AS "qa_user_nicknames",
            "array_agg"(DISTINCT "ui_1"."photo_url") FILTER (WHERE ("ui_1"."photo_url" IS NOT NULL)) AS "qa_user_photo_urls",
            "array_agg"(DISTINCT "ui_1"."group") AS "qa_user_group_ids",
            "array_agg"(DISTINCT "ug2"."group") FILTER (WHERE ("ug2"."group" IS NOT NULL)) AS "qa_user_group_names"
           FROM (("public"."user-QA" "uq"
             LEFT JOIN "public"."user_info" "ui_1" ON (("ui_1"."id" = "uq"."user_id")))
             LEFT JOIN "public"."user_group" "ug2" ON (("ug2"."id" = "ui_1"."group")))
          GROUP BY "uq"."QA_id"
        )
 SELECT "p"."id",
    "p"."created_at" AS "post_created_at",
    "date"("p"."created_at") AS "post_created_at_date",
    "p"."user_id",
    "p"."vitalSign_id",
    "p"."Text",
        CASE
            WHEN (NULLIF("btrim"("p"."title"), ''::"text") IS NOT NULL) THEN "p"."title"
            ELSE (SUBSTRING("btrim"("regexp_replace"("regexp_replace"(COALESCE("p"."Text", ''::"text"), '[\n\r\t]+'::"text", ' '::"text", 'g'::"text"), '\\s+'::"text", ' '::"text", 'g'::"text")) FROM 1 FOR 30) || '..'::"text")
        END AS "title",
    "p"."youtubeUrl",
    "p"."imgUrl",
    "p"."nursinghome_id",
    "p"."tagged_user",
    "p"."user_group_edit",
    "p"."user_group_id_edit",
    "p"."visible_to_relative",
    "p"."reply_to",
    "ui_reply"."photo_url" AS "reply_to_user_photo_url",
    "ui_reply"."nickname" AS "reply_to_user_nickname",
    "p_reply"."Text" AS "reply_to_post_text",
    "pr"."id" AS "post_resident_id",
    "res"."id" AS "resident_id",
    "nz"."id" AS "zone_id",
    "nz"."zone" AS "resident_zone",
    "res"."i_Name_Surname" AS "resident_name",
    "res"."i_picture_url" AS "resident_i_picture_url",
    "res"."s_special_status" AS "resident_s_special_status",
    "res"."underlying_disease_list" AS "resident_underlying_disease_list",
    COALESCE("tg"."post_tags_string", ''::"text") AS "post_tags_string",
    "tg"."post_tags",
    COALESCE("tg"."post_tabs_raw", ARRAY['FYI'::"text"]) AS "post_tabs",
    "array_to_string"(COALESCE("tg"."post_tabs_raw", ARRAY['FYI'::"text"]), ','::"text") AS "post_tabs_string",
    COALESCE("tg"."prioritized_tab", 'FYI'::"text") AS "tab",
    "p"."multi_img_url",
        CASE
            WHEN ("p"."multi_img_url" IS NULL) THEN NULL::"text"[]
            ELSE ( SELECT "array_agg"(
                    CASE
                        WHEN ("strpos"("t"."u", '?'::"text") > 0) THEN ("t"."u" || '&width=52&height=60&quality=65&resize=cover&format=webp'::"text")
                        ELSE ("t"."u" || '?width=52&height=60&quality=65&resize=cover&format=webp'::"text")
                    END ORDER BY "t"."ord") AS "array_agg"
               FROM "unnest"("p"."multi_img_url") WITH ORDINALITY "t"("u", "ord"))
        END AS "multi_img_url_thumb",
    COALESCE("ta"."number_of_tagged_users", 0) AS "number_of_tagged_users",
    "ta"."tagged_user_nicknames",
    "ui"."nickname" AS "post_user_nickname",
    "ui"."photo_url",
    "ug"."group" AS "user_group",
    "la"."like_user_ids",
    "la"."like_user_nicknames",
    "la"."like_user_photo_urls",
    GREATEST((COALESCE("la"."like_count", (0)::bigint) - 1), (0)::bigint) AS "like_count_minus_one",
    "la"."last_like_nickname",
    "la"."last_like_photo_url",
    "res"."i_Name_Surname" AS "resident_name_dup_for_compat",
    "ca"."calendar_ids",
    "tdb"."task_done_by_nickname",
    "tdb"."task_done_by_id",
    "qa"."quest_accept_user_id",
    "qa"."quest_accept_user_nickname",
    ( SELECT "array_to_string"(ARRAY( SELECT "unnest"(COALESCE("ta"."tagged_user_nicknames", ARRAY[]::"text"[])) AS "unnest"
                EXCEPT
                 SELECT "unnest"(COALESCE("la"."like_user_nicknames", ARRAY[]::"text"[])) AS "unnest"), ','::"text") AS "array_to_string") AS "non_liked_tagged_nicknames",
    GREATEST("p"."created_at", COALESCE("p"."last_modified_at", '1970-01-01 00:00:00+07'::timestamp with time zone)) AS "latest_update_time",
    COALESCE("tg"."Importent", false) AS "Importent",
    "res"."s_status",
    "res"."s_special_status",
    "ll"."id" AS "log_id",
    "pq"."prn_status",
    "pq"."prn_status_created_at",
    "pq"."prn_queue_id",
    "lq"."log_line_status",
    "lq"."log_line_status_created_at",
    "lq"."log_line_queue_id",
    "p"."qa_id",
    "qt"."question" AS "qa_question",
    "qt"."choiceA" AS "qa_choice_a",
    "qt"."choiceB" AS "qa_choice_b",
    "qt"."choiceC" AS "qa_choice_c",
    "qt"."answer" AS "qa_answer",
    "qa_u"."qa_user_ids",
    "qa_u"."qa_user_full_names",
    "qa_u"."qa_user_nicknames",
    "qa_u"."qa_user_photo_urls",
    "qa_u"."qa_user_group_ids",
    "qa_u"."qa_user_group_names"
   FROM (((((((((((((((((("public"."Post" "p"
     LEFT JOIN "public"."user_info" "ui" ON (("ui"."id" = "p"."user_id")))
     LEFT JOIN "public"."user_group" "ug" ON (("ug"."id" = "ui"."group")))
     LEFT JOIN "public"."Post_Resident_id" "pr" ON (("pr"."Post_id" = "p"."id")))
     LEFT JOIN "public"."residents" "res" ON (("res"."id" = "pr"."resident_id")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("nz"."id" = "res"."s_zone")))
     LEFT JOIN "likes_agg" "la" ON (("la"."Post_id" = "p"."id")))
     LEFT JOIN "tags_agg" "tg" ON (("tg"."post_id" = "p"."id")))
     LEFT JOIN "calendar_agg" "ca" ON (("ca"."post_id" = "p"."id")))
     LEFT JOIN "tagged_agg" "ta" ON (("ta"."post_id" = "p"."id")))
     LEFT JOIN "task_done_by_one" "tdb" ON (("tdb"."post_id" = "p"."id")))
     LEFT JOIN "quest_accept_one" "qa" ON (("qa"."post_id" = "p"."id")))
     LEFT JOIN "public"."Post" "p_reply" ON (("p_reply"."id" = "p"."reply_to")))
     LEFT JOIN "public"."user_info" "ui_reply" ON (("ui_reply"."id" = "p_reply"."user_id")))
     LEFT JOIN "last_log" "ll" ON (("ll"."post_id" = "p"."id")))
     LEFT JOIN "prn_queue_one" "pq" ON (("pq"."post_id" = "p"."id")))
     LEFT JOIN "log_line_queue_one" "lq" ON (("lq"."log_id" = "ll"."id")))
     LEFT JOIN "public"."QATable" "qt" ON (("qt"."id" = "p"."qa_id")))
     LEFT JOIN "qa_users_agg" "qa_u" ON (("qa_u"."qa_id" = "p"."qa_id")));


ALTER TABLE "public"."postwithuserinfo" OWNER TO "postgres";


ALTER TABLE "public"."prn_post_queue" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."prn_post_queue_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "fcm_token" "text" NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."program_summary_daily" (
    "snapshot_date" "date" NOT NULL,
    "program_id" bigint NOT NULL,
    "program_name" "text" NOT NULL,
    "nursinghome_id" bigint NOT NULL,
    "member_count" integer NOT NULL,
    "resident_names" "text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."program_summary_daily" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."program_summary_view" AS
SELECT
    NULL::bigint AS "program_id",
    NULL::"text" AS "program_name",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "nursinghome_name",
    NULL::bigint AS "number_of_residents";


ALTER TABLE "public"."program_summary_view" OWNER TO "postgres";


ALTER TABLE "public"."programs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."programs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."quicksnap_picture_view" WITH ("security_invoker"='on') AS
 SELECT "q"."id",
    "q"."created_at",
    "q"."uuid",
    "u"."nickname" AS "user_nickname",
    "u"."full_name" AS "user_fullname",
    "u"."photo_url" AS "user_pic",
    "q"."pic_url",
    "q"."caption"
   FROM ("public"."quickSnap_picture" "q"
     LEFT JOIN "public"."user_info" "u" ON (("q"."uuid" = "u"."id")));


ALTER TABLE "public"."quicksnap_picture_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."relatives_with_resident_ids" WITH ("security_invoker"='true') AS
 SELECT "r"."id",
    "r"."created_at",
    "r"."r_name_surname",
    "r"."r_phone",
    "r"."r_detail",
    "r"."key_person",
    "r"."r_nickname",
    "r"."lineUserId",
    COALESCE("array_agg"("rr"."resident_id") FILTER (WHERE ("rr"."resident_id" IS NOT NULL)), '{}'::bigint[]) AS "resident_ids"
   FROM ("public"."relatives" "r"
     LEFT JOIN "public"."resident_relatives" "rr" ON (("r"."id" = "rr"."relatives_id")))
  GROUP BY "r"."id", "r"."created_at", "r"."r_name_surname", "r"."r_phone", "r"."r_detail", "r"."key_person", "r"."r_nickname", "r"."lineUserId";


ALTER TABLE "public"."relatives_with_resident_ids" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."report_subject_summary_view" AS
SELECT
    NULL::bigint AS "subject_id",
    NULL::"text" AS "subject_name",
    NULL::"text" AS "subject_description",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "nursinghome_name",
    NULL::bigint AS "number_of_reports",
    NULL::"text"[] AS "choices";


ALTER TABLE "public"."report_subject_summary_view" OWNER TO "postgres";


ALTER TABLE "public"."resident_relatives" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."resident&relatives_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."resident_basic_info_view" WITH ("security_invoker"='on') AS
 SELECT "r"."id" AS "resident_id",
    COALESCE("r"."i_Name_Surname", '-'::"text") AS "i_name_surname",
    COALESCE((EXTRACT(year FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."i_DOB")::timestamp with time zone)))::"text", '-'::"text") AS "age",
    COALESCE("r"."i_gender", '-'::"text") AS "i_gender",
    COALESCE(NULLIF("r"."i_picture_url", ''::"text"), 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/sign/user_Profile_Pic/profile%20blank.png'::"text") AS "i_picture_url",
    COALESCE("r"."zone_text", "nz"."zone", '-'::"text") AS "zone_name",
    COALESCE(("r"."s_zone")::"text", '-'::"text") AS "zone_id",
    COALESCE("r"."s_bed", '-'::"text") AS "s_bed",
    "r"."s_status",
    COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
        CASE
            WHEN ("age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone) < '1 mon'::interval) THEN "concat"(EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ว')
            WHEN ("age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone) < '1 year'::interval) THEN "concat"(EXTRACT(month FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ด ', EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ว')
            ELSE "concat"(EXTRACT(year FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ป ', EXTRACT(month FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ด ', EXTRACT(day FROM "age"((CURRENT_DATE)::timestamp with time zone, ("r"."s_contract_date")::timestamp with time zone)), 'ว')
        END AS "s_stay_period",
    COALESCE(ARRAY( SELECT "ud"."name"
           FROM ("public"."resident_underlying_disease" "rud"
             JOIN "public"."underlying_disease" "ud" ON (("rud"."underlying_id" = "ud"."id")))
          WHERE ("rud"."resident_id" = "r"."id")
          ORDER BY "rud"."id"), '{}'::"text"[]) AS "underlying_diseases_list",
    COALESCE(ARRAY( SELECT "p"."name"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::"text"[]) AS "programs_list"
   FROM ("public"."residents" "r"
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("r"."s_zone" = "nz"."id")))
  WHERE ("r"."s_status" = 'Stay'::"text");


ALTER TABLE "public"."resident_basic_info_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."resident_full_program_view" WITH ("security_invoker"='on') AS
 SELECT "r"."id",
    "r"."nursinghome_id",
    "r"."i_Name_Surname",
    "r"."i_National_ID_num",
    "r"."i_DOB",
    "r"."i_gender",
    "r"."i_picture_url",
    "r"."m_past_history",
    "r"."m_dietary",
    "r"."m_fooddrug_allergy",
    "r"."s_zone",
    "r"."s_bed",
    "r"."s_reason_being_here",
    "r"."s_contract_date",
    "r"."s_status",
    "r"."s_special_status",
    "r"."zone_text",
    "r"."underlying_disease_list",
    "r"."DTX/insulin",
    "r"."Report_Amount",
    "r"."Report_Scale_Day",
    "r"."Report_Scale_Night",
    "r"."โรงพยาบาล",
    "r"."SocialSecuruty",
    "r"."is_processed",
    "r"."created_at",
    "r"."updated_at",
    COALESCE(ARRAY( SELECT "p"."name"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::"text"[]) AS "program_names",
    COALESCE(ARRAY( SELECT "p"."program_pastel_color"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "p"."id"), '{}'::"text"[]) AS "program_colors",
    COALESCE(ARRAY( SELECT "rp"."program_id"
           FROM "public"."resident_programs" "rp"
          WHERE ("rp"."resident_id" = "r"."id")
          ORDER BY "rp"."program_id"), '{}'::bigint[]) AS "program_ids"
   FROM "public"."residents" "r";


ALTER TABLE "public"."resident_full_program_view" OWNER TO "postgres";


ALTER TABLE "public"."resident_line_group_id" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."resident_line_group_id_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."resident_programs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."resident_programs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."resident_ticket_status_view" WITH ("security_invoker"='on') AS
 SELECT "r"."id" AS "resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."i_picture_url",
    "r"."nursinghome_id",
    "r"."s_status" AS "resident_status",
    "r"."s_special_status" AS "resident_special_status",
    ( SELECT "array_agg"("bt"."id") AS "array_agg"
           FROM "public"."B_Ticket" "bt"
          WHERE ("bt"."resident_id" = "r"."id")) AS "ticket_ids",
    ( SELECT "count"(*) AS "count"
           FROM "public"."B_Ticket" "bt"
          WHERE ("bt"."resident_id" = "r"."id")) AS "number_of_tickets",
    (EXISTS ( SELECT 1
           FROM "public"."B_Ticket" "bt"
          WHERE (("bt"."resident_id" = "r"."id") AND ("bt"."status" = 'open'::"text")))) AS "opened_ticket"
   FROM "public"."residents" "r";


ALTER TABLE "public"."resident_ticket_status_view" OWNER TO "postgres";


ALTER TABLE "public"."resident_underlying_disease" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."resident_underlying_disease_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."residents" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."residents_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."scale_report_log_detailed_view" WITH ("security_invoker"='on') AS
 SELECT "srl"."id",
    "srl"."created_at",
    "srl"."vital_sign_id",
    "srl"."resident_id",
    "srl"."Subject_id" AS "subject_id",
    "rs"."Subject" AS "subject_text",
    "rs"."Description" AS "subject_description",
    "rc"."Scale" AS "choice_scale",
    "rc"."Choice" AS "choice_text",
    "rc"."represent_url",
    "vs"."shift" AS "vital_sign_shift"
   FROM ((("public"."Scale_Report_Log" "srl"
     JOIN "public"."Report_Subject" "rs" ON (("srl"."Subject_id" = "rs"."id")))
     JOIN "public"."Report_Choice" "rc" ON ((("rc"."Subject" = "srl"."Subject_id") AND ("rc"."Scale" = "srl"."Choice_id"))))
     JOIN "public"."vitalSign" "vs" ON (("srl"."vital_sign_id" = "vs"."id")));


ALTER TABLE "public"."scale_report_log_detailed_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."send_out_user_resident" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "resident_id" bigint
);


ALTER TABLE "public"."send_out_user_resident" OWNER TO "postgres";


ALTER TABLE "public"."send_out_user_resident" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."send_out_user_resident_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."soapnote_summary" WITH ("security_invoker"='on') AS
 SELECT "sn"."id",
    "sn"."created_at",
    "sn"."Subjective",
    "sn"."Objective",
    "sn"."Assessment",
    "sn"."Plan",
    "sn"."user_id",
    "sn"."resident_id",
    "sn"."time",
    "sn"."date",
    "sn"."type",
    "sn"."modified_at",
    "sn"."descriptive_Note",
    "sn"."ai_summary",
    "sn"."automation_status",
    "sn"."progression_2_times",
    "sn"."progression_7_days",
    "ui"."full_name",
    "ui"."nickname",
    "ui"."prefix",
    "ui"."photo_url",
    "r"."i_Name_Surname" AS "resident_name",
        CASE
            WHEN ("sn"."type" = 'กายภาพบำบัด'::"text") THEN '#FFF6BD'::"text"
            WHEN ("sn"."type" = 'แพทย์'::"text") THEN '#E3F4F4'::"text"
            WHEN ("sn"."type" = 'พยาบาล'::"text") THEN '#FDEBED'::"text"
            ELSE NULL::"text"
        END AS "type_color"
   FROM (("public"."SOAPNote" "sn"
     LEFT JOIN "public"."user_info" "ui" ON (("sn"."user_id" = "ui"."id")))
     LEFT JOIN "public"."residents" "r" ON (("sn"."resident_id" = "r"."id")));


ALTER TABLE "public"."soapnote_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tagslabel_with_usergroups" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "tag_id",
    "t"."created_at",
    "t"."nursinghome_id",
    "t"."tagName",
    COALESCE("t"."tab", 'FYI'::"text") AS "tab",
        CASE
            WHEN (COALESCE("t"."tab", 'FYI'::"text") = ANY (ARRAY['Announcements-Critical'::"text", 'Announcements-Policy'::"text", 'Announcements-Info'::"text"])) THEN 'Announcement'::"text"
            ELSE COALESCE("t"."tab", 'FYI'::"text")
        END AS "tab_group",
    COALESCE("array_agg"(DISTINCT "ug"."group") FILTER (WHERE ("ug"."id" IS NOT NULL)), '{}'::"text"[]) AS "user_groups",
    COALESCE("array_agg"(DISTINCT "ug"."id") FILTER (WHERE ("ug"."id" IS NOT NULL)), '{}'::bigint[]) AS "user_group_ids"
   FROM (("public"."TagsLabel" "t"
     LEFT JOIN "public"."Relation_TagTopic_UserGroup" "rtug" ON (("t"."id" = "rtug"."tagTopic")))
     LEFT JOIN "public"."user_group" "ug" ON (("rtug"."userGroup" = "ug"."id")))
  GROUP BY "t"."id", "t"."created_at", "t"."nursinghome_id", "t"."tagName", "t"."tab";


ALTER TABLE "public"."tagslabel_with_usergroups" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."task_log_line_queue_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."task_log_line_queue_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."task_log_line_queue_id_seq" OWNED BY "public"."task_log_line_queue"."id";



CREATE TABLE IF NOT EXISTS "public"."task_summary" (
    "id" bigint NOT NULL,
    "totaltasks" integer,
    "completedtasks" integer,
    "completionrate" "text",
    "totalpoints" integer,
    "topUsers" "jsonb"[],
    "timeBlock" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_summary" OWNER TO "postgres";


ALTER TABLE "public"."task_summary" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."task_summary_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."training_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "icon" "text",
    "image_url" "text",
    "requirement_type" "text" NOT NULL,
    "requirement_value" "jsonb" DEFAULT '{}'::"jsonb",
    "category" "text" DEFAULT 'general'::"text",
    "points" integer DEFAULT 10,
    "rarity" "text" DEFAULT 'common'::"text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "training_badges_rarity_check" CHECK (("rarity" = ANY (ARRAY['common'::"text", 'rare'::"text", 'epic'::"text", 'legendary'::"text"])))
);


ALTER TABLE "public"."training_badges" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_badges" IS 'รายชื่อ Badge ทั้งหมดและเงื่อนไขการได้รับ';



CREATE TABLE IF NOT EXISTS "public"."training_content" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "topic_id" "text" NOT NULL,
    "season_id" "uuid",
    "title" "text" NOT NULL,
    "content_markdown" "text" NOT NULL,
    "content_summary" "text",
    "reading_time_minutes" integer,
    "notion_page_id" "text",
    "notion_last_edited" timestamp with time zone,
    "version" integer DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "synced_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."training_content" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_content" IS 'เนื้อหาการอบรม sync จาก Notion ผ่าน n8n';



CREATE TABLE IF NOT EXISTS "public"."training_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "topic_id" "text" NOT NULL,
    "season_id" "uuid",
    "question_text" "text" NOT NULL,
    "question_image_url" "text",
    "choices" "jsonb" NOT NULL,
    "explanation" "text",
    "explanation_image_url" "text",
    "difficulty" integer DEFAULT 2,
    "thinking_type" "text",
    "tags" "text"[],
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "training_questions_difficulty_check" CHECK ((("difficulty" >= 1) AND ("difficulty" <= 3))),
    CONSTRAINT "training_questions_thinking_type_check" CHECK (("thinking_type" = ANY (ARRAY['analysis'::"text", 'prioritization'::"text", 'risk_assessment'::"text", 'reasoning'::"text", 'uncertainty'::"text"]))),
    CONSTRAINT "valid_choices" CHECK ((("jsonb_typeof"("choices") = 'array'::"text") AND ("jsonb_array_length"("choices") >= 2)))
);


ALTER TABLE "public"."training_questions" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_questions" IS 'คลังข้อสอบ ~200 ข้อต่อหัวข้อ สุ่ม 20 ข้อต่อ session';



CREATE TABLE IF NOT EXISTS "public"."training_quiz_answers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "selected_choice" "text",
    "is_correct" boolean,
    "answer_time_seconds" integer,
    "answered_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."training_quiz_answers" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_quiz_answers" IS 'คำตอบที่ผู้ใช้เลือกในแต่ละข้อ';



CREATE TABLE IF NOT EXISTS "public"."training_quiz_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "topic_id" "text" NOT NULL,
    "season_id" "uuid" NOT NULL,
    "progress_id" "uuid" NOT NULL,
    "quiz_type" "text" NOT NULL,
    "attempt_number" integer DEFAULT 1,
    "score" integer DEFAULT 0,
    "total_questions" integer DEFAULT 20,
    "passing_score" integer DEFAULT 16,
    "time_limit_seconds" integer DEFAULT 600,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    "is_passed" boolean GENERATED ALWAYS AS (
CASE
    WHEN ("completed_at" IS NOT NULL) THEN ("score" >= "passing_score")
    ELSE NULL::boolean
END) STORED,
    "duration_seconds" integer GENERATED ALWAYS AS (
CASE
    WHEN ("completed_at" IS NOT NULL) THEN (EXTRACT(epoch FROM ("completed_at" - "started_at")))::integer
    ELSE NULL::integer
END) STORED,
    "question_ids" "uuid"[] DEFAULT '{}'::"uuid"[],
    CONSTRAINT "training_quiz_sessions_quiz_type_check" CHECK (("quiz_type" = ANY (ARRAY['posttest'::"text", 'review'::"text"])))
);


ALTER TABLE "public"."training_quiz_sessions" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_quiz_sessions" IS 'ทุกครั้งที่กดเริ่มทำ Quiz จะสร้าง 1 Session';



COMMENT ON COLUMN "public"."training_quiz_sessions"."question_ids" IS 'Array ของ question IDs ที่สุ่มมาสำหรับ session นี้';



CREATE TABLE IF NOT EXISTS "public"."training_seasons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "is_active" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_date_range" CHECK (("end_date" > "start_date"))
);


ALTER TABLE "public"."training_seasons" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_seasons" IS 'ไตรมาสการวัดผล เมื่อขึ้น Season ใหม่ ทุกคนเริ่มนับใหม่';



CREATE TABLE IF NOT EXISTS "public"."training_streaks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "season_id" "uuid" NOT NULL,
    "current_streak" integer DEFAULT 0,
    "longest_streak" integer DEFAULT 0,
    "last_activity_date" "date",
    "weeks_with_weekend_activity" integer DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."training_streaks" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_streaks" IS 'สถิติการทำ Quiz ติดต่อกัน';



CREATE TABLE IF NOT EXISTS "public"."training_topics" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "Type" "text",
    "notion_url" "text",
    "cover_image_url" "text",
    "display_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "description" "text"
);


ALTER TABLE "public"."training_topics" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_topics" IS 'หัวข้อการอบรมทั้งหมด ใช้ Notion page ID เป็น PK';



CREATE TABLE IF NOT EXISTS "public"."training_user_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "badge_id" "uuid" NOT NULL,
    "season_id" "uuid",
    "earned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."training_user_badges" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_user_badges" IS 'Badge ที่แต่ละคนได้รับในแต่ละ Season';



CREATE TABLE IF NOT EXISTS "public"."training_user_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "topic_id" "text" NOT NULL,
    "season_id" "uuid" NOT NULL,
    "posttest_score" integer,
    "posttest_completed_at" timestamp with time zone,
    "posttest_attempts" integer DEFAULT 0,
    "posttest_last_attempt_at" timestamp with time zone,
    "last_review_score" integer,
    "last_review_at" timestamp with time zone,
    "next_review_at" timestamp with time zone,
    "review_count" integer DEFAULT 0,
    "content_read_at" timestamp with time zone,
    "content_read_count" integer DEFAULT 0,
    "mastery_level" "text" DEFAULT 'beginner'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "training_user_progress_mastery_level_check" CHECK (("mastery_level" = ANY (ARRAY['beginner'::"text", 'learning'::"text", 'competent'::"text", 'expert'::"text"])))
);


ALTER TABLE "public"."training_user_progress" OWNER TO "postgres";


COMMENT ON TABLE "public"."training_user_progress" IS 'ความก้าวหน้าของแต่ละคน ในแต่ละหัวข้อ ในแต่ละ Season';



CREATE OR REPLACE VIEW "public"."training_v_badges" WITH ("security_invoker"='on') AS
 SELECT "b"."id" AS "badge_id",
    "b"."name" AS "badge_name",
    "b"."description",
    "b"."icon",
    "b"."image_url",
    "b"."category",
    "b"."points",
    "b"."rarity",
    "b"."requirement_type",
    "b"."requirement_value",
    "ub"."user_id",
    "ub"."season_id",
        CASE
            WHEN ("ub"."id" IS NOT NULL) THEN true
            ELSE false
        END AS "is_earned",
    "ub"."earned_at"
   FROM ("public"."training_badges" "b"
     LEFT JOIN "public"."training_user_badges" "ub" ON (("ub"."badge_id" = "b"."id")))
  WHERE ("b"."is_active" = true)
  ORDER BY
        CASE "b"."rarity"
            WHEN 'legendary'::"text" THEN 1
            WHEN 'epic'::"text" THEN 2
            WHEN 'rare'::"text" THEN 3
            ELSE 4
        END, "b"."category", "b"."name";


ALTER TABLE "public"."training_v_badges" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_badges" IS 'Badge ทั้งหมด พร้อมสถานะว่า user ได้รับหรือยัง';



CREATE OR REPLACE VIEW "public"."training_v_leaderboard" WITH ("security_invoker"='on') AS
 WITH "user_scores" AS (
         SELECT "ui"."id" AS "user_id",
            "ui"."nickname",
            "ui"."photo_url",
            "s"."id" AS "season_id",
            "s"."name" AS "season_name",
            "count"(DISTINCT
                CASE
                    WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN "up"."topic_id"
                    ELSE NULL::"text"
                END) AS "topics_passed",
            COALESCE("round"("avg"("up"."posttest_score") FILTER (WHERE ("up"."posttest_completed_at" IS NOT NULL)), 1), (0)::numeric) AS "avg_score",
            (COALESCE("sum"("up"."review_count"), (0)::bigint))::integer AS "total_reviews",
            COALESCE("st"."current_streak", 0) AS "current_streak",
            COALESCE("st"."longest_streak", 0) AS "longest_streak",
            ( SELECT "count"(*) AS "count"
                   FROM "public"."training_user_badges" "ub"
                  WHERE (("ub"."user_id" = "ui"."id") AND (("ub"."season_id" = "s"."id") OR ("ub"."season_id" IS NULL)))) AS "badge_count",
            ((((("count"(DISTINCT
                CASE
                    WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN "up"."topic_id"
                    ELSE NULL::"text"
                END) * 100))::numeric + COALESCE("round"("avg"("up"."posttest_score") FILTER (WHERE ("up"."posttest_completed_at" IS NOT NULL)), 0), (0)::numeric)) + ((COALESCE("sum"("up"."review_count"), (0)::bigint) * 5))::numeric) + ((( SELECT "count"(*) AS "count"
                   FROM "public"."training_user_badges" "ub"
                  WHERE (("ub"."user_id" = "ui"."id") AND (("ub"."season_id" = "s"."id") OR ("ub"."season_id" IS NULL)))) * 10))::numeric) AS "total_score"
           FROM ((("public"."user_info" "ui"
             CROSS JOIN "public"."training_seasons" "s")
             LEFT JOIN "public"."training_user_progress" "up" ON ((("up"."user_id" = "ui"."id") AND ("up"."season_id" = "s"."id"))))
             LEFT JOIN "public"."training_streaks" "st" ON ((("st"."user_id" = "ui"."id") AND ("st"."season_id" = "s"."id"))))
          WHERE ("s"."is_active" = true)
          GROUP BY "ui"."id", "ui"."nickname", "ui"."photo_url", "s"."id", "s"."name", "st"."current_streak", "st"."longest_streak"
         HAVING ("count"(DISTINCT
                CASE
                    WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN "up"."topic_id"
                    ELSE NULL::"text"
                END) > 0)
        )
 SELECT "user_scores"."user_id",
    "user_scores"."nickname",
    "user_scores"."photo_url",
    "user_scores"."season_id",
    "user_scores"."season_name",
    "user_scores"."topics_passed",
    "user_scores"."avg_score",
    "user_scores"."total_reviews",
    "user_scores"."current_streak",
    "user_scores"."longest_streak",
    "user_scores"."badge_count",
    "user_scores"."total_score",
    "rank"() OVER (PARTITION BY "user_scores"."season_id" ORDER BY "user_scores"."total_score" DESC) AS "rank",
    ( SELECT "count"(*) AS "count"
           FROM "user_scores" "user_scores_1") AS "total_users"
   FROM "user_scores"
  ORDER BY "user_scores"."total_score" DESC;


ALTER TABLE "public"."training_v_leaderboard" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_leaderboard" IS 'อันดับผู้ใช้ สำหรับหน้า Leaderboard';



CREATE OR REPLACE VIEW "public"."training_v_needs_review" WITH ("security_invoker"='on') AS
 SELECT "up"."user_id",
    "ui"."nickname",
    "ui"."fcm_token",
    "t"."id" AS "topic_id",
    "t"."name" AS "topic_name",
    "t"."cover_image_url",
    "s"."id" AS "season_id",
    "s"."name" AS "season_name",
    "up"."next_review_at",
    "up"."mastery_level",
    "up"."last_review_score",
    "up"."review_count",
    GREATEST(0, (EXTRACT(day FROM ("now"() - "up"."next_review_at")))::integer) AS "days_overdue"
   FROM ((("public"."training_user_progress" "up"
     JOIN "public"."training_topics" "t" ON (("up"."topic_id" = "t"."id")))
     JOIN "public"."user_info" "ui" ON (("up"."user_id" = "ui"."id")))
     JOIN "public"."training_seasons" "s" ON (("up"."season_id" = "s"."id")))
  WHERE (("s"."is_active" = true) AND ("t"."is_active" = true) AND ("up"."posttest_completed_at" IS NOT NULL) AND ("up"."next_review_at" IS NOT NULL) AND ("up"."next_review_at" <= "now"()))
  ORDER BY "up"."next_review_at";


ALTER TABLE "public"."training_v_needs_review" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_needs_review" IS 'แสดง topics ที่ต้องทบทวน สำหรับส่ง notifications';



CREATE OR REPLACE VIEW "public"."training_v_quiz_history" WITH ("security_invoker"='on') AS
 SELECT "qs"."id" AS "session_id",
    "qs"."user_id",
    "qs"."topic_id",
    "t"."name" AS "topic_name",
    "t"."cover_image_url",
    "qs"."season_id",
    "s"."name" AS "season_name",
    "qs"."progress_id",
    "qs"."quiz_type",
    "qs"."attempt_number",
    "qs"."score",
    "qs"."total_questions",
    "qs"."passing_score",
    "qs"."is_passed",
    "qs"."time_limit_seconds",
    "qs"."duration_seconds",
    "qs"."started_at",
    "qs"."completed_at",
    "round"(((100.0 * ("qs"."score")::numeric) / (NULLIF("qs"."total_questions", 0))::numeric), 1) AS "score_percent",
    ( SELECT "jsonb_object_agg"("sub"."thinking_type", "jsonb_build_object"('total', "sub"."total", 'correct', "sub"."correct", 'percent', "round"(((100.0 * ("sub"."correct")::numeric) / (NULLIF("sub"."total", 0))::numeric), 1))) AS "jsonb_object_agg"
           FROM ( SELECT "q"."thinking_type",
                    "count"(*) AS "total",
                    "sum"(
                        CASE
                            WHEN "qa"."is_correct" THEN 1
                            ELSE 0
                        END) AS "correct"
                   FROM ("public"."training_quiz_answers" "qa"
                     JOIN "public"."training_questions" "q" ON (("qa"."question_id" = "q"."id")))
                  WHERE (("qa"."session_id" = "qs"."id") AND ("q"."thinking_type" IS NOT NULL))
                  GROUP BY "q"."thinking_type") "sub") AS "thinking_breakdown"
   FROM (("public"."training_quiz_sessions" "qs"
     JOIN "public"."training_topics" "t" ON (("qs"."topic_id" = "t"."id")))
     JOIN "public"."training_seasons" "s" ON (("qs"."season_id" = "s"."id")))
  WHERE ("qs"."completed_at" IS NOT NULL)
  ORDER BY "qs"."completed_at" DESC;


ALTER TABLE "public"."training_v_quiz_history" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_quiz_history" IS 'ประวัติการทำ quiz ของ user พร้อม thinking breakdown';



CREATE OR REPLACE VIEW "public"."training_v_thinking_analysis" WITH ("security_invoker"='on') AS
 SELECT "qs"."user_id",
    "qs"."season_id",
    "q"."thinking_type",
    "count"(*) AS "total_questions",
    "sum"(
        CASE
            WHEN "qa"."is_correct" THEN 1
            ELSE 0
        END) AS "correct_count",
    "round"(((100.0 * ("sum"(
        CASE
            WHEN "qa"."is_correct" THEN 1
            ELSE 0
        END))::numeric) / (NULLIF("count"(*), 0))::numeric), 1) AS "percent_correct"
   FROM (("public"."training_quiz_answers" "qa"
     JOIN "public"."training_questions" "q" ON (("qa"."question_id" = "q"."id")))
     JOIN "public"."training_quiz_sessions" "qs" ON (("qa"."session_id" = "qs"."id")))
  WHERE (("q"."thinking_type" IS NOT NULL) AND ("qs"."completed_at" IS NOT NULL))
  GROUP BY "qs"."user_id", "qs"."season_id", "q"."thinking_type"
  ORDER BY "qs"."user_id", "q"."thinking_type";


ALTER TABLE "public"."training_v_thinking_analysis" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_thinking_analysis" IS 'วิเคราะห์ประเภทการคิด สำหรับ Pentagon chart';



CREATE OR REPLACE VIEW "public"."training_v_topic_detail" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "topic_id",
    "t"."name" AS "topic_name",
    "t"."notion_url",
    "t"."cover_image_url",
    "t"."display_order",
    "c"."id" AS "content_id",
    "c"."title" AS "content_title",
    "c"."content_markdown",
    "c"."content_summary",
    "c"."reading_time_minutes",
    "c"."synced_at" AS "content_synced_at",
    "up"."user_id",
    "up"."season_id",
    "up"."id" AS "progress_id",
    COALESCE(("up"."content_read_at" IS NOT NULL), false) AS "is_read",
    COALESCE("up"."content_read_count", 0) AS "read_count",
    COALESCE(("up"."posttest_completed_at" IS NOT NULL), false) AS "is_passed",
        CASE
            WHEN (("up"."posttest_completed_at" IS NOT NULL) AND ("up"."next_review_at" IS NOT NULL) AND ("up"."next_review_at" <= "now"())) THEN 'review_due'::"text"
            WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN 'passed'::"text"
            WHEN ("up"."posttest_score" IS NOT NULL) THEN 'in_progress'::"text"
            ELSE 'not_started'::"text"
        END AS "quiz_status",
    "up"."posttest_score",
    "up"."last_review_score",
    COALESCE("up"."posttest_attempts", 0) AS "posttest_attempts",
    COALESCE("up"."review_count", 0) AS "review_count",
    COALESCE("up"."mastery_level", 'beginner'::"text") AS "mastery_level",
    "up"."content_read_at",
    "up"."posttest_completed_at",
    "up"."posttest_last_attempt_at",
    "up"."last_review_at",
    "up"."next_review_at",
    ( SELECT "count"(*) AS "count"
           FROM "public"."training_questions" "q"
          WHERE (("q"."topic_id" = "t"."id") AND ("q"."is_active" = true) AND (("q"."season_id" IS NULL) OR ("q"."season_id" = "up"."season_id")))) AS "question_count"
   FROM ((("public"."training_topics" "t"
     LEFT JOIN "public"."training_seasons" "s" ON (("s"."is_active" = true)))
     LEFT JOIN "public"."training_content" "c" ON ((("c"."topic_id" = "t"."id") AND ("c"."is_active" = true) AND (("c"."season_id" IS NULL) OR ("c"."season_id" = "s"."id")))))
     LEFT JOIN "public"."training_user_progress" "up" ON ((("up"."topic_id" = "t"."id") AND ("up"."season_id" = "s"."id"))))
  WHERE ("t"."is_active" = true);


ALTER TABLE "public"."training_v_topic_detail" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_topic_detail" IS 'รายละเอียด topic พร้อม content และ progress สำหรับหน้า Topic Detail';



CREATE OR REPLACE VIEW "public"."training_v_topics_with_progress" AS
 SELECT "t"."id" AS "topic_id",
    "t"."name" AS "topic_name",
    "t"."Type" AS "topic_type",
    "t"."notion_url",
    "t"."cover_image_url",
    "t"."display_order",
    "up"."id" AS "progress_id",
    "up"."user_id",
    "s"."id" AS "season_id",
    COALESCE(("up"."content_read_at" IS NOT NULL), false) AS "is_read",
    COALESCE("up"."content_read_count", 0) AS "read_count",
    "up"."content_read_at",
    COALESCE(("up"."posttest_completed_at" IS NOT NULL), false) AS "is_passed",
        CASE
            WHEN (("up"."posttest_completed_at" IS NOT NULL) AND ("up"."next_review_at" IS NOT NULL) AND ("up"."next_review_at" <= "now"())) THEN 'review_due'::"text"
            WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN 'passed'::"text"
            WHEN ("up"."posttest_score" IS NOT NULL) THEN 'in_progress'::"text"
            ELSE 'not_started'::"text"
        END AS "quiz_status",
    "up"."posttest_score",
    "up"."last_review_score",
    COALESCE("up"."posttest_attempts", 0) AS "posttest_attempts",
    COALESCE("up"."review_count", 0) AS "review_count",
    COALESCE("up"."mastery_level", 'beginner'::"text") AS "mastery_level",
    "up"."posttest_completed_at",
    "up"."posttest_last_attempt_at",
    "up"."last_review_at",
    "up"."next_review_at",
    "up"."updated_at" AS "progress_updated_at",
        CASE
            WHEN (("up"."posttest_completed_at" IS NOT NULL) AND ("up"."review_count" > 0)) THEN 100
            WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN 75
            WHEN ("up"."posttest_score" IS NOT NULL) THEN 50
            WHEN ("up"."content_read_at" IS NOT NULL) THEN 10
            ELSE 0
        END AS "progress_percent"
   FROM (("public"."training_topics" "t"
     CROSS JOIN "public"."training_seasons" "s")
     LEFT JOIN "public"."training_user_progress" "up" ON ((("t"."id" = "up"."topic_id") AND ("up"."season_id" = "s"."id"))))
  WHERE (("t"."is_active" = true) AND ("s"."is_active" = true))
  ORDER BY "t"."display_order", "t"."name";


ALTER TABLE "public"."training_v_topics_with_progress" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."training_v_user_stats" WITH ("security_invoker"='on') AS
 SELECT "ui"."id" AS "user_id",
    "ui"."nickname",
    "ui"."photo_url",
    "s"."id" AS "season_id",
    "s"."name" AS "season_name",
    ( SELECT "count"(*) AS "count"
           FROM "public"."training_topics"
          WHERE ("training_topics"."is_active" = true)) AS "total_topics",
    "count"(DISTINCT
        CASE
            WHEN ("up"."content_read_at" IS NOT NULL) THEN "up"."topic_id"
            ELSE NULL::"text"
        END) AS "topics_read",
    "count"(DISTINCT
        CASE
            WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN "up"."topic_id"
            ELSE NULL::"text"
        END) AS "topics_passed",
    "count"(DISTINCT
        CASE
            WHEN ("up"."next_review_at" <= "now"()) THEN "up"."topic_id"
            ELSE NULL::"text"
        END) AS "topics_need_review",
    "count"(DISTINCT
        CASE
            WHEN ("up"."mastery_level" = 'expert'::"text") THEN "up"."topic_id"
            ELSE NULL::"text"
        END) AS "topics_expert",
    "round"("avg"("up"."posttest_score") FILTER (WHERE ("up"."posttest_score" IS NOT NULL)), 1) AS "avg_posttest_score",
    "max"("up"."posttest_score") AS "best_posttest_score",
    (COALESCE("sum"("up"."posttest_attempts"), (0)::bigint))::integer AS "total_posttest_attempts",
    (COALESCE("sum"("up"."review_count"), (0)::bigint))::integer AS "total_reviews",
    (COALESCE("sum"("up"."content_read_count"), (0)::bigint))::integer AS "total_content_reads",
    COALESCE("st"."current_streak", 0) AS "current_streak",
    COALESCE("st"."longest_streak", 0) AS "longest_streak",
    "st"."last_activity_date",
    ( SELECT "count"(*) AS "count"
           FROM "public"."training_user_badges" "ub"
          WHERE (("ub"."user_id" = "ui"."id") AND (("ub"."season_id" = "s"."id") OR ("ub"."season_id" IS NULL)))) AS "badge_count",
    "round"(((100.0 * ("count"(DISTINCT
        CASE
            WHEN ("up"."posttest_completed_at" IS NOT NULL) THEN "up"."topic_id"
            ELSE NULL::"text"
        END))::numeric) / (NULLIF(( SELECT "count"(*) AS "count"
           FROM "public"."training_topics"
          WHERE ("training_topics"."is_active" = true)), 0))::numeric), 1) AS "completion_percent"
   FROM ((("public"."user_info" "ui"
     CROSS JOIN "public"."training_seasons" "s")
     LEFT JOIN "public"."training_user_progress" "up" ON ((("up"."user_id" = "ui"."id") AND ("up"."season_id" = "s"."id"))))
     LEFT JOIN "public"."training_streaks" "st" ON ((("st"."user_id" = "ui"."id") AND ("st"."season_id" = "s"."id"))))
  WHERE ("s"."is_active" = true)
  GROUP BY "ui"."id", "ui"."nickname", "ui"."photo_url", "s"."id", "s"."name", "st"."current_streak", "st"."longest_streak", "st"."last_activity_date";


ALTER TABLE "public"."training_v_user_stats" OWNER TO "postgres";


COMMENT ON VIEW "public"."training_v_user_stats" IS 'สถิติรวมของ user แต่ละคน สำหรับหน้า Profile/Dashboard';



CREATE TABLE IF NOT EXISTS "public"."trigger_schedule_snooze_log" (
    "id" bigint NOT NULL,
    "snooze_status" boolean NOT NULL,
    "additional_info" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."trigger_schedule_snooze_log" OWNER TO "postgres";


ALTER TABLE "public"."trigger_schedule_snooze_log" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."trigger_schedule_snooze_log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."tt_template_tasks" WITH ("security_invoker"='on') AS
 SELECT "t"."id",
    "t"."created_at",
    "t"."title",
    "t"."description",
    "t"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "t"."creator_id",
    "u_creator"."full_name" AS "creator_name",
    "t"."completed_by",
    "u_completed"."full_name" AS "completed_by_name",
    "t"."due_date",
    "t"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "t"."Subtask_of",
    "parent_task"."title" AS "parent_task_title",
    "t"."assign_to",
    "u_assign"."full_name" AS "assign_to_name",
    "t"."taskType",
    "t"."completed_at",
    "t"."calendar_id",
    "t"."ass_template_Ticket",
    "tt"."ticket_Title" AS "template_ticket_title",
    "parent_task"."form_url" AS "parent_task_form_url"
   FROM (((((((("public"."Template_Tasks" "t"
     LEFT JOIN "public"."residents" "r" ON (("t"."resident_id" = "r"."id")))
     LEFT JOIN "public"."user_info" "u_creator" ON (("t"."creator_id" = "u_creator"."id")))
     LEFT JOIN "public"."user_info" "u_completed" ON (("t"."completed_by" = "u_completed"."id")))
     LEFT JOIN "public"."user_info" "u_assign" ON (("t"."assign_to" = "u_assign"."id")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("t"."nursinghome_id" = "nh"."id")))
     LEFT JOIN "public"."A_Tasks" "parent_task" ON (("t"."Subtask_of" = "parent_task"."id")))
     LEFT JOIN "public"."C_Calendar" "c" ON (("t"."calendar_id" = "c"."id")))
     LEFT JOIN "public"."Template_Ticket" "tt" ON (("t"."ass_template_Ticket" = "tt"."id")));


ALTER TABLE "public"."tt_template_tasks" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tt_template_ticket" WITH ("security_invoker"='on') AS
 SELECT "tt"."id" AS "ticket_id",
    "tt"."ticket_Title",
    "tt"."ticket_Description",
    "tt"."created_at" AS "ticket_created_at",
    "tt"."nursinghome_id" AS "ticket_nursinghome_id",
    "tt"."created_by" AS "ticket_created_by",
    "tt"."assignee" AS "ticket_assignee",
    "tt"."source" AS "ticket_source",
    "tt"."follow_Up_Date",
    "tt"."status",
    "tt"."priority",
    "tt"."meeting_Agenda",
    COALESCE("array_agg"("tts"."id") FILTER (WHERE ("tts"."id" IS NOT NULL)), '{}'::bigint[]) AS "template_task_ids"
   FROM ("public"."Template_Ticket" "tt"
     LEFT JOIN "public"."Template_Tasks" "tts" ON (("tts"."ass_template_Ticket" = "tt"."id")))
  GROUP BY "tt"."id", "tt"."ticket_Title", "tt"."ticket_Description", "tt"."created_at", "tt"."nursinghome_id", "tt"."created_by", "tt"."assignee", "tt"."source", "tt"."follow_Up_Date", "tt"."status", "tt"."priority", "tt"."meeting_Agenda";


ALTER TABLE "public"."tt_template_ticket" OWNER TO "postgres";


ALTER TABLE "public"."underlying_disease" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."underlying_disease_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."underlying_disease_summary_view" AS
SELECT
    NULL::bigint AS "disease_id",
    NULL::"text" AS "disease_name",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "nursinghome_name",
    NULL::"text" AS "pastel_color",
    NULL::bigint AS "number_of_residents";


ALTER TABLE "public"."underlying_disease_summary_view" OWNER TO "postgres";


ALTER TABLE "public"."user-QA" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user-QA_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."user_group" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_group_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."user_with_user_group" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "user_group_id" bigint
);


ALTER TABLE "public"."user_with_user_group" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_info_with_nursinghomes" WITH ("security_invoker"='on') AS
 SELECT DISTINCT ON ("u"."id") "u"."id" AS "user_id",
    "u"."created_at" AS "user_created_at",
    "u"."email" AS "user_email",
    "u"."full_name",
    "u"."nickname",
    "u"."photo_url",
    "u"."phone_number",
    "u"."prefix",
    "u"."about_me",
    "u"."bank",
    "u"."bank_account",
    "u"."english_name",
    "u"."line_ID",
    "u"."DOB_staff",
    "u"."gender",
    "u"."underlying_disease_staff",
    "u"."education_degree",
    "u"."national_ID_staff",
    "u"."user_role",
    "u"."boardSubscription",
    "u"."snooze",
    "u"."appVersion",
    "u"."buildNumber",
    "u"."packageName",
    "u"."platform",
    "nh"."id" AS "nursinghome_id",
    "nh"."created_at" AS "nursinghome_created_at",
    "nh"."name" AS "nursinghome_name",
    "nh"."report_times" AS "nursinghome_report_times",
    "nh"."pic_url" AS "nursinghome_pic_url",
    ("inv"."id" IS NOT NULL) AS "has_invitation",
    ("u"."nursinghome_id" IS NOT NULL) AS "linked_to_nursinghome",
    COALESCE("r"."resident_stay_count", (0)::bigint) AS "resident_stay_count",
    COALESCE("ug"."user_group", ''::"text") AS "user_group",
    COALESCE("pt"."total_points", (0)::bigint) AS "total_points",
    COALESCE("current_shift_type"."shift_type", NULL::"text") AS "current_shift_type",
    COALESCE("current_shift_type"."selected_resident_id_list", NULL::bigint[]) AS "selected_resident_id_list",
    COALESCE("current_shift_type"."selected_break_time", NULL::bigint[]) AS "selected_break_time",
    "concat"(
        CASE
            WHEN ("u"."nickname" IS NOT NULL) THEN (('('::"text" || "u"."nickname") || ') '::"text")
            ELSE ''::"text"
        END, COALESCE("u"."prefix", ''::"text"), ' ', COALESCE("u"."full_name", ''::"text")) AS "concatenated_name",
    (EXISTS ( SELECT 1
           FROM "public"."clock_in_out_summary" "cio"
          WHERE (("cio"."user_id" = "u"."id") AND ("cio"."nursinghome_id" = "nh"."id") AND ("cio"."clock_out_time" IS NULL) AND ("cio"."is_manual_add_deduct" = false)))) AS "is_currently_working",
    (EXISTS ( SELECT 1
           FROM "public"."clock_in_out_summary" "cio"
          WHERE (("cio"."user_id" = "u"."id") AND ("cio"."nursinghome_id" = "nh"."id") AND ("cio"."clock_out_time" IS NULL) AND ("cio"."Incharge" = true) AND ("cio"."is_manual_add_deduct" = false)))) AS "is_incharge"
   FROM (((((("public"."user_info" "u"
     LEFT JOIN "public"."nursinghomes" "nh" ON (("u"."nursinghome_id" = "nh"."id")))
     LEFT JOIN "public"."invitations" "inv" ON (("u"."email" = "inv"."user_email")))
     LEFT JOIN LATERAL ( SELECT "cio"."shift_type",
            "cio"."selected_resident_id_list",
            "cio"."selected_break_time"
           FROM "public"."clock_in_out_summary" "cio"
          WHERE (("cio"."user_id" = "u"."id") AND ("cio"."nursinghome_id" = "nh"."id") AND ("cio"."clock_out_time" IS NULL) AND ("cio"."is_manual_add_deduct" = false))
          ORDER BY "cio"."clock_in_time" DESC
         LIMIT 1) "current_shift_type" ON (true))
     LEFT JOIN LATERAL ( SELECT "count"("residents"."id") AS "resident_stay_count"
           FROM "public"."residents"
          WHERE (("residents"."s_status" = 'Stay'::"text") AND ("residents"."nursinghome_id" = "nh"."id"))) "r" ON (true))
     LEFT JOIN LATERAL ( SELECT "string_agg"("ug_1"."group", ', '::"text") AS "user_group"
           FROM ("public"."user_with_user_group" "uwug"
             JOIN "public"."user_group" "ug_1" ON (("uwug"."user_group_id" = "ug_1"."id")))
          WHERE ("uwug"."user_id" = "u"."id")) "ug" ON (true))
     LEFT JOIN LATERAL ( SELECT "sum"("Point_Transaction"."point_change") AS "total_points"
           FROM "public"."Point_Transaction"
          WHERE ("Point_Transaction"."user_id" = "u"."id")) "pt" ON (true))
  ORDER BY "u"."id", "nh"."created_at" DESC;


ALTER TABLE "public"."user_info_with_nursinghomes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_points_with_info" WITH ("security_invoker"='on') AS
 SELECT "ui"."id",
    "ui"."full_name",
    "ui"."nickname",
    "ui"."photo_url",
    "ui"."user_role" AS "admin_type",
    "ui"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    COALESCE("sum"("pt"."point_change"), (0)::bigint) AS "total_points"
   FROM (("public"."user_info" "ui"
     LEFT JOIN "public"."Point_Transaction" "pt" ON (("ui"."id" = "pt"."user_id")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("ui"."nursinghome_id" = "nh"."id")))
  GROUP BY "ui"."id", "ui"."full_name", "ui"."nickname", "ui"."photo_url", "ui"."user_role", "ui"."nursinghome_id", "nh"."name";


ALTER TABLE "public"."user_points_with_info" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_task_seen" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "text",
    "Task_seen_id" bigint
);


ALTER TABLE "public"."user_task_seen" OWNER TO "postgres";


ALTER TABLE "public"."user_task_seen" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_task_seen_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."user_with_user_group" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_with_user_group_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."users_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "role_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."users_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v2_task_logs_with_daily_aggregation" WITH ("security_invoker"='on') AS
 SELECT ("log"."created_at")::"date" AS "adjust_date",
    "repeat"."startTme",
    "repeat"."timeBlock",
    "task"."nursinghome_id",
    "count"("log"."id") AS "task_count",
    "string_agg"(DISTINCT "task"."form_url", ', '::"text") AS "form_urls",
    "sum"(
        CASE
            WHEN ("log"."completed_at" IS NULL) THEN 0
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (15)::numeric) THEN 50
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (30)::numeric) THEN 36
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (45)::numeric) THEN 24
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (60)::numeric) THEN 14
            ELSE 5
        END) AS "sum_time_difference_value"
   FROM (((("public"."A_Task_logs_ver2" "log"
     LEFT JOIN "public"."A_Tasks" "task" ON (("log"."task_id" = "task"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "repeat" ON (("log"."Task_Repeat_Id" = "repeat"."id")))
     LEFT JOIN "public"."user_info" "u" ON (("log"."completed_by" = "u"."id")))
     LEFT JOIN "public"."residents" "resident" ON (("task"."resident_id" = "resident"."id")))
  GROUP BY (("log"."created_at")::"date"), "repeat"."startTme", "repeat"."timeBlock", "task"."nursinghome_id"
  ORDER BY (("log"."created_at")::"date"), "repeat"."startTme", "repeat"."timeBlock", "task"."nursinghome_id";


ALTER TABLE "public"."v2_task_logs_with_daily_aggregation" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v2_task_logs_with_details" WITH ("security_invoker"='on') AS
 WITH "last_queue" AS (
         SELECT DISTINCT ON ("task_log_line_queue"."log_id") "task_log_line_queue"."log_id",
            "task_log_line_queue"."status" AS "queue_status",
            "task_log_line_queue"."created_at" AS "queue_created_at",
            "task_log_line_queue"."id" AS "queue_row_id"
           FROM "public"."task_log_line_queue"
          ORDER BY "task_log_line_queue"."log_id", "task_log_line_queue"."created_at" DESC, "task_log_line_queue"."id" DESC
        )
 SELECT "log"."id" AS "log_id",
    "log"."created_at" AS "log_created_at",
    ("log"."created_at")::"date" AS "adjust_date",
    ("log"."ExpectedDateTime")::"date" AS "expected_date_only",
    COALESCE("log"."task_id", "log"."c_task_id") AS "task_id",
    "log"."completed_by",
    "log"."Created_Date" AS "log_date",
    "log"."status",
    "log"."Descript",
    "log"."Task_Repeat_Id",
    "log"."ExpectedDateTime",
    "log"."completed_at" AS "log_completed_at",
    "log"."confirmImage",
    "log"."postpone_to",
    "log"."postpone_from",
    "prev_log"."ExpectedDateTime" AS "expecteddate_postpone_from",
    COALESCE("a_task"."title", "c_task"."title") AS "task_title",
    COALESCE("a_task"."description", "c_task"."description") AS "task_description",
    "a_task"."form_url",
    COALESCE("a_task"."resident_id", "c_task"."resident_id") AS "resident_id",
    "resident"."i_Name_Surname" AS "resident_name",
    "resident"."i_picture_url",
    "resident"."s_status",
    COALESCE("resident"."s_special_status", '-'::"text") AS "s_special_status",
    "resident"."underlying_disease_list" AS "resident_underlying_disease_list",
    COALESCE("a_task"."creator_id", "c_task"."creator_id") AS "creator_id",
    "creator_u"."nickname" AS "creator_nickname",
    "creator_u"."photo_url" AS "creator_photo_url",
    COALESCE("a_task"."due_date", "c_task"."due_date") AS "task_due_date",
    COALESCE("a_task"."nursinghome_id", "c_task"."nursinghome_id") AS "nursinghome_id",
    COALESCE("a_task"."Subtask_of", "c_task"."Subtask_of") AS "task_subtask_of",
    COALESCE("a_task"."assign_to", "c_task"."assign_to") AS "assign_to",
    COALESCE("a_task"."taskType", "c_task"."taskType") AS "taskType",
    COALESCE("a_task"."reaquire_image", false) AS "reaquire_image",
    COALESCE("a_task"."mustCompleteByPost", false) AS "mustCompleteByPost",
    "repeat"."sampleImageURL",
    "repeat"."must_complete_by_image",
    COALESCE("repeat"."recurrenceType", "c_task"."recurrenceType") AS "recurrenceType",
    COALESCE("repeat"."recurrenceInterval", "c_task"."recurrenceInterval") AS "recurrenceInterval",
    COALESCE("repeat"."start_Date", "c_task"."start_Date") AS "start_Date",
    COALESCE("repeat"."end_Date", "c_task"."end_Date") AS "end_Date",
    COALESCE("repeat"."startTme", "c_task"."startTme") AS "startTme",
    COALESCE("repeat"."endTime", "c_task"."endTime") AS "endTime",
    COALESCE("repeat"."timeBlock", "c_task"."timeBlock") AS "timeBlock",
    COALESCE("repeat"."daysOfWeek", ARRAY[]::"text"[]) AS "daysOfWeek",
        CASE
            WHEN ("log"."c_task_id" IS NOT NULL) THEN "c_task"."recurNote"
            ELSE "repeat"."recurNote"
        END AS "recurNote",
    COALESCE("repeat"."update_status", false) AS "repeat_update_status",
    "repeat"."recurring_dates",
    "u"."nickname" AS "completed_by_nickname",
    "u"."photo_url" AS "completed_by_photo_url",
    "resident"."s_zone" AS "zone_id",
    "nz"."zone" AS "zone_name",
    "log"."post_id",
    "post"."multi_img_url",
    "post"."imgUrl" AS "imgurl",
        CASE
            WHEN ("log"."completed_by" IS NULL) THEN 1
            ELSE 2
        END AS "completed_by_status",
        CASE
            WHEN ("log"."status" = 'postpone'::"text") THEN 1
            WHEN ("log"."status" = 'refer'::"text") THEN 0
            WHEN ("log"."completed_at" IS NULL) THEN 0
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (30)::numeric) THEN 10
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) > (30)::numeric) THEN 4
            ELSE 0
        END AS "time_difference_value",
    COALESCE(
        CASE
            WHEN (COALESCE("repeat"."timeBlock", "c_task"."timeBlock") = ANY (ARRAY['07:00 - 09:00'::"text", '09:00 - 11:00'::"text", '11:00 - 13:00'::"text", '13:00 - 15:00'::"text", '15:00 - 17:00'::"text", '17:00 - 19:00'::"text"])) THEN '07:00 - 19:00'::"text"
            WHEN (COALESCE("repeat"."timeBlock", "c_task"."timeBlock") = ANY (ARRAY['19:00 - 21:00'::"text", '21:00 - 23:00'::"text", '23:00 - 01:00'::"text", '01:00 - 03:00'::"text", '03:00 - 05:00'::"text", '05:00 - 07:00'::"text"])) THEN '19:00 - 07:00'::"text"
            ELSE NULL::"text"
        END, ''::"text") AS "timeblock_range",
        CASE
            WHEN ((COALESCE("repeat"."startTme", "c_task"."startTme") >= '07:00:00'::time without time zone) AND (COALESCE("repeat"."startTme", "c_task"."startTme") < '19:00:00'::time without time zone)) THEN 'เวรเช้า'::"text"
            WHEN (COALESCE("repeat"."startTme", "c_task"."startTme") IS NOT NULL) THEN 'เวรดึก'::"text"
            ELSE NULL::"text"
        END AS "shift_response",
    "lq"."queue_status",
    "lq"."queue_created_at",
    "lq"."queue_row_id",
    "last_seen"."history_seen_id",
    "last_seen"."history_seen_users",
    "u"."group" AS "completed_by_group_id",
    "ug_completed"."group" AS "completed_by_group_name",
    "creator_u"."group" AS "creator_group_id",
    "ug_creator"."group" AS "creator_group_name"
   FROM (((((((((((((("public"."A_Task_logs_ver2" "log"
     LEFT JOIN "public"."A_Tasks" "a_task" ON (("log"."task_id" = "a_task"."id")))
     LEFT JOIN "public"."C_Tasks" "c_task" ON (("log"."c_task_id" = "c_task"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "repeat" ON (("log"."Task_Repeat_Id" = "repeat"."id")))
     LEFT JOIN "public"."user_info" "u" ON (("log"."completed_by" = "u"."id")))
     LEFT JOIN "public"."residents" "resident" ON ((COALESCE("a_task"."resident_id", "c_task"."resident_id") = "resident"."id")))
     LEFT JOIN "public"."A_Task_with_Post" "post_link" ON (("log"."task_id" = "post_link"."task_id")))
     LEFT JOIN "public"."A_Task_logs_ver2" "prev_log" ON (("log"."postpone_from" = "prev_log"."id")))
     LEFT JOIN "last_queue" "lq" ON (("lq"."log_id" = "log"."id")))
     LEFT JOIN "public"."Post" "post" ON (("log"."post_id" = "post"."id")))
     LEFT JOIN "public"."user_info" "creator_u" ON (("creator_u"."id" = COALESCE("a_task"."creator_id", "c_task"."creator_id"))))
     LEFT JOIN "public"."user_group" "ug_completed" ON (("ug_completed"."id" = "u"."group")))
     LEFT JOIN "public"."user_group" "ug_creator" ON (("ug_creator"."id" = "creator_u"."group")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON ((("nz"."id" = "resident"."s_zone") AND ("nz"."nursinghome_id" = COALESCE("a_task"."nursinghome_id", "c_task"."nursinghome_id")))))
     LEFT JOIN LATERAL ( SELECT "ls"."id" AS "history_seen_id",
            COALESCE("array_agg"("uts"."user_id" ORDER BY "uts"."created_at"), ARRAY[]::"text"[]) AS "history_seen_users"
           FROM (( SELECT "A_Task_History_Seen"."id"
                   FROM "public"."A_Task_History_Seen"
                  WHERE ("A_Task_History_Seen"."relatedTaskId" = "a_task"."id")
                  ORDER BY "A_Task_History_Seen"."created_at" DESC, "A_Task_History_Seen"."id" DESC
                 LIMIT 1) "ls"
             LEFT JOIN "public"."user_task_seen" "uts" ON (("uts"."Task_seen_id" = "ls"."id")))
          GROUP BY "ls"."id") "last_seen" ON (true));


ALTER TABLE "public"."v2_task_logs_with_details" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v2_task_logs_with_details_n8n" WITH ("security_invoker"='on') AS
 SELECT "log"."id" AS "log_id",
    "log"."created_at" AS "log_created_at",
    ("log"."created_at")::"date" AS "adjust_date",
    ("log"."ExpectedDateTime")::"date" AS "expected_date_only",
    "log"."task_id",
    "log"."completed_by",
    "log"."Created_Date" AS "log_date",
    "log"."status",
    "log"."Descript",
    "log"."Task_Repeat_Id",
    "log"."ExpectedDateTime",
    "log"."completed_at" AS "log_completed_at",
    "log"."confirmImage",
    "log"."postpone_to",
    "log"."postpone_from",
    "prev_log"."ExpectedDateTime" AS "expecteddate_postpone_from",
    "task"."title" AS "task_title",
    "task"."description" AS "task_description",
    "task"."form_url",
    "task"."resident_id",
    "resident"."i_Name_Surname" AS "resident_name",
    "resident"."s_status",
    COALESCE("resident"."s_special_status", '-'::"text") AS "s_special_status",
    "task"."creator_id",
    "task"."due_date" AS "task_due_date",
    "task"."nursinghome_id",
    "task"."Subtask_of" AS "task_subtask_of",
    "task"."assign_to",
    "task"."taskType",
    "task"."reaquire_image",
    "repeat"."sampleImageURL",
    "repeat"."recurrenceType",
    "repeat"."recurrenceInterval",
    "repeat"."start_Date",
    "repeat"."end_Date",
    "repeat"."startTme",
    "repeat"."endTime",
    "repeat"."timeBlock",
    "repeat"."daysOfWeek",
    "repeat"."recurNote",
    "repeat"."update_status" AS "repeat_update_status",
    "repeat"."recurring_dates",
    "u"."nickname" AS "completed_by_nickname",
    "u"."photo_url" AS "completed_by_photo_url",
    "resident"."s_zone" AS "zone_id",
    "post_link"."post_id",
        CASE
            WHEN ("log"."completed_by" IS NULL) THEN 1
            ELSE 2
        END AS "completed_by_status",
        CASE
            WHEN ("log"."status" = 'postpone'::"text") THEN 10
            WHEN ("log"."status" = 'refer'::"text") THEN 20
            WHEN ("log"."completed_at" IS NULL) THEN 0
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (15)::numeric) THEN 50
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (30)::numeric) THEN 36
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (45)::numeric) THEN 24
            WHEN ("abs"((EXTRACT(epoch FROM ("log"."ExpectedDateTime" - "log"."completed_at")) / (60)::numeric)) <= (60)::numeric) THEN 14
            ELSE 5
        END AS "time_difference_value",
        CASE
            WHEN ("repeat"."timeBlock" = ANY (ARRAY['07:00 - 09:00'::"text", '09:00 - 11:00'::"text", '11:00 - 13:00'::"text", '13:00 - 15:00'::"text", '15:00 - 17:00'::"text", '17:00 - 19:00'::"text"])) THEN '07:00 - 19:00'::"text"
            WHEN ("repeat"."timeBlock" = ANY (ARRAY['19:00 - 21:00'::"text", '21:00 - 23:00'::"text", '23:00 - 01:00'::"text", '01:00 - 03:00'::"text", '03:00 - 05:00'::"text", '05:00 - 07:00'::"text"])) THEN '19:00 - 07:00'::"text"
            ELSE NULL::"text"
        END AS "timeblock_range",
        CASE
            WHEN (("repeat"."startTme" >= '07:00:00'::time without time zone) AND ("repeat"."startTme" < '19:00:00'::time without time zone)) THEN 'เวรเช้า'::"text"
            ELSE 'เวรดึก'::"text"
        END AS "shift_response",
    "stats"."complete_count",
    "stats"."problem_count",
    "stats"."postpone_count",
    "stats"."refer_count",
    "stats"."null_count",
    "stats"."total_count"
   FROM ((((((("public"."A_Task_logs_ver2_n8n" "log"
     LEFT JOIN "public"."A_Tasks" "task" ON (("log"."task_id" = "task"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "repeat" ON (("log"."Task_Repeat_Id" = "repeat"."id")))
     LEFT JOIN "public"."user_info" "u" ON (("log"."completed_by" = "u"."id")))
     LEFT JOIN "public"."residents" "resident" ON (("task"."resident_id" = "resident"."id")))
     LEFT JOIN "public"."A_Task_with_Post" "post_link" ON (("log"."task_id" = "post_link"."task_id")))
     LEFT JOIN "public"."A_Task_logs_ver2_n8n" "prev_log" ON (("log"."postpone_from" = "prev_log"."id")))
     LEFT JOIN ( SELECT "A_Task_logs_ver2_n8n"."Task_Repeat_Id",
            "count"(*) FILTER (WHERE ("A_Task_logs_ver2_n8n"."status" = 'complete'::"text")) AS "complete_count",
            "count"(*) FILTER (WHERE ("A_Task_logs_ver2_n8n"."status" = 'problem'::"text")) AS "problem_count",
            "count"(*) FILTER (WHERE ("A_Task_logs_ver2_n8n"."status" = 'postpone'::"text")) AS "postpone_count",
            "count"(*) FILTER (WHERE ("A_Task_logs_ver2_n8n"."status" = 'refer'::"text")) AS "refer_count",
            "count"(*) FILTER (WHERE ("A_Task_logs_ver2_n8n"."status" IS NULL)) AS "null_count",
            "count"(*) AS "total_count"
           FROM "public"."A_Task_logs_ver2_n8n"
          WHERE ("A_Task_logs_ver2_n8n"."created_at" >= ("now"() - '1 mon'::interval))
          GROUP BY "A_Task_logs_ver2_n8n"."Task_Repeat_Id") "stats" ON (("repeat"."id" = "stats"."Task_Repeat_Id")));


ALTER TABLE "public"."v2_task_logs_with_details_n8n" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v2_task_summary" WITH ("security_invoker"='on') AS
 SELECT ("log"."created_at")::"date" AS "adjust_date",
    "task"."nursinghome_id",
    "count"("log"."id") AS "total_tasks",
    "count"(
        CASE
            WHEN ("log"."status" = 'complete'::"text") THEN 1
            ELSE NULL::integer
        END) AS "completed_tasks",
    "count"(
        CASE
            WHEN ("log"."status" IS NULL) THEN 1
            ELSE NULL::integer
        END) AS "not_done_tasks",
    "count"(
        CASE
            WHEN ("log"."status" = 'problem'::"text") THEN 1
            ELSE NULL::integer
        END) AS "problem_tasks",
    "count"(
        CASE
            WHEN ("log"."status" = 'postpone'::"text") THEN 1
            ELSE NULL::integer
        END) AS "postponed_tasks",
    "count"(
        CASE
            WHEN ("log"."status" = 'refer'::"text") THEN 1
            ELSE NULL::integer
        END) AS "referred_tasks"
   FROM ("public"."A_Task_logs_ver2" "log"
     LEFT JOIN "public"."A_Tasks" "task" ON (("log"."task_id" = "task"."id")))
  GROUP BY (("log"."created_at")::"date"), "task"."nursinghome_id";


ALTER TABLE "public"."v2_task_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_duty_transaction_clock" WITH ("security_invoker"='on') AS
 SELECT "dtc"."id",
    "dtc"."created_at",
    "dtc"."user_1",
    "u1"."full_name" AS "user_1_full_name",
    "u1"."nickname" AS "user_1_nickname",
    "u1"."photo_url" AS "user_1_photo_url",
    "dtc"."transactionType",
    "dtc"."user_2",
    "u2"."full_name" AS "user_2_full_name",
    "u2"."nickname" AS "user_2_nickname",
    "u2"."photo_url" AS "user_2_photo_url",
    "dtc"."price",
    "dtc"."purchasingStatus",
    "dtc"."date",
    "dtc"."shift",
    "dtc"."isClockIn",
    false AS "is_virtual",
    NULL::bigint AS "original_id"
   FROM (("public"."Duty_Transaction_Clock" "dtc"
     LEFT JOIN "public"."user_info" "u1" ON (("dtc"."user_1" = "u1"."id")))
     LEFT JOIN "public"."user_info" "u2" ON (("dtc"."user_2" = "u2"."id")))
UNION ALL
 SELECT "dtc"."id",
    "dtc"."created_at",
    "dtc"."user_2" AS "user_1",
    "u2"."full_name" AS "user_1_full_name",
    "u2"."nickname" AS "user_1_nickname",
    "u2"."photo_url" AS "user_1_photo_url",
    'ซื้อ'::"text" AS "transactionType",
    "dtc"."user_1" AS "user_2",
    "u1"."full_name" AS "user_2_full_name",
    "u1"."nickname" AS "user_2_nickname",
    "u1"."photo_url" AS "user_2_photo_url",
    "dtc"."price",
    "dtc"."purchasingStatus",
    "dtc"."date",
    "dtc"."shift",
    "dtc"."isClockIn",
    true AS "is_virtual",
    "dtc"."id" AS "original_id"
   FROM (("public"."Duty_Transaction_Clock" "dtc"
     LEFT JOIN "public"."user_info" "u1" ON (("dtc"."user_1" = "u1"."id")))
     LEFT JOIN "public"."user_info" "u2" ON (("dtc"."user_2" = "u2"."id")))
  WHERE ("dtc"."transactionType" = 'ขาย'::"text")
UNION ALL
 SELECT "dtc"."id",
    "dtc"."created_at",
    "dtc"."user_2" AS "user_1",
    "u2"."full_name" AS "user_1_full_name",
    "u2"."nickname" AS "user_1_nickname",
    "u2"."photo_url" AS "user_1_photo_url",
    'ขาย'::"text" AS "transactionType",
    "dtc"."user_1" AS "user_2",
    "u1"."full_name" AS "user_2_full_name",
    "u1"."nickname" AS "user_2_nickname",
    "u1"."photo_url" AS "user_2_photo_url",
    "dtc"."price",
    "dtc"."purchasingStatus",
    "dtc"."date",
    "dtc"."shift",
    "dtc"."isClockIn",
    true AS "is_virtual",
    "dtc"."id" AS "original_id"
   FROM (("public"."Duty_Transaction_Clock" "dtc"
     LEFT JOIN "public"."user_info" "u1" ON (("dtc"."user_1" = "u1"."id")))
     LEFT JOIN "public"."user_info" "u2" ON (("dtc"."user_2" = "u2"."id")))
  WHERE ("dtc"."transactionType" = 'ซื้อ'::"text");


ALTER TABLE "public"."v_duty_transaction_clock" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_filtered_tasks_with_logs" AS
SELECT
    NULL::bigint AS "repeated_task_id",
    NULL::bigint AS "task_id",
    NULL::"text" AS "title",
    NULL::"text" AS "description",
    NULL::bigint AS "resident_id",
    NULL::"text" AS "resident_name",
    NULL::bigint AS "zone_id",
    NULL::"text" AS "zone",
    NULL::"uuid" AS "creator_id",
    NULL::"uuid" AS "completed_by",
    NULL::timestamp with time zone AS "due_date",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "recurrenceType",
    NULL::bigint AS "recurrenceInterval",
    NULL::"date" AS "start_Date",
    NULL::"date" AS "end_Date",
    NULL::time without time zone AS "start_time",
    NULL::time without time zone AS "end_time",
    NULL::"text" AS "timeBlock",
    NULL::"text" AS "taskType",
    NULL::"text" AS "form_url",
    NULL::"text"[] AS "daysOfWeek",
    NULL::"text" AS "recurNote",
    NULL::"text" AS "resident_status",
    NULL::"text" AS "s_special_status",
    NULL::integer AS "time_slot",
    NULL::boolean AS "has_log_date",
    NULL::"date"[] AS "log_dates";


ALTER TABLE "public"."v_filtered_tasks_with_logs" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_prn_post_queue" WITH ("security_invoker"='on') AS
 SELECT "q"."id" AS "queue_id",
    "q"."created_at" AS "queue_created_at",
    "q"."post_id",
    "q"."status" AS "queue_status",
    "p"."created_at" AS "post_created_at",
    "p"."nursinghome_id",
    "p"."user_id",
    "ui"."nickname" AS "user_nickname",
    "pr"."resident_id",
    "rs"."i_Name_Surname" AS "resident_name",
    "rs"."i_picture_url" AS "resident_photo_url",
    "p"."Text" AS "post_text",
    "p"."multi_img_url",
    "p"."Tag_Topics",
    "p"."visible_to_relative",
    "p"."reply_to"
   FROM (((("public"."prn_post_queue" "q"
     JOIN "public"."Post" "p" ON (("p"."id" = "q"."post_id")))
     LEFT JOIN "public"."Post_Resident_id" "pr" ON (("pr"."Post_id" = "p"."id")))
     LEFT JOIN "public"."residents" "rs" ON (("rs"."id" = "pr"."resident_id")))
     LEFT JOIN "public"."user_info" "ui" ON (("ui"."id" = "p"."user_id")));


ALTER TABLE "public"."v_prn_post_queue" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_program_membership" WITH ("security_invoker"='on') AS
 SELECT "rp"."program_id",
    "p"."name" AS "program_name",
    "p"."nursinghome_id",
    "r"."id" AS "resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_status"
   FROM (("public"."resident_programs" "rp"
     JOIN "public"."programs" "p" ON (("p"."id" = "rp"."program_id")))
     JOIN "public"."residents" "r" ON (("r"."id" = "rp"."resident_id")));


ALTER TABLE "public"."v_program_membership" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_repeated_task_summary" WITH ("security_invoker"='on') AS
 SELECT "repeat"."task_id",
    "repeat"."id" AS "repeated_task_id",
    "task"."nursinghome_id",
    "task"."resident_id",
    "resident"."i_Name_Surname" AS "resident_name",
    "task"."title" AS "task_title",
    "task"."description" AS "task_description",
    "resident"."s_status",
        CASE
            WHEN ("resident"."s_special_status" IS NULL) THEN '-'::"text"
            ELSE "resident"."s_special_status"
        END AS "s_special_status",
    "task"."creator_id",
    "task"."due_date" AS "task_due_date",
    "task"."Subtask_of" AS "task_subtask_of",
    "task"."assign_to",
    "task"."taskType",
    "task"."reaquire_image",
    "task"."sampleImageURL",
    "task"."form_url",
    "repeat"."recurrenceType",
    "repeat"."recurrenceInterval",
    "repeat"."start_Date",
    "repeat"."end_Date",
    "repeat"."startTme",
    "repeat"."endTime",
    "repeat"."timeBlock",
    "repeat"."daysOfWeek",
    "repeat"."recurNote",
    "repeat"."update_status" AS "repeat_update_status",
    "resident"."s_zone" AS "zone_id",
    ( SELECT "log"."id"
           FROM "public"."A_Task_logs_ver2" "log"
          WHERE ("log"."Task_Repeat_Id" = "repeat"."id")
          ORDER BY "log"."created_at" DESC
         LIMIT 1) AS "latest_log_id",
    ( SELECT "count"(*) AS "count"
           FROM "public"."A_Task_logs_ver2"
          WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."status" = 'complete'::"text") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))) AS "complete_count",
    ( SELECT "count"(*) AS "count"
           FROM "public"."A_Task_logs_ver2"
          WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."status" = 'problem'::"text") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))) AS "problem_count",
    ( SELECT "count"(*) AS "count"
           FROM "public"."A_Task_logs_ver2"
          WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."status" IS NULL) AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))) AS "null_count",
    ( SELECT "count"(*) AS "count"
           FROM "public"."A_Task_logs_ver2"
          WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))) AS "total_count",
        CASE
            WHEN (( SELECT "count"(*) AS "count"
               FROM "public"."A_Task_logs_ver2"
              WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))) > 0) THEN "round"((((( SELECT "count"(*) AS "count"
               FROM "public"."A_Task_logs_ver2"
              WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."status" = 'problem'::"text") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))))::numeric / (( SELECT "count"(*) AS "count"
               FROM "public"."A_Task_logs_ver2"
              WHERE (("A_Task_logs_ver2"."Task_Repeat_Id" = "repeat"."id") AND ("A_Task_logs_ver2"."created_at" >= ("now"() - '1 mon'::interval)))))::numeric) * (100)::numeric), 2)
            ELSE (0)::numeric
        END AS "problem_percentage"
   FROM (("public"."A_Repeated_Task" "repeat"
     LEFT JOIN "public"."A_Tasks" "task" ON (("repeat"."task_id" = "task"."id")))
     LEFT JOIN "public"."residents" "resident" ON (("task"."resident_id" = "resident"."id")));


ALTER TABLE "public"."v_repeated_task_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_task_log_queue_history" WITH ("security_invoker"='on') AS
 SELECT "q"."id" AS "queue_row_id",
    "q"."created_at" AS "queue_created_at",
    "q"."log_id",
    "q"."status" AS "queue_status",
    "lg"."created_at" AS "log_created_at",
    "lg"."ExpectedDateTime" AS "expected_datetime",
    COALESCE("lg"."task_id", "lg"."c_task_id") AS "task_id",
    COALESCE("at"."title", "ct"."title") AS "task_title",
    COALESCE("at"."resident_id", "ct"."resident_id") AS "resident_id",
    "rs"."i_Name_Surname" AS "resident_name",
    "lg"."completed_by" AS "completed_by_id",
    "ui"."nickname" AS "completed_by_nickname",
    "rpt"."sampleImageURL" AS "sample_image_url",
    "lg"."confirmImage" AS "confirm_image_url",
    COALESCE("at"."nursinghome_id", "ct"."nursinghome_id") AS "nursinghome_id"
   FROM (((((("public"."task_log_line_queue" "q"
     JOIN "public"."A_Task_logs_ver2" "lg" ON (("lg"."id" = "q"."log_id")))
     LEFT JOIN "public"."A_Tasks" "at" ON (("lg"."task_id" = "at"."id")))
     LEFT JOIN "public"."C_Tasks" "ct" ON (("lg"."c_task_id" = "ct"."id")))
     LEFT JOIN "public"."residents" "rs" ON ((COALESCE("at"."resident_id", "ct"."resident_id") = "rs"."id")))
     LEFT JOIN "public"."user_info" "ui" ON (("lg"."completed_by" = "ui"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "rpt" ON (("lg"."Task_Repeat_Id" = "rpt"."id")));


ALTER TABLE "public"."v_task_log_queue_history" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_task_logs_with_user_info" WITH ("security_invoker"='on') AS
 SELECT "l"."id" AS "log_id",
    "l"."created_at" AS "log_created_at",
    "l"."Created_Date" AS "log_date",
    "l"."task_id",
    "l"."status",
    "l"."Descript",
    "l"."Task_Repeat_Id",
    "u"."id" AS "user_id",
    "u"."full_name",
    "u"."nickname",
    "u"."nursinghome_id"
   FROM ("public"."A_Task_logs" "l"
     JOIN "public"."user_info" "u" ON (("l"."completed_by" = "u"."id")));


ALTER TABLE "public"."v_task_logs_with_user_info" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_tasks_with_logs" AS
SELECT
    NULL::bigint AS "repeated_task_id",
    NULL::bigint AS "task_id",
    NULL::"text" AS "title",
    NULL::"text" AS "description",
    NULL::bigint AS "resident_id",
    NULL::"text" AS "resident_name",
    NULL::bigint AS "zone_id",
    NULL::"text" AS "zone",
    NULL::"uuid" AS "creator_id",
    NULL::timestamp with time zone AS "due_date",
    NULL::bigint AS "nursinghome_id",
    NULL::"text" AS "recurrenceType",
    NULL::bigint AS "recurrenceInterval",
    NULL::"date" AS "start_Date",
    NULL::"date" AS "end_Date",
    NULL::time without time zone AS "start_time",
    NULL::time without time zone AS "end_time",
    NULL::"text" AS "timeBlock",
    NULL::"text" AS "taskType",
    NULL::"text" AS "form_url",
    NULL::"text"[] AS "daysofweek",
    NULL::"text" AS "recurNote",
    NULL::smallint[] AS "recurring_dates",
    NULL::"text" AS "sampleImageURL",
    NULL::"text"[] AS "previous_days",
    NULL::boolean AS "has_log_date",
    NULL::"text" AS "resident_status",
    NULL::"text" AS "s_special_status",
    NULL::integer AS "time_slot",
    NULL::integer AS "is_next_day",
    NULL::"uuid" AS "completed_by",
    NULL::"text" AS "completed_by_nickname",
    NULL::timestamp with time zone AS "completed_at",
    NULL::"text" AS "log_status",
    NULL::"text" AS "log_descript",
    NULL::timestamp with time zone AS "latest_expecteddatetime";


ALTER TABLE "public"."v_tasks_with_logs" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_tasks_with_logs_by_task" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "task_id",
    "t"."created_at",
    "t"."title",
    "t"."description",
    "t"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_zone" AS "zone_id",
    "t"."creator_id",
    "t"."completed_by",
    "t"."due_date",
    "r"."nursinghome_id",
    "t"."Subtask_of",
    "t"."assign_to",
    "t"."taskType",
    COALESCE("r"."s_status", 'zone'::"text") AS "resident_status",
    COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
        CASE
            WHEN ("min"("rt"."end_Date") IS NOT NULL) THEN 'inactive'::"text"
            ELSE 'active'::"text"
        END AS "status",
    "latest_log"."latest_log_id",
    "t"."mustCompleteByPost",
    "t"."form_url"
   FROM ((("public"."A_Tasks" "t"
     LEFT JOIN "public"."residents" "r" ON (("t"."resident_id" = "r"."id")))
     LEFT JOIN "public"."A_Repeated_Task" "rt" ON (("t"."id" = "rt"."task_id")))
     LEFT JOIN ( SELECT "A_Task_logs_ver2"."task_id",
            "max"("A_Task_logs_ver2"."id") AS "latest_log_id"
           FROM "public"."A_Task_logs_ver2"
          GROUP BY "A_Task_logs_ver2"."task_id") "latest_log" ON (("t"."id" = "latest_log"."task_id")))
  GROUP BY "t"."id", "t"."created_at", "t"."title", "t"."description", "t"."resident_id", "r"."i_Name_Surname", "r"."s_zone", "t"."creator_id", "t"."completed_by", "t"."due_date", "r"."nursinghome_id", "t"."Subtask_of", "t"."assign_to", "t"."taskType", "r"."s_status", "r"."s_special_status", "latest_log"."latest_log_id", "t"."mustCompleteByPost", "t"."form_url";


ALTER TABLE "public"."v_tasks_with_logs_by_task" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_resident_caution_manual" WITH ("security_invoker"='on') AS
 SELECT "rcm"."id",
    "rcm"."created_at",
    "rcm"."resident_id",
    "rcm"."text",
    "rcm"."user_id",
    "rcm"."modified_at",
    "rcm"."active",
    "rcm"."type",
    "rcm"."index",
    "rcm"."priority",
    COALESCE("rcm"."modified_at", "rcm"."created_at") AS "latest_update",
    "ui"."nickname" AS "user_nickname"
   FROM ("public"."resident_caution_manual" "rcm"
     LEFT JOIN "public"."user_info" "ui" ON (("rcm"."user_id" = "ui"."id")));


ALTER TABLE "public"."view_resident_caution_manual" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_resident_template_reports" WITH ("security_invoker"='on') AS
 SELECT "r"."id" AS "resident_id",
    "r"."i_Name_Surname" AS "name",
    "r"."nursinghome_id",
    "r"."s_status" AS "status",
    "rg"."template_D",
    "rg"."template_N"
   FROM ("public"."residents" "r"
     JOIN "public"."Resident_Template_Gen_Report" "rg" ON (("r"."id" = "rg"."resident_id")));


ALTER TABLE "public"."view_resident_template_reports" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_resident_underlying_disease" WITH ("security_invoker"='on') AS
 SELECT "rud"."id",
    "rud"."created_at",
    "rud"."resident_id",
    "rud"."underlying_id",
    "ud"."name" AS "disease_name",
    "ud"."pastel_color"
   FROM (("public"."resident_underlying_disease" "rud"
     JOIN "public"."underlying_disease" "ud" ON (("rud"."underlying_id" = "ud"."id")))
     JOIN "public"."underlying_disease_summary_view" "uds" ON (("ud"."id" = "uds"."disease_id")));


ALTER TABLE "public"."view_resident_underlying_disease" OWNER TO "postgres";


ALTER TABLE "public"."vitalSign" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."vitalSign_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."vitalsign_sent_queue" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vitalsign_id" bigint,
    "status" "text",
    "comment" "text"
);


ALTER TABLE "public"."vitalsign_sent_queue" OWNER TO "postgres";


COMMENT ON TABLE "public"."vitalsign_sent_queue" IS 'คิวสำหรับ n8n ในการส่งให้ line bot';



CREATE OR REPLACE VIEW "public"."vitalsign_queue_view" WITH ("security_invoker"='on') AS
 SELECT "q"."id" AS "queue_id",
    "q"."created_at" AS "queue_created_at",
    "q"."vitalsign_id",
    "q"."status",
    "q"."comment",
    "vs"."nursinghome_id",
    "crd"."s_zone" AS "zone",
    "crd"."zone_id",
    "cvd"."formatted_created_at",
    "cvd"."formatted_vital_signs",
    "cvd"."resident_id",
    "cvd"."resident_name",
    "cvd"."resident_photo_url",
    "cvd"."user_id",
    "cvd"."user_nickname",
    "cvd"."user_photo_url"
   FROM ((("public"."vitalsign_sent_queue" "q"
     JOIN "public"."vitalSign" "vs" ON (("vs"."id" = "q"."vitalsign_id")))
     JOIN "public"."combined_vitalsign_details_view" "cvd" ON (("cvd"."id" = "q"."vitalsign_id")))
     LEFT JOIN "public"."combined_resident_details_view" "crd" ON (("crd"."resident_id" = "cvd"."resident_id")));


ALTER TABLE "public"."vitalsign_queue_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."vitalsign_recent_basic_view" WITH ("security_invoker"='on') AS
 SELECT "vs"."id" AS "vital_sign_id",
    "vs"."resident_id",
    "vs"."created_at",
    "to_char"("vs"."created_at", 'DD/MM/YYYY HH24:MI'::"text") AS "formatted_created_at",
    "vs"."Temp" AS "temp_celsius",
    "vs"."PR" AS "pulse_bpm",
    "vs"."RR" AS "resp_rate_per_min",
    "vs"."sBP" AS "sbp_mmhg",
    "vs"."dBP" AS "dbp_mmhg",
    "vs"."O2" AS "o2sat_percent",
    "vs"."DTX" AS "dtx_mgdl",
    "vs"."constipation",
    "vs"."Input" AS "fluid_input_ml",
    "vs"."output" AS "fluid_output_estimate",
    COALESCE("vs"."generalReport", '-'::"text") AS "general_report"
   FROM "public"."vitalSign" "vs"
  WHERE ("vs"."created_at" >= (CURRENT_DATE - '14 days'::interval))
  ORDER BY "vs"."resident_id", "vs"."created_at" DESC;


ALTER TABLE "public"."vitalsign_recent_basic_view" OWNER TO "postgres";


ALTER TABLE "public"."vitalsign_sent_queue" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."vitalsign_sent_queue_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."vw_comment_details" WITH ("security_invoker"='on') AS
 SELECT "cp"."id" AS "comment_id",
    "cp"."created_at" AS "comment_created_at",
    "cp"."comment",
    "cp"."user_id",
    "cp"."Post_id",
    "ui"."photo_url",
    "ui"."nickname",
    "ui"."user_role",
    ( SELECT "array_agg"("pl"."user_id") AS "array_agg"
           FROM "public"."Post_likes" "pl"
          WHERE ("pl"."Comment_id" = "cp"."id")) AS "liked_by_user_ids"
   FROM ("public"."CommentPost" "cp"
     LEFT JOIN "public"."user_info" "ui" ON (("cp"."user_id" = "ui"."id")));


ALTER TABLE "public"."vw_comment_details" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."vw_resident_report_relation" WITH ("security_invoker"='on') AS
 SELECT "rrr"."id",
    "rrr"."created_at",
    "rrr"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "rs"."id" AS "subject_id",
    "rs"."Subject" AS "report_subject",
    "rs"."Description" AS "subject_description",
    "rs"."nursinghome_id",
    "rrr"."shift",
    "rc"."choices",
    "rc"."represent_urls"
   FROM ((("public"."Resident_Report_Relation" "rrr"
     JOIN "public"."residents" "r" ON (("rrr"."resident_id" = "r"."id")))
     JOIN "public"."Report_Subject" "rs" ON (("rrr"."subject_id" = "rs"."id")))
     LEFT JOIN LATERAL ( SELECT "array_agg"("rc_1"."Choice" ORDER BY "rc_1"."Scale") AS "choices",
            "array_agg"("rc_1"."represent_url" ORDER BY "rc_1"."Scale") AS "represent_urls"
           FROM "public"."Report_Choice" "rc_1"
          WHERE ("rc_1"."Subject" = "rrr"."subject_id")) "rc" ON (true));


ALTER TABLE "public"."vw_resident_report_relation" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."vw_residents_with_relatives" WITH ("security_invoker"='on') AS
 SELECT "r"."id" AS "resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."i_National_ID_num" AS "national_id",
    "r"."i_DOB" AS "date_of_birth",
    "r"."i_gender" AS "gender",
    "r"."s_status" AS "status",
    "r"."s_zone" AS "zone_id",
    "r"."zone_text",
    "r"."s_bed" AS "bed",
    COALESCE("json_agg"("json_build_object"('id', "rel"."id", 'name_surname', "rel"."r_name_surname", 'nickname', "rel"."r_nickname", 'phone', "rel"."r_phone", 'detail', "rel"."r_detail", 'key_person', "rel"."key_person", 'line_user_id', "rel"."lineUserId") ORDER BY "rel"."key_person" DESC NULLS LAST, "rel"."r_name_surname") FILTER (WHERE ("rel"."id" IS NOT NULL)), '[]'::"json") AS "relatives_list",
    "count"("rel"."id") AS "relatives_count",
    ( SELECT "json_build_object"('id', "rel_key"."id", 'name_surname', "rel_key"."r_name_surname", 'nickname', "rel_key"."r_nickname", 'phone', "rel_key"."r_phone", 'detail', "rel_key"."r_detail") AS "json_build_object"
           FROM ("public"."resident_relatives" "rr_key"
             JOIN "public"."relatives" "rel_key" ON (("rr_key"."relatives_id" = "rel_key"."id")))
          WHERE (("rr_key"."resident_id" = "r"."id") AND ("rel_key"."key_person" = true))
         LIMIT 1) AS "key_person_contact"
   FROM (("public"."residents" "r"
     LEFT JOIN "public"."resident_relatives" "rr" ON (("r"."id" = "rr"."resident_id")))
     LEFT JOIN "public"."relatives" "rel" ON (("rr"."relatives_id" = "rel"."id")))
  GROUP BY "r"."id", "r"."i_Name_Surname", "r"."i_National_ID_num", "r"."i_DOB", "r"."i_gender", "r"."s_status", "r"."s_zone", "r"."zone_text", "r"."s_bed"
  ORDER BY "r"."i_Name_Surname";


ALTER TABLE "public"."vw_residents_with_relatives" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhook_trigger_logs" (
    "id" bigint NOT NULL,
    "webhook_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb",
    "response_status" integer,
    "response_body" "text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."webhook_trigger_logs" OWNER TO "postgres";


ALTER TABLE "public"."webhook_trigger_logs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."webhook_trigger_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."cleanup_snooze_log" ALTER COLUMN "log_id" SET DEFAULT "nextval"('"public"."cleanup_snooze_log_log_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."task_log_line_queue" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."task_log_line_queue_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."A_Med_Error_Log"
    ADD CONSTRAINT "A_Med_Error_Log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Repeated_Task"
    ADD CONSTRAINT "A_Repeated_Task_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Task_History_Seen"
    ADD CONSTRAINT "A_Task_History_Seen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Task_logs"
    ADD CONSTRAINT "A_Task_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2_n8n"
    ADD CONSTRAINT "A_Task_logs_ver2_n8n_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Task_with_Post"
    ADD CONSTRAINT "A_Task_with_Post_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."C_Calendar"
    ADD CONSTRAINT "C_Calendar_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."C_Calendar_with_Post"
    ADD CONSTRAINT "C_Calendar_with_Post_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clock_in_out_ver2"
    ADD CONSTRAINT "Clock In Out_ver2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Clock Special Record"
    ADD CONSTRAINT "Clock Special Record_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CommentPost"
    ADD CONSTRAINT "CommentPost_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DD_Record_Clock"
    ADD CONSTRAINT "DD_Record_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Doc_Bowel_Movement"
    ADD CONSTRAINT "Doc_Bowel_Movement_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Duty_Transaction_Clock"
    ADD CONSTRAINT "Duty_Transaction_Clock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."F_timeBlock"
    ADD CONSTRAINT "F_timeBlock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."med_DB"
    ADD CONSTRAINT "Med_DB_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Medication Error Rate"
    ADD CONSTRAINT "Medication Error Rate_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."New_Manual"
    ADD CONSTRAINT "New_Manual_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Inbox"
    ADD CONSTRAINT "Notification_Center_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Point_Transaction"
    ADD CONSTRAINT "Point_Transaction_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Post_Quest_Accept"
    ADD CONSTRAINT "Post_Quest_Accept_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Post_Resident_id"
    ADD CONSTRAINT "Post_Resident_id_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TagsLabel"
    ADD CONSTRAINT "Post_Tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Post_Tags"
    ADD CONSTRAINT "Post_Tags_pkey1" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Post_likes"
    ADD CONSTRAINT "Post_likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QATable"
    ADD CONSTRAINT "QATable_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Relation_TagTopic_UserGroup"
    ADD CONSTRAINT "Relation_TagTopic_UserGroup_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."relatives"
    ADD CONSTRAINT "Relatives_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Report_Choice"
    ADD CONSTRAINT "Report_Choice_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Report_Subject"
    ADD CONSTRAINT "Report_Subject_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."resident_caution_manual"
    ADD CONSTRAINT "Resident_Caution_Manual_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Resident_Report_Relation"
    ADD CONSTRAINT "Resident_Report_Relation_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."SOAPNote"
    ADD CONSTRAINT "SOAPNote_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "Scale_Report_Log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Calendar_Subject"
    ADD CONSTRAINT "SubjectCalendarType_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Task_Type"
    ADD CONSTRAINT "Task_Type_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Template_Ticket"
    ADD CONSTRAINT "Template_Ticket_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Workday"
    ADD CONSTRAINT "Workday_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."abnormal_value_Dashboard"
    ADD CONSTRAINT "abnormal_value_Dashboard_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."abnormal_value_and_Ticket_Calendar"
    ADD CONSTRAINT "abnormal_value_and_Ticket_Calendar_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clock_break_time_nursinghome"
    ADD CONSTRAINT "break_time_nursinghome_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cleanup_snooze_log"
    ADD CONSTRAINT "cleanup_snooze_log_pkey" PRIMARY KEY ("log_id");



ALTER TABLE ONLY "public"."dummyFinishDutyTable"
    ADD CONSTRAINT "dummyFinishDutyTable_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medMadeChange"
    ADD CONSTRAINT "medMadeChange_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."med_example"
    ADD CONSTRAINT "med_example_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."med_history"
    ADD CONSTRAINT "med_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medicine_List"
    ADD CONSTRAINT "medicine_List_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medicine_tag"
    ADD CONSTRAINT "medicine_tag_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quickSnap_picture"
    ADD CONSTRAINT "my_Picture_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nursinghome_zone"
    ADD CONSTRAINT "nursinghome_zone_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nursinghomes"
    ADD CONSTRAINT "nursinghomes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pastel_color"
    ADD CONSTRAINT "pastel color_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_status"
    ADD CONSTRAINT "patient_status_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."postDoneBy"
    ADD CONSTRAINT "postDoneBy_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."postReferenceId"
    ADD CONSTRAINT "postReferenceId_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prn_post_queue"
    ADD CONSTRAINT "prn_post_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("fcm_token");



ALTER TABLE ONLY "public"."program_summary_daily"
    ADD CONSTRAINT "program_summary_daily_pkey" PRIMARY KEY ("snapshot_date", "program_id", "nursinghome_id");



ALTER TABLE ONLY "public"."programs"
    ADD CONSTRAINT "programs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."resident_relatives"
    ADD CONSTRAINT "resident&relatives_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."resident_line_group_id"
    ADD CONSTRAINT "resident_line_group_id_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."resident_programs"
    ADD CONSTRAINT "resident_programs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Resident_Template_Gen_Report"
    ADD CONSTRAINT "resident_template_gen_report_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."resident_underlying_disease"
    ADD CONSTRAINT "resident_underlying_disease_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."residents"
    ADD CONSTRAINT "residents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."send_out_user_resident"
    ADD CONSTRAINT "send_out_user_resident_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_log_line_queue"
    ADD CONSTRAINT "task_log_line_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_summary"
    ADD CONSTRAINT "task_summary_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_badges"
    ADD CONSTRAINT "training_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_content"
    ADD CONSTRAINT "training_content_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_content"
    ADD CONSTRAINT "training_content_topic_id_season_id_key" UNIQUE ("topic_id", "season_id");



ALTER TABLE ONLY "public"."training_questions"
    ADD CONSTRAINT "training_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_quiz_answers"
    ADD CONSTRAINT "training_quiz_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_quiz_answers"
    ADD CONSTRAINT "training_quiz_answers_session_id_question_id_key" UNIQUE ("session_id", "question_id");



ALTER TABLE ONLY "public"."training_quiz_sessions"
    ADD CONSTRAINT "training_quiz_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_seasons"
    ADD CONSTRAINT "training_seasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_streaks"
    ADD CONSTRAINT "training_streaks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_streaks"
    ADD CONSTRAINT "training_streaks_user_id_season_id_key" UNIQUE ("user_id", "season_id");



ALTER TABLE ONLY "public"."training_topics"
    ADD CONSTRAINT "training_topics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_user_badges"
    ADD CONSTRAINT "training_user_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_user_badges"
    ADD CONSTRAINT "training_user_badges_user_id_badge_id_season_id_key" UNIQUE ("user_id", "badge_id", "season_id");



ALTER TABLE ONLY "public"."training_user_progress"
    ADD CONSTRAINT "training_user_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_user_progress"
    ADD CONSTRAINT "training_user_progress_user_id_topic_id_season_id_key" UNIQUE ("user_id", "topic_id", "season_id");



ALTER TABLE ONLY "public"."trigger_schedule_snooze_log"
    ADD CONSTRAINT "trigger_schedule_snooze_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."underlying_disease"
    ADD CONSTRAINT "underlying_disease_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "unique_meal_date_resident" UNIQUE ("Created_Date", "meal", "resident_id");



ALTER TABLE ONLY "public"."resident_underlying_disease"
    ADD CONSTRAINT "unique_resident_disease" UNIQUE ("resident_id", "underlying_id");



ALTER TABLE ONLY "public"."resident_programs"
    ADD CONSTRAINT "unique_resident_program" UNIQUE ("resident_id", "program_id");



ALTER TABLE ONLY "public"."Post_likes"
    ADD CONSTRAINT "unique_user_comment" UNIQUE ("user_id", "Comment_id");



ALTER TABLE ONLY "public"."Post_likes"
    ADD CONSTRAINT "unique_user_post" UNIQUE ("user_id", "Post_id");



ALTER TABLE ONLY "public"."user-QA"
    ADD CONSTRAINT "user-QA_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_group"
    ADD CONSTRAINT "user_group_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_info"
    ADD CONSTRAINT "user_info_uuid_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_task_seen"
    ADD CONSTRAINT "user_task_seen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_with_user_group"
    ADD CONSTRAINT "user_with_user_group_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vitalSign"
    ADD CONSTRAINT "vitalSign_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vitalsign_sent_queue"
    ADD CONSTRAINT "vitalsign_sent_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_trigger_logs"
    ADD CONSTRAINT "webhook_trigger_logs_pkey" PRIMARY KEY ("id");



CREATE INDEX "A_Med_Error_Log_CalendarDate_idx" ON "public"."A_Med_Error_Log" USING "btree" ("CalendarDate");



CREATE INDEX "A_Med_Error_Log_reply_nurseMark_idx" ON "public"."A_Med_Error_Log" USING "btree" ("reply_nurseMark");



CREATE INDEX "A_Med_Error_Log_resident_id_idx" ON "public"."A_Med_Error_Log" USING "btree" ("resident_id");



CREATE INDEX "A_Med_Error_Log_user_id_idx" ON "public"."A_Med_Error_Log" USING "btree" ("user_id");



CREATE INDEX "A_Med_logs_2C_completed_by_idx" ON "public"."A_Med_logs" USING "btree" ("2C_completed_by");



CREATE INDEX "A_Med_logs_3C_Compleated_by_idx" ON "public"."A_Med_logs" USING "btree" ("3C_Compleated_by");



CREATE INDEX "A_Med_logs_ArrangeMed_by_idx" ON "public"."A_Med_logs" USING "btree" ("ArrangeMed_by");



CREATE INDEX "A_Med_logs_Created_Date_idx" ON "public"."A_Med_logs" USING "btree" ("Created_Date");



CREATE INDEX "A_Med_logs_created_at_desc_idx" ON "public"."A_Med_logs" USING "btree" ("created_at" DESC);

ALTER TABLE "public"."A_Med_logs" CLUSTER ON "A_Med_logs_created_at_desc_idx";



CREATE INDEX "A_Med_logs_created_at_idx" ON "public"."A_Med_logs" USING "btree" ("created_at");



CREATE INDEX "A_Med_logs_resident_created_desc_idx" ON "public"."A_Med_logs" USING "btree" ("resident_id", "created_at" DESC);



CREATE INDEX "A_Med_logs_resident_id_idx" ON "public"."A_Med_logs" USING "btree" ("resident_id");



CREATE INDEX "A_Med_logs_resident_meal_created_desc_idx" ON "public"."A_Med_logs" USING "btree" ("resident_id", "meal", "created_at" DESC);



CREATE INDEX "A_Repeated_Task_task_id_idx" ON "public"."A_Repeated_Task" USING "btree" ("task_id");



CREATE INDEX "A_Task_History_Seen_relatedTaskId_idx" ON "public"."A_Task_History_Seen" USING "btree" ("relatedTaskId");



CREATE INDEX "A_Task_logs_Task_Repeat_Id_idx" ON "public"."A_Task_logs" USING "btree" ("Task_Repeat_Id");



CREATE INDEX "A_Task_logs_completed_by_idx" ON "public"."A_Task_logs" USING "btree" ("completed_by");



CREATE INDEX "A_Task_logs_task_id_idx" ON "public"."A_Task_logs" USING "btree" ("task_id");



CREATE INDEX "A_Task_logs_ver2_ExpectedDateTime_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("ExpectedDateTime");



CREATE INDEX "A_Task_logs_ver2_Task_Repeat_Id_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("Task_Repeat_Id");



CREATE INDEX "A_Task_logs_ver2_completed_by_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("completed_by");



CREATE INDEX "A_Task_logs_ver2_created_at_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("created_at");



CREATE INDEX "A_Task_logs_ver2_n8n_ExpectedDateTime_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("ExpectedDateTime");



CREATE INDEX "A_Task_logs_ver2_n8n_Task_Repeat_Id_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("Task_Repeat_Id");



CREATE INDEX "A_Task_logs_ver2_n8n_completed_by_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("completed_by");



CREATE INDEX "A_Task_logs_ver2_n8n_created_at_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("created_at");



CREATE INDEX "A_Task_logs_ver2_n8n_postpone_from_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("postpone_from");



CREATE INDEX "A_Task_logs_ver2_n8n_postpone_to_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("postpone_to");



CREATE INDEX "A_Task_logs_ver2_n8n_status_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("status");



CREATE INDEX "A_Task_logs_ver2_n8n_task_id_idx" ON "public"."A_Task_logs_ver2_n8n" USING "btree" ("task_id");



CREATE INDEX "A_Task_logs_ver2_status_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("status");



CREATE INDEX "A_Task_logs_ver2_task_id_idx" ON "public"."A_Task_logs_ver2" USING "btree" ("task_id");



CREATE INDEX "A_Tasks_Subtask_of_idx" ON "public"."A_Tasks" USING "btree" ("Subtask_of");



CREATE INDEX "A_Tasks_assign_to_idx" ON "public"."A_Tasks" USING "btree" ("assign_to");



CREATE INDEX "A_Tasks_calendar_id_idx" ON "public"."A_Tasks" USING "btree" ("calendar_id");



CREATE INDEX "A_Tasks_completed_by_idx" ON "public"."A_Tasks" USING "btree" ("completed_by");



CREATE INDEX "A_Tasks_creator_id_idx" ON "public"."A_Tasks" USING "btree" ("creator_id");



CREATE INDEX "A_Tasks_nh_id" ON "public"."A_Tasks" USING "btree" ("nursinghome_id", "id");



CREATE INDEX "A_Tasks_nursinghome_id_idx" ON "public"."A_Tasks" USING "btree" ("nursinghome_id");



CREATE INDEX "A_Tasks_resident_id_idx" ON "public"."A_Tasks" USING "btree" ("resident_id");



CREATE INDEX "C_Calendar_nursinghome_id_idx" ON "public"."C_Calendar" USING "btree" ("nursinghome_id");



CREATE INDEX "C_Tasks_Subtask_of_idx" ON "public"."C_Tasks" USING "btree" ("Subtask_of");



CREATE INDEX "C_Tasks_assign_to_idx" ON "public"."C_Tasks" USING "btree" ("assign_to");



CREATE INDEX "C_Tasks_completed_by_idx" ON "public"."C_Tasks" USING "btree" ("completed_by");



CREATE INDEX "C_Tasks_creator_id_idx" ON "public"."C_Tasks" USING "btree" ("creator_id");



CREATE INDEX "C_Tasks_nh_id" ON "public"."C_Tasks" USING "btree" ("nursinghome_id", "id");



CREATE INDEX "C_Tasks_nursinghome_id_idx" ON "public"."C_Tasks" USING "btree" ("nursinghome_id");



CREATE INDEX "C_Tasks_resident_id_idx" ON "public"."C_Tasks" USING "btree" ("resident_id");



CREATE INDEX "C_Tasks_self_ticket_id_idx" ON "public"."C_Tasks" USING "btree" ("self_ticket_id");



CREATE INDEX "Calendar_Subject_subject_idx" ON "public"."Calendar_Subject" USING "btree" ("subject");



CREATE INDEX "Clock In Out_ver2_nursinghome_id_idx" ON "public"."clock_in_out_ver2" USING "btree" ("nursinghome_id");



CREATE INDEX "Clock In Out_ver2_supervisor_id_idx" ON "public"."clock_in_out_ver2" USING "btree" ("supervisor_id");



CREATE INDEX "Clock In Out_ver2_user_id_idx" ON "public"."clock_in_out_ver2" USING "btree" ("user_id");



CREATE INDEX "Clock Special Record_nursinghome_id_idx" ON "public"."Clock Special Record" USING "btree" ("nursinghome_id");



CREATE INDEX "Clock Special Record_supervisor_id_idx" ON "public"."Clock Special Record" USING "btree" ("supervisor_id");



CREATE INDEX "Clock Special Record_user_id_idx" ON "public"."Clock Special Record" USING "btree" ("user_id");



CREATE INDEX "Clock Special Record_user_id_nursinghome_id_timestamp_idx" ON "public"."Clock Special Record" USING "btree" ("user_id", "nursinghome_id", "timestamp");



CREATE INDEX "Post_created_at_idx" ON "public"."Post" USING "btree" ("created_at");



CREATE INDEX "Post_nh_id_id" ON "public"."Post" USING "btree" ("nursinghome_id", "id");



CREATE INDEX "Report_Choice_Subject_idx" ON "public"."Report_Choice" USING "btree" ("Subject");



CREATE INDEX "Resident_Report_Relation_resident_id_idx" ON "public"."Resident_Report_Relation" USING "btree" ("resident_id");



CREATE INDEX "Scale_Report_Log_vital_sign_id_idx" ON "public"."Scale_Report_Log" USING "btree" ("vital_sign_id");



CREATE INDEX "Template_Ticket_created_by_idx" ON "public"."Template_Ticket" USING "btree" ("created_by");



CREATE INDEX "Template_Ticket_nursinghome_id_idx" ON "public"."Template_Ticket" USING "btree" ("nursinghome_id");



CREATE INDEX "Ticket_Template_Tasks_Subtask_of_idx" ON "public"."Template_Tasks" USING "btree" ("Subtask_of");



CREATE INDEX "Ticket_Template_Tasks_assign_to_idx" ON "public"."Template_Tasks" USING "btree" ("assign_to");



CREATE INDEX "Ticket_Template_Tasks_calendar_id_idx" ON "public"."Template_Tasks" USING "btree" ("calendar_id");



CREATE INDEX "Ticket_Template_Tasks_completed_by_idx" ON "public"."Template_Tasks" USING "btree" ("completed_by");



CREATE INDEX "Ticket_Template_Tasks_creator_id_idx" ON "public"."Template_Tasks" USING "btree" ("creator_id");



CREATE INDEX "Ticket_Template_Tasks_nursinghome_id_idx" ON "public"."Template_Tasks" USING "btree" ("nursinghome_id");



CREATE INDEX "Ticket_Template_Tasks_resident_id_idx" ON "public"."Template_Tasks" USING "btree" ("resident_id");



CREATE INDEX "a_task_logs_completed_by_idx" ON "public"."A_Task_logs" USING "btree" ("completed_by");



CREATE INDEX "a_task_logs_task_id_idx" ON "public"."A_Task_logs" USING "btree" ("task_id");



CREATE INDEX "a_task_logs_task_repeat_id_idx" ON "public"."A_Task_logs" USING "btree" ("Task_Repeat_Id");



CREATE INDEX "a_task_logs_ver2_c_task_id" ON "public"."A_Task_logs_ver2" USING "btree" ("c_task_id");



CREATE INDEX "a_task_logs_ver2_task_id" ON "public"."A_Task_logs_ver2" USING "btree" ("task_id");



CREATE INDEX "a_task_with_post_post_id_idx" ON "public"."A_Task_with_Post" USING "btree" ("post_id");



CREATE INDEX "a_tasks_nursinghome_id_idx" ON "public"."A_Tasks" USING "btree" ("nursinghome_id");



CREATE INDEX "a_tasks_resident_id_idx" ON "public"."A_Tasks" USING "btree" ("resident_id");



CREATE INDEX "aths_rel_created_desc_idx" ON "public"."A_Task_History_Seen" USING "btree" ("relatedTaskId", "created_at" DESC, "id" DESC);



CREATE INDEX "commentpost_post_id_idx" ON "public"."CommentPost" USING "btree" ("Post_id");



CREATE INDEX "idx_a_task_logs_ver2_postpone_from" ON "public"."A_Task_logs_ver2" USING "btree" ("postpone_from");



CREATE INDEX "idx_a_task_logs_ver2_postpone_to" ON "public"."A_Task_logs_ver2" USING "btree" ("postpone_to");



CREATE INDEX "idx_a_task_with_post_task_id" ON "public"."A_Task_with_Post" USING "btree" ("task_id");



CREATE INDEX "idx_abnormal_value_and_ticket_calendar_abnormal_value_id" ON "public"."abnormal_value_and_Ticket_Calendar" USING "btree" ("abnormal_value_id");



CREATE INDEX "idx_abnormal_value_and_ticket_calendar_calendar_id" ON "public"."abnormal_value_and_Ticket_Calendar" USING "btree" ("calendar_id");



CREATE INDEX "idx_abnormal_value_dashboard_nursinghome_id" ON "public"."abnormal_value_Dashboard" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_abnormal_value_dashboard_resident_id" ON "public"."abnormal_value_Dashboard" USING "btree" ("resident_id");



CREATE INDEX "idx_abnormal_value_dashboard_seen_user_id" ON "public"."abnormal_value_Dashboard" USING "btree" ("seen_user_id");



CREATE INDEX "idx_answers_question" ON "public"."training_quiz_answers" USING "btree" ("question_id");



CREATE INDEX "idx_answers_session" ON "public"."training_quiz_answers" USING "btree" ("session_id");



CREATE INDEX "idx_b_ticket_created_by" ON "public"."B_Ticket" USING "btree" ("created_by");



CREATE INDEX "idx_b_ticket_med_list_id" ON "public"."B_Ticket" USING "btree" ("med_list_id");



CREATE INDEX "idx_b_ticket_nursinghome_id" ON "public"."B_Ticket" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_b_ticket_resident_id" ON "public"."B_Ticket" USING "btree" ("resident_id");



CREATE INDEX "idx_b_ticket_template_ticket_id" ON "public"."B_Ticket" USING "btree" ("template_ticket_id");



CREATE INDEX "idx_badges_season" ON "public"."training_user_badges" USING "btree" ("season_id");



CREATE INDEX "idx_badges_type" ON "public"."training_badges" USING "btree" ("requirement_type");



CREATE INDEX "idx_badges_user" ON "public"."training_user_badges" USING "btree" ("user_id");



CREATE INDEX "idx_c_calendar_assignna" ON "public"."C_Calendar" USING "btree" ("assignNA");



CREATE INDEX "idx_c_calendar_creator_id" ON "public"."C_Calendar" USING "btree" ("creator_id");



CREATE INDEX "idx_c_calendar_datetime" ON "public"."C_Calendar" USING "btree" ("dateTime");



CREATE INDEX "idx_c_calendar_resident_id" ON "public"."C_Calendar" USING "btree" ("resident_id");



CREATE INDEX "idx_c_calendar_with_post_postid" ON "public"."C_Calendar_with_Post" USING "btree" ("PostId");



CREATE INDEX "idx_c_tasks_calendar_id" ON "public"."C_Tasks" USING "btree" ("calendar_id");



CREATE INDEX "idx_calendar_id" ON "public"."C_Calendar_with_Post" USING "btree" ("CalendarId");



CREATE INDEX "idx_cio2_nh_date_not_incharge" ON "public"."clock_in_out_ver2" USING "btree" ("nursinghome_id", ((("clock_in_timestamp" AT TIME ZONE 'Asia/Bangkok'::"text"))::"date")) WHERE ("Incharge" IS FALSE);



CREATE INDEX "idx_content_season" ON "public"."training_content" USING "btree" ("season_id");



CREATE INDEX "idx_content_topic" ON "public"."training_content" USING "btree" ("topic_id");



CREATE INDEX "idx_dd_record_user_created_at" ON "public"."DD_Record_Clock" USING "btree" ("user_id", "created_at");



CREATE INDEX "idx_doc_bowel_movement_latest_update" ON "public"."Doc_Bowel_Movement" USING "btree" ("latest_Update_by");



CREATE INDEX "idx_doc_bowel_movement_task_log_id" ON "public"."Doc_Bowel_Movement" USING "btree" ("task_log_id");



CREATE INDEX "idx_doc_bowel_movement_user_id" ON "public"."Doc_Bowel_Movement" USING "btree" ("user_id");



CREATE INDEX "idx_fcm_token" ON "public"."profiles" USING "btree" ("fcm_token");



CREATE INDEX "idx_id" ON "public"."residents" USING "btree" ("id");



CREATE INDEX "idx_inbox_post_id" ON "public"."Inbox" USING "btree" ("post_id");



CREATE INDEX "idx_inbox_user_id" ON "public"."Inbox" USING "btree" ("user_id");



CREATE INDEX "idx_invitations_created_at" ON "public"."invitations" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_invitations_lower_email" ON "public"."invitations" USING "btree" ("lower"("user_email"));



CREATE INDEX "idx_invitations_nh" ON "public"."invitations" USING "btree" ("nursinghome_ID");



CREATE INDEX "idx_invitations_nh_created_at" ON "public"."invitations" USING "btree" ("nursinghome_ID", "created_at" DESC);



CREATE INDEX "idx_invitations_nh_lower_email" ON "public"."invitations" USING "btree" ("nursinghome_ID", "lower"("user_email"));



CREATE INDEX "idx_invitations_nursinghome_id" ON "public"."invitations" USING "btree" ("nursinghome_ID");



CREATE INDEX "idx_invitations_user_email_lower" ON "public"."invitations" USING "btree" ("lower"("user_email"));



CREATE INDEX "idx_log_line_queue_log_created_desc" ON "public"."task_log_line_queue" USING "btree" ("log_id", "created_at" DESC, "id" DESC);



CREATE UNIQUE INDEX "idx_meal_resident_date_admin_2cpicture" ON "public"."A_Med_Error_Log" USING "btree" ("meal", "resident_id", "CalendarDate", "admin", "2CPicture") WHERE ("2CPicture" IS NOT NULL);



CREATE UNIQUE INDEX "idx_meal_resident_date_admin_3cpicture" ON "public"."A_Med_Error_Log" USING "btree" ("meal", "resident_id", "CalendarDate", "admin", "3CPicture") WHERE ("3CPicture" IS NOT NULL);



CREATE INDEX "idx_med_db_nursinghome_id" ON "public"."med_DB" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_med_history_user_id" ON "public"."med_history" USING "btree" ("user_id");



CREATE INDEX "idx_medicine_tag_med_list_id" ON "public"."medicine_tag" USING "btree" ("med_list_id");



CREATE INDEX "idx_medicine_tag_resident_id" ON "public"."medicine_tag" USING "btree" ("resident_id");



CREATE INDEX "idx_my_picture_uuid" ON "public"."quickSnap_picture" USING "btree" ("uuid");



CREATE INDEX "idx_new_manual_created_by" ON "public"."New_Manual" USING "btree" ("created_by");



CREATE INDEX "idx_new_manual_modified_by" ON "public"."New_Manual" USING "btree" ("modified_by");



CREATE INDEX "idx_new_manual_refered_post_id" ON "public"."New_Manual" USING "btree" ("refered_post_id");



CREATE INDEX "idx_new_manual_resident_id" ON "public"."New_Manual" USING "btree" ("resident_id");



CREATE INDEX "idx_nursinghome_id" ON "public"."F_timeBlock" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_nursinghomes_id" ON "public"."nursinghomes" USING "btree" ("id");



CREATE INDEX "idx_point_transaction_user_id" ON "public"."Point_Transaction" USING "btree" ("user_id");



CREATE INDEX "idx_post_likes_comment_id" ON "public"."Post_likes" USING "btree" ("Comment_id");



CREATE INDEX "idx_post_likes_post_created_desc" ON "public"."Post_likes" USING "btree" ("Post_id", "created_at" DESC);



CREATE INDEX "idx_post_likes_post_id" ON "public"."Post_likes" USING "btree" ("Post_id");



CREATE INDEX "idx_post_likes_post_user_time" ON "public"."Post_likes" USING "btree" ("Post_id", "user_id", "created_at" DESC, "id" DESC);



CREATE INDEX "idx_post_nh_created_desc" ON "public"."Post" USING "btree" ("nursinghome_id", "created_at" DESC, "id" DESC);



CREATE INDEX "idx_post_nursinghome_id" ON "public"."Post" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_post_qa_id" ON "public"."Post" USING "btree" ("qa_id");



CREATE INDEX "idx_post_quest_accept_post" ON "public"."Post_Quest_Accept" USING "btree" ("post_id");



CREATE INDEX "idx_post_quest_accept_post_id_id_desc" ON "public"."Post_Quest_Accept" USING "btree" ("post_id", "id" DESC);



CREATE INDEX "idx_post_quest_accept_user_id" ON "public"."Post_Quest_Accept" USING "btree" ("user_id");



CREATE INDEX "idx_post_reply_to" ON "public"."Post" USING "btree" ("reply_to");



CREATE INDEX "idx_post_resident_id" ON "public"."Post_Resident_id" USING "btree" ("resident_id");



CREATE INDEX "idx_post_resident_post_id" ON "public"."Post_Resident_id" USING "btree" ("Post_id");



CREATE INDEX "idx_post_tags_post" ON "public"."Post_Tags" USING "btree" ("Post_id");



CREATE INDEX "idx_post_tags_post_id" ON "public"."Post_Tags" USING "btree" ("Post_id");



CREATE INDEX "idx_post_tags_tag" ON "public"."Post_Tags" USING "btree" ("Tag_id");



CREATE INDEX "idx_post_tags_tag_id" ON "public"."Post_Tags" USING "btree" ("Tag_id");



CREATE INDEX "idx_post_user_id" ON "public"."Post" USING "btree" ("user_id");



CREATE INDEX "idx_post_vitalsign_id" ON "public"."Post" USING "btree" ("vitalSign_id");



CREATE INDEX "idx_postdoneby_post" ON "public"."postDoneBy" USING "btree" ("post_id");



CREATE INDEX "idx_postdoneby_post_id" ON "public"."postDoneBy" USING "btree" ("post_id");



CREATE INDEX "idx_postdoneby_post_id_id_desc" ON "public"."postDoneBy" USING "btree" ("post_id", "id" DESC);



CREATE INDEX "idx_postdoneby_user_id" ON "public"."postDoneBy" USING "btree" ("user_id");



CREATE INDEX "idx_postreferenceid_post_id" ON "public"."postReferenceId" USING "btree" ("post_id");



CREATE INDEX "idx_postreferenceid_task_id" ON "public"."postReferenceId" USING "btree" ("task_id");



CREATE INDEX "idx_prn_queue_post_created_desc" ON "public"."prn_post_queue" USING "btree" ("post_id", "created_at" DESC, "id" DESC);



CREATE INDEX "idx_profiles_id" ON "public"."profiles" USING "btree" ("id");



CREATE INDEX "idx_programs_nursinghome_id" ON "public"."programs" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_progress_mastery" ON "public"."training_user_progress" USING "btree" ("mastery_level");



CREATE INDEX "idx_progress_review" ON "public"."training_user_progress" USING "btree" ("next_review_at") WHERE ("next_review_at" IS NOT NULL);



CREATE INDEX "idx_progress_topic" ON "public"."training_user_progress" USING "btree" ("topic_id");



CREATE INDEX "idx_progress_user_season" ON "public"."training_user_progress" USING "btree" ("user_id", "season_id");



CREATE INDEX "idx_questions_difficulty" ON "public"."training_questions" USING "btree" ("difficulty");



CREATE INDEX "idx_questions_season" ON "public"."training_questions" USING "btree" ("season_id");



CREATE INDEX "idx_questions_thinking" ON "public"."training_questions" USING "btree" ("thinking_type");



CREATE INDEX "idx_questions_topic" ON "public"."training_questions" USING "btree" ("topic_id") WHERE ("is_active" = true);



CREATE INDEX "idx_relation_tagtopic_usergroup_tagtopic" ON "public"."Relation_TagTopic_UserGroup" USING "btree" ("tagTopic");



CREATE INDEX "idx_relation_tagtopic_usergroup_usergroup" ON "public"."Relation_TagTopic_UserGroup" USING "btree" ("userGroup");



CREATE INDEX "idx_report_subject_nursinghome_id" ON "public"."Report_Subject" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_resident_caution_manual_resident_id" ON "public"."resident_caution_manual" USING "btree" ("resident_id");



CREATE INDEX "idx_resident_caution_manual_user_id" ON "public"."resident_caution_manual" USING "btree" ("user_id");



CREATE INDEX "idx_resident_disease" ON "public"."resident_underlying_disease" USING "btree" ("resident_id", "underlying_id");



CREATE INDEX "idx_resident_programs" ON "public"."resident_programs" USING "btree" ("resident_id", "program_id");



CREATE INDEX "idx_resident_programs_program_id" ON "public"."resident_programs" USING "btree" ("program_id");



CREATE INDEX "idx_resident_relatives_relatives_id" ON "public"."resident_relatives" USING "btree" ("relatives_id");



CREATE INDEX "idx_resident_relatives_resident_id" ON "public"."resident_relatives" USING "btree" ("resident_id");



CREATE INDEX "idx_resident_report_relation_subject_id" ON "public"."Resident_Report_Relation" USING "btree" ("subject_id");



CREATE INDEX "idx_resident_template_gen_report_resident_id" ON "public"."Resident_Template_Gen_Report" USING "btree" ("resident_id");



CREATE INDEX "idx_resident_zone" ON "public"."residents" USING "btree" ("id", "s_zone");



CREATE INDEX "idx_residents_name_trgm" ON "public"."residents" USING "gin" ("lower"("i_Name_Surname") "public"."gin_trgm_ops");



CREATE INDEX "idx_residents_nursinghome_id" ON "public"."residents" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_residents_nursinghome_status" ON "public"."residents" USING "btree" ("nursinghome_id", "s_status");



CREATE INDEX "idx_residents_nursinghome_zone" ON "public"."residents" USING "btree" ("nursinghome_id", "s_zone");



CREATE INDEX "idx_residents_s_zone" ON "public"."residents" USING "btree" ("s_zone");



CREATE INDEX "idx_residents_status" ON "public"."residents" USING "btree" ("s_status");



CREATE INDEX "idx_residents_status_zone_lowername_id" ON "public"."residents" USING "btree" ("s_status", "s_zone", "lower"("i_Name_Surname"), "id");



CREATE INDEX "idx_residents_status_zone_name_id" ON "public"."residents" USING "btree" ("s_status", "s_zone", "i_Name_Surname", "id");



CREATE INDEX "idx_rlgi_resident_created_id" ON "public"."resident_line_group_id" USING "btree" ("resident_id", "created_at" DESC, "id" DESC) WHERE (("line_group_id" IS NOT NULL) AND ("btrim"("line_group_id") <> ''::"text"));



CREATE INDEX "idx_rud_resident" ON "public"."resident_underlying_disease" USING "btree" ("resident_id");



CREATE INDEX "idx_rud_underlying" ON "public"."resident_underlying_disease" USING "btree" ("underlying_id");



CREATE INDEX "idx_scale_report_log_choice_id" ON "public"."Scale_Report_Log" USING "btree" ("Choice_id");



CREATE INDEX "idx_scale_report_log_relation_id" ON "public"."Scale_Report_Log" USING "btree" ("Relation_id");



CREATE INDEX "idx_scale_report_log_resident_id" ON "public"."Scale_Report_Log" USING "btree" ("resident_id");



CREATE INDEX "idx_scale_report_log_subject_id" ON "public"."Scale_Report_Log" USING "btree" ("Subject_id");



CREATE INDEX "idx_send_out_user_resident_resident_id" ON "public"."send_out_user_resident" USING "btree" ("resident_id");



CREATE INDEX "idx_send_out_user_resident_user_id" ON "public"."send_out_user_resident" USING "btree" ("user_id");



CREATE INDEX "idx_sessions_completed" ON "public"."training_quiz_sessions" USING "btree" ("completed_at" DESC) WHERE ("completed_at" IS NOT NULL);



CREATE INDEX "idx_sessions_progress" ON "public"."training_quiz_sessions" USING "btree" ("progress_id");



CREATE INDEX "idx_sessions_type" ON "public"."training_quiz_sessions" USING "btree" ("quiz_type");



CREATE INDEX "idx_sessions_user" ON "public"."training_quiz_sessions" USING "btree" ("user_id");



CREATE INDEX "idx_soapnote_resident_id" ON "public"."SOAPNote" USING "btree" ("resident_id");



CREATE INDEX "idx_soapnote_user_id" ON "public"."SOAPNote" USING "btree" ("user_id");



CREATE INDEX "idx_status_stay" ON "public"."residents" USING "btree" ("s_status") WHERE ("s_status" = 'Stay'::"text");



CREATE INDEX "idx_streaks_user_season" ON "public"."training_streaks" USING "btree" ("user_id", "season_id");



CREATE INDEX "idx_tagslabel_nursinghome_id" ON "public"."TagsLabel" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_task_logs_ver2_post_created_desc" ON "public"."A_Task_logs_ver2" USING "btree" ("post_id", "created_at" DESC, "id" DESC);



CREATE INDEX "idx_task_type_nursinghome_id" ON "public"."Task_Type" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_template_tasks_ass_template_ticket" ON "public"."Template_Tasks" USING "btree" ("ass_template_Ticket");



CREATE INDEX "idx_trigger_schedule_snooze_log_user_id" ON "public"."trigger_schedule_snooze_log" USING "btree" ("user_id");



CREATE INDEX "idx_underlying_disease_nursinghome_id" ON "public"."underlying_disease" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_user_group_id" ON "public"."user_group" USING "btree" ("id");



CREATE INDEX "idx_user_group_nursinghome_id" ON "public"."user_group" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_user_info_group" ON "public"."user_info" USING "btree" ("group");



CREATE INDEX "idx_user_info_id" ON "public"."user_info" USING "btree" ("id");



CREATE INDEX "idx_user_info_lower_email" ON "public"."user_info" USING "btree" ("lower"("email"));



CREATE INDEX "idx_user_info_nh_email_lower" ON "public"."user_info" USING "btree" ("nursinghome_id", "lower"("email")) WHERE ("email" IS NOT NULL);



CREATE INDEX "idx_user_info_nh_lower_email" ON "public"."user_info" USING "btree" ("nursinghome_id", "lower"("email"));



CREATE INDEX "idx_user_qa_qa_id" ON "public"."user-QA" USING "btree" ("QA_id");



CREATE INDEX "idx_user_qa_user_id" ON "public"."user-QA" USING "btree" ("user_id");



CREATE INDEX "idx_user_with_user_group_user_group_id" ON "public"."user_with_user_group" USING "btree" ("user_group_id");



CREATE INDEX "idx_user_with_user_group_user_id" ON "public"."user_with_user_group" USING "btree" ("user_id");



CREATE INDEX "idx_vitalsign_nursinghome_id" ON "public"."vitalSign" USING "btree" ("nursinghome_id");



CREATE INDEX "idx_vitalsign_sent_queue_created_at" ON "public"."vitalsign_sent_queue" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_vitalsign_user_id" ON "public"."vitalSign" USING "btree" ("user_id");



CREATE INDEX "idx_webhook_trigger_logs_created_at" ON "public"."webhook_trigger_logs" USING "btree" ("created_at");



CREATE INDEX "idx_webhook_trigger_logs_event_type" ON "public"."webhook_trigger_logs" USING "btree" ("event_type");



CREATE INDEX "idx_webhook_trigger_logs_webhook_id" ON "public"."webhook_trigger_logs" USING "btree" ("webhook_id");



CREATE INDEX "idx_workday_nh_year_month" ON "public"."Workday" USING "btree" ("nursinghome_id", "year", "month");



CREATE INDEX "med_example_med_log_start_id_idx" ON "public"."med_example" USING "btree" ("med_log_start_id");



CREATE INDEX "med_example_resident_id_idx" ON "public"."med_example" USING "btree" ("resident_id");



CREATE INDEX "med_example_user_id_idx" ON "public"."med_example" USING "btree" ("user_id");



CREATE INDEX "med_history_created_at_idx" ON "public"."med_history" USING "btree" ("created_at");



CREATE INDEX "med_history_med_list_id_idx" ON "public"."med_history" USING "btree" ("med_list_id");



CREATE INDEX "medicine_List_MedString_idx" ON "public"."medicine_List" USING "btree" ("MedString");



CREATE INDEX "medicine_List_med_DB_id_idx" ON "public"."medicine_List" USING "btree" ("med_DB_id");



CREATE INDEX "medicine_List_resident_id_idx" ON "public"."medicine_List" USING "btree" ("resident_id");



CREATE INDEX "nursinghome_zone_nursinghome_id_idx" ON "public"."nursinghome_zone" USING "btree" ("nursinghome_id");



CREATE INDEX "patient_status_info_type_idx" ON "public"."patient_status" USING "btree" ("info_type");



CREATE INDEX "patient_status_resident_id_idx" ON "public"."patient_status" USING "btree" ("resident_id");



CREATE INDEX "prn_post_queue_created_id_post_desc" ON "public"."prn_post_queue" USING "btree" ("created_at" DESC, "id" DESC, "post_id");



CREATE UNIQUE INDEX "prn_post_queue_unique_waiting_processing" ON "public"."prn_post_queue" USING "btree" ("post_id") WHERE ("status" = ANY (ARRAY['waiting'::"text", 'processing'::"text"]));



CREATE INDEX "resident_programs_resident_id_idx" ON "public"."resident_programs" USING "btree" ("resident_id");



CREATE INDEX "task_log_line_queue_created_id_log_desc" ON "public"."task_log_line_queue" USING "btree" ("created_at" DESC, "id" DESC, "log_id");



CREATE UNIQUE INDEX "uq_vs_queue_active_once" ON "public"."vitalsign_sent_queue" USING "btree" ("vitalsign_id") WHERE ("status" = ANY (ARRAY['pending'::"text", 'PROCESSING'::"text"]));



CREATE UNIQUE INDEX "uq_vs_queue_sent_once" ON "public"."vitalsign_sent_queue" USING "btree" ("vitalsign_id") WHERE ("status" = 'SENT'::"text");



CREATE INDEX "users_roles_role_id_idx" ON "public"."users_roles" USING "btree" ("role_id");



CREATE INDEX "users_roles_user_id_idx" ON "public"."users_roles" USING "btree" ("user_id");



CREATE INDEX "uts_task_seen_id_idx" ON "public"."user_task_seen" USING "btree" ("Task_seen_id");



CREATE UNIQUE INDEX "ux_report_relation_resident_subject_shift" ON "public"."Resident_Report_Relation" USING "btree" ("resident_id", "subject_id", "shift");



CREATE INDEX "vitalSign_created_at_idx" ON "public"."vitalSign" USING "btree" ("created_at");



CREATE INDEX "vitalSign_resident_id_idx" ON "public"."vitalSign" USING "btree" ("resident_id");



CREATE INDEX "vitalsign_resident_created_id_desc" ON "public"."vitalSign" USING "btree" ("resident_id", "created_at" DESC, "id" DESC);



CREATE OR REPLACE VIEW "public"."nursinghome_zone_resident_count" WITH ("security_invoker"='on') AS
 SELECT "nz"."id" AS "zone_id",
    "nz"."zone" AS "zone_name",
    "nz"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "count"("r"."id") AS "resident_count"
   FROM (("public"."nursinghome_zone" "nz"
     LEFT JOIN "public"."residents" "r" ON ((("nz"."id" = "r"."s_zone") AND ("r"."s_status" = 'Stay'::"text"))))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("nz"."nursinghome_id" = "nh"."id")))
  GROUP BY "nz"."id", "nh"."name";



CREATE OR REPLACE VIEW "public"."program_summary_view" WITH ("security_invoker"='on') AS
 SELECT "p"."id" AS "program_id",
    "p"."name" AS "program_name",
    "p"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "count"(DISTINCT "r"."id") AS "number_of_residents"
   FROM ((("public"."programs" "p"
     LEFT JOIN "public"."resident_programs" "rp" ON (("p"."id" = "rp"."program_id")))
     LEFT JOIN "public"."residents" "r" ON (("r"."id" = "rp"."resident_id")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("p"."nursinghome_id" = "nh"."id")))
  GROUP BY "p"."id", "p"."name", "nh"."id", "nh"."name";



CREATE OR REPLACE VIEW "public"."report_subject_summary_view" WITH ("security_invoker"='on') AS
 SELECT "rs"."id" AS "subject_id",
    "rs"."Subject" AS "subject_name",
    "rs"."Description" AS "subject_description",
    "rs"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "count"(DISTINCT "rrl"."id") AS "number_of_reports",
    ( SELECT "array_agg"("rc"."Choice" ORDER BY "rc"."Scale") AS "array_agg"
           FROM "public"."Report_Choice" "rc"
          WHERE ("rc"."Subject" = "rs"."id")
          GROUP BY "rc"."Subject") AS "choices"
   FROM (("public"."Report_Subject" "rs"
     LEFT JOIN "public"."nursinghomes" "nh" ON (("rs"."nursinghome_id" = "nh"."id")))
     LEFT JOIN "public"."Resident_Report_Relation" "rrl" ON (("rs"."id" = "rrl"."subject_id")))
  GROUP BY "rs"."id", "nh"."id";



CREATE OR REPLACE VIEW "public"."underlying_disease_summary_view" WITH ("security_invoker"='on') AS
 SELECT "ud"."id" AS "disease_id",
    "ud"."name" AS "disease_name",
    "ud"."nursinghome_id",
    "nh"."name" AS "nursinghome_name",
    "ud"."pastel_color",
    "count"(DISTINCT "r"."id") AS "number_of_residents"
   FROM ((("public"."underlying_disease" "ud"
     LEFT JOIN "public"."resident_underlying_disease" "rud" ON (("ud"."id" = "rud"."underlying_id")))
     LEFT JOIN "public"."residents" "r" ON (("r"."id" = "rud"."resident_id")))
     LEFT JOIN "public"."nursinghomes" "nh" ON (("ud"."nursinghome_id" = "nh"."id")))
  GROUP BY "ud"."id", "ud"."name", "nh"."id", "nh"."name";



CREATE OR REPLACE VIEW "public"."v_filtered_tasks_with_logs" WITH ("security_invoker"='on') AS
 WITH "current_date_cte" AS (
         SELECT ("now"())::"date" AS "calendar_date",
            "now"() AS "current_datetime",
            (("now"())::"date" + '1 day'::interval) AS "next_calendar_date",
            EXTRACT(dow FROM "now"()) AS "current_dow"
        ), "initial_occurrence" AS (
         SELECT "rt"."id" AS "repeated_task_id",
            "t"."id" AS "task_id",
            "rt"."start_Date",
            "rt"."recurrenceInterval",
            "rt"."recurrenceType",
            "rt"."daysOfWeek",
            "rt"."end_Date",
            "t"."due_date",
            (("rt"."start_Date" + ((("generate_series"((0)::numeric, ((EXTRACT(epoch FROM "age"("now"(), ("rt"."start_Date")::timestamp with time zone)) / (86400)::numeric) / ("rt"."recurrenceInterval")::numeric)) * ("rt"."recurrenceInterval")::numeric))::double precision * '1 day'::interval)))::"date" AS "next_occurrence"
           FROM ("public"."A_Tasks" "t"
             LEFT JOIN "public"."A_Repeated_Task" "rt" ON (("t"."id" = "rt"."task_id")))
          WHERE (("rt"."daysOfWeek" IS NULL) AND ("rt"."recurrenceType" = 'สัปดาห์'::"text"))
        ), "adjusted_tasks" AS (
         SELECT "rt"."id" AS "repeated_task_id",
            "t"."id" AS "task_id",
            "t"."title",
            "t"."description",
            "t"."resident_id",
            "r"."i_Name_Surname" AS "resident_name",
            "r"."s_zone" AS "zone_id",
            "nz"."zone",
            "t"."creator_id",
            "t"."completed_by",
            "t"."due_date",
                CASE
                    WHEN ("r"."nursinghome_id" IS NOT NULL) THEN "r"."nursinghome_id"
                    ELSE "t"."nursinghome_id"
                END AS "nursinghome_id",
            "rt"."recurrenceType",
            "rt"."recurrenceInterval",
            "rt"."start_Date",
            "rt"."end_Date",
            "rt"."startTme" AS "start_time",
            "rt"."endTime" AS "end_time",
            "rt"."timeBlock",
            "t"."taskType",
            "t"."form_url",
            "rt"."daysOfWeek",
            "rt"."recurNote",
            COALESCE("r"."s_status", 'zone'::"text") AS "resident_status",
            COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
                CASE
                    WHEN (("rt"."startTme" >= '07:00:00'::time without time zone) AND ("rt"."startTme" <= '07:59:59'::time without time zone)) THEN 1
                    WHEN (("rt"."startTme" >= '08:00:00'::time without time zone) AND ("rt"."startTme" <= '08:59:59'::time without time zone)) THEN 2
                    WHEN (("rt"."startTme" >= '09:00:00'::time without time zone) AND ("rt"."startTme" <= '09:59:59'::time without time zone)) THEN 3
                    WHEN (("rt"."startTme" >= '10:00:00'::time without time zone) AND ("rt"."startTme" <= '10:59:59'::time without time zone)) THEN 4
                    WHEN (("rt"."startTme" >= '11:00:00'::time without time zone) AND ("rt"."startTme" <= '11:59:59'::time without time zone)) THEN 5
                    WHEN (("rt"."startTme" >= '12:00:00'::time without time zone) AND ("rt"."startTme" <= '12:59:59'::time without time zone)) THEN 6
                    WHEN (("rt"."startTme" >= '13:00:00'::time without time zone) AND ("rt"."startTme" <= '13:59:59'::time without time zone)) THEN 7
                    WHEN (("rt"."startTme" >= '14:00:00'::time without time zone) AND ("rt"."startTme" <= '14:59:59'::time without time zone)) THEN 8
                    WHEN (("rt"."startTme" >= '15:00:00'::time without time zone) AND ("rt"."startTme" <= '15:59:59'::time without time zone)) THEN 9
                    WHEN (("rt"."startTme" >= '16:00:00'::time without time zone) AND ("rt"."startTme" <= '16:59:59'::time without time zone)) THEN 10
                    WHEN (("rt"."startTme" >= '17:00:00'::time without time zone) AND ("rt"."startTme" <= '17:59:59'::time without time zone)) THEN 11
                    WHEN (("rt"."startTme" >= '18:00:00'::time without time zone) AND ("rt"."startTme" <= '18:59:59'::time without time zone)) THEN 12
                    WHEN (("rt"."startTme" >= '19:00:00'::time without time zone) AND ("rt"."startTme" <= '19:59:59'::time without time zone)) THEN 13
                    WHEN (("rt"."startTme" >= '20:00:00'::time without time zone) AND ("rt"."startTme" <= '20:59:59'::time without time zone)) THEN 14
                    WHEN (("rt"."startTme" >= '21:00:00'::time without time zone) AND ("rt"."startTme" <= '21:59:59'::time without time zone)) THEN 15
                    WHEN (("rt"."startTme" >= '22:00:00'::time without time zone) AND ("rt"."startTme" <= '22:59:59'::time without time zone)) THEN 16
                    WHEN (("rt"."startTme" >= '23:00:00'::time without time zone) AND ("rt"."startTme" <= '23:59:59'::time without time zone)) THEN 17
                    WHEN (("rt"."startTme" >= '00:00:00'::time without time zone) AND ("rt"."startTme" <= '00:59:59'::time without time zone)) THEN 18
                    WHEN (("rt"."startTme" >= '01:00:00'::time without time zone) AND ("rt"."startTme" <= '01:59:59'::time without time zone)) THEN 19
                    WHEN (("rt"."startTme" >= '02:00:00'::time without time zone) AND ("rt"."startTme" <= '02:59:59'::time without time zone)) THEN 20
                    WHEN (("rt"."startTme" >= '03:00:00'::time without time zone) AND ("rt"."startTme" <= '03:59:59'::time without time zone)) THEN 21
                    WHEN (("rt"."startTme" >= '04:00:00'::time without time zone) AND ("rt"."startTme" <= '04:59:59'::time without time zone)) THEN 22
                    WHEN (("rt"."startTme" >= '05:00:00'::time without time zone) AND ("rt"."startTme" <= '05:59:59'::time without time zone)) THEN 23
                    WHEN (("rt"."startTme" >= '06:00:00'::time without time zone) AND ("rt"."startTme" <= '06:59:59'::time without time zone)) THEN 24
                    ELSE 0
                END AS "time_slot",
            ("count"("l"."created_at") > 0) AS "has_log_date",
            "array_agg"("date"("l"."created_at") ORDER BY "l"."created_at" DESC) AS "log_dates"
           FROM (((("public"."A_Tasks" "t"
             LEFT JOIN "public"."A_Task_logs" "l" ON (("t"."id" = "l"."task_id")))
             LEFT JOIN "public"."A_Repeated_Task" "rt" ON (("t"."id" = "rt"."task_id")))
             LEFT JOIN "public"."residents" "r" ON (("t"."resident_id" = "r"."id")))
             LEFT JOIN "public"."nursinghome_zone" "nz" ON (("r"."s_zone" = "nz"."id")))
          GROUP BY "rt"."id", "t"."id", "r"."i_Name_Surname", "r"."s_zone", "r"."nursinghome_id", "nz"."zone", "rt"."recurrenceType", "rt"."recurrenceInterval", "rt"."start_Date", "rt"."end_Date", "rt"."startTme", "rt"."endTime", "rt"."timeBlock", "t"."taskType", "t"."form_url", "rt"."daysOfWeek", "rt"."recurNote", "r"."s_status", "r"."s_special_status"
        )
 SELECT "at"."repeated_task_id",
    "at"."task_id",
    "at"."title",
    "at"."description",
    "at"."resident_id",
    "at"."resident_name",
    "at"."zone_id",
    "at"."zone",
    "at"."creator_id",
    "at"."completed_by",
    "at"."due_date",
    "at"."nursinghome_id",
    "at"."recurrenceType",
    "at"."recurrenceInterval",
    "at"."start_Date",
    "at"."end_Date",
    "at"."start_time",
    "at"."end_time",
    "at"."timeBlock",
    "at"."taskType",
    "at"."form_url",
    "at"."daysOfWeek",
    "at"."recurNote",
    "at"."resident_status",
    "at"."s_special_status",
    "at"."time_slot",
    "at"."has_log_date",
    "at"."log_dates"
   FROM (("adjusted_tasks" "at"
     JOIN "current_date_cte" "cdc" ON (true))
     LEFT JOIN "initial_occurrence" "io" ON (("at"."repeated_task_id" = "io"."repeated_task_id")))
  WHERE (
        CASE "at"."recurrenceType"
            WHEN 'วัน'::"text" THEN (((((EXTRACT(epoch FROM (("cdc"."calendar_date")::timestamp without time zone - ("at"."start_Date")::timestamp without time zone)) / (86400)::numeric))::integer)::bigint % "at"."recurrenceInterval") = 0)
            WHEN 'สัปดาห์'::"text" THEN ((((((EXTRACT(epoch FROM (("cdc"."calendar_date")::timestamp without time zone - ("at"."start_Date")::timestamp without time zone)) / (604800)::numeric))::integer)::bigint % "at"."recurrenceInterval") = 0) AND
            CASE
                WHEN (("at"."start_time" >= '00:00:00'::time without time zone) AND ("at"."start_time" <= '06:59:59'::time without time zone)) THEN true
                WHEN ("at"."daysOfWeek" IS NULL) THEN (EXTRACT(dow FROM "cdc"."calendar_date") = EXTRACT(dow FROM "at"."start_Date"))
                ELSE ((EXTRACT(dow FROM "cdc"."calendar_date"))::"text" = ANY ("string_to_array"("regexp_replace"(("at"."daysOfWeek")::"text", '[\[\]\"]'::"text", ''::"text", 'g'::"text"), ','::"text")))
            END)
            WHEN 'เดือน'::"text" THEN (((((EXTRACT(year FROM "age"(("cdc"."calendar_date")::timestamp with time zone, ("at"."start_Date")::timestamp with time zone)) * (12)::numeric) + EXTRACT(month FROM "age"(("cdc"."calendar_date")::timestamp with time zone, ("at"."start_Date")::timestamp with time zone))) % ("at"."recurrenceInterval")::numeric) = (0)::numeric) AND (EXTRACT(day FROM "cdc"."calendar_date") = EXTRACT(day FROM "at"."start_Date")))
            WHEN 'ปี'::"text" THEN (((EXTRACT(year FROM "age"(("cdc"."calendar_date")::timestamp with time zone, ("at"."start_Date")::timestamp with time zone)) % ("at"."recurrenceInterval")::numeric) = (0)::numeric) AND (EXTRACT(month FROM "cdc"."calendar_date") = EXTRACT(month FROM "at"."start_Date")) AND (EXTRACT(day FROM "cdc"."calendar_date") = EXTRACT(day FROM "at"."start_Date")))
            ELSE false
        END AND ("at"."start_time" >= '00:00:00'::time without time zone) AND ("at"."start_time" < '24:00:00'::time without time zone) AND (("at"."end_Date" IS NULL) OR ("cdc"."calendar_date" <= "at"."end_Date")));



CREATE OR REPLACE VIEW "public"."v_tasks_with_logs" WITH ("security_invoker"='on') AS
 WITH "latest_logs" AS (
         SELECT DISTINCT ON ("tl"."Task_Repeat_Id") "tl"."Task_Repeat_Id",
            "tl"."completed_by",
            "ui"."nickname" AS "completed_by_nickname",
            "tl"."completed_at",
            "tl"."status" AS "log_status",
            "tl"."Descript" AS "log_descript",
            "tl"."ExpectedDateTime"
           FROM ("public"."A_Task_logs_ver2" "tl"
             LEFT JOIN "public"."user_info" "ui" ON (("tl"."completed_by" = "ui"."id")))
          ORDER BY "tl"."Task_Repeat_Id", "tl"."ExpectedDateTime" DESC
        )
 SELECT "rt"."id" AS "repeated_task_id",
    "t"."id" AS "task_id",
    "t"."title",
    "t"."description",
    "t"."resident_id",
    "r"."i_Name_Surname" AS "resident_name",
    "r"."s_zone" AS "zone_id",
    "nz"."zone",
    "t"."creator_id",
    "t"."due_date",
        CASE
            WHEN ("r"."nursinghome_id" IS NOT NULL) THEN "r"."nursinghome_id"
            ELSE "t"."nursinghome_id"
        END AS "nursinghome_id",
    "rt"."recurrenceType",
    "rt"."recurrenceInterval",
    "rt"."start_Date",
    "rt"."end_Date",
    "rt"."startTme" AS "start_time",
    "rt"."endTime" AS "end_time",
    "rt"."timeBlock",
    "t"."taskType",
    "t"."form_url",
        CASE
            WHEN (("rt"."recurrenceType" = 'สัปดาห์'::"text") AND (("rt"."daysOfWeek" IS NULL) OR ("array_length"("rt"."daysOfWeek", 1) = 0))) THEN ARRAY[
            CASE EXTRACT(dow FROM "rt"."start_Date")
                WHEN 0 THEN 'อาทิตย์'::"text"
                WHEN 1 THEN 'จันทร์'::"text"
                WHEN 2 THEN 'อังคาร'::"text"
                WHEN 3 THEN 'พุธ'::"text"
                WHEN 4 THEN 'พฤหัส'::"text"
                WHEN 5 THEN 'ศุกร์'::"text"
                WHEN 6 THEN 'เสาร์'::"text"
                ELSE NULL::"text"
            END]
            ELSE "rt"."daysOfWeek"
        END AS "daysofweek",
    "rt"."recurNote",
    "rt"."recurring_dates",
    "rt"."sampleImageURL",
        CASE
            WHEN (("rt"."daysOfWeek" IS NULL) OR ("array_length"("rt"."daysOfWeek", 1) = 0)) THEN '{}'::"text"[]
            ELSE ARRAY( SELECT
                    CASE "d"."day"
                        WHEN 'จันทร์'::"text" THEN 'อาทิตย์'::"text"
                        WHEN 'อังคาร'::"text" THEN 'จันทร์'::"text"
                        WHEN 'พุธ'::"text" THEN 'อังคาร'::"text"
                        WHEN 'พฤหัส'::"text" THEN 'พุธ'::"text"
                        WHEN 'ศุกร์'::"text" THEN 'พฤหัส'::"text"
                        WHEN 'เสาร์'::"text" THEN 'ศุกร์'::"text"
                        WHEN 'อาทิตย์'::"text" THEN 'เสาร์'::"text"
                        ELSE NULL::"text"
                    END AS "case"
               FROM "unnest"("rt"."daysOfWeek") "d"("day")
              ORDER BY
                    CASE "d"."day"
                        WHEN 'จันทร์'::"text" THEN 1
                        WHEN 'อังคาร'::"text" THEN 2
                        WHEN 'พุธ'::"text" THEN 3
                        WHEN 'พฤหัส'::"text" THEN 4
                        WHEN 'ศุกร์'::"text" THEN 5
                        WHEN 'เสาร์'::"text" THEN 6
                        WHEN 'อาทิตย์'::"text" THEN 7
                        ELSE NULL::integer
                    END)
        END AS "previous_days",
    ("count"("l"."created_at") > 0) AS "has_log_date",
    COALESCE("r"."s_status", 'zone'::"text") AS "resident_status",
    COALESCE("r"."s_special_status", '-'::"text") AS "s_special_status",
        CASE
            WHEN (("rt"."startTme" >= '07:00:00'::time without time zone) AND ("rt"."startTme" <= '07:59:59'::time without time zone)) THEN 1
            WHEN (("rt"."startTme" >= '08:00:00'::time without time zone) AND ("rt"."startTme" <= '08:59:59'::time without time zone)) THEN 2
            WHEN (("rt"."startTme" >= '09:00:00'::time without time zone) AND ("rt"."startTme" <= '09:59:59'::time without time zone)) THEN 3
            WHEN (("rt"."startTme" >= '10:00:00'::time without time zone) AND ("rt"."startTme" <= '10:59:59'::time without time zone)) THEN 4
            WHEN (("rt"."startTme" >= '11:00:00'::time without time zone) AND ("rt"."startTme" <= '11:59:59'::time without time zone)) THEN 5
            WHEN (("rt"."startTme" >= '12:00:00'::time without time zone) AND ("rt"."startTme" <= '12:59:59'::time without time zone)) THEN 6
            WHEN (("rt"."startTme" >= '13:00:00'::time without time zone) AND ("rt"."startTme" <= '13:59:59'::time without time zone)) THEN 7
            WHEN (("rt"."startTme" >= '14:00:00'::time without time zone) AND ("rt"."startTme" <= '14:59:59'::time without time zone)) THEN 8
            WHEN (("rt"."startTme" >= '15:00:00'::time without time zone) AND ("rt"."startTme" <= '15:59:59'::time without time zone)) THEN 9
            WHEN (("rt"."startTme" >= '16:00:00'::time without time zone) AND ("rt"."startTme" <= '16:59:59'::time without time zone)) THEN 10
            WHEN (("rt"."startTme" >= '17:00:00'::time without time zone) AND ("rt"."startTme" <= '17:59:59'::time without time zone)) THEN 11
            WHEN (("rt"."startTme" >= '18:00:00'::time without time zone) AND ("rt"."startTme" <= '18:59:59'::time without time zone)) THEN 12
            WHEN (("rt"."startTme" >= '19:00:00'::time without time zone) AND ("rt"."startTme" <= '19:59:59'::time without time zone)) THEN 13
            WHEN (("rt"."startTme" >= '20:00:00'::time without time zone) AND ("rt"."startTme" <= '20:59:59'::time without time zone)) THEN 14
            WHEN (("rt"."startTme" >= '21:00:00'::time without time zone) AND ("rt"."startTme" <= '21:59:59'::time without time zone)) THEN 15
            WHEN (("rt"."startTme" >= '22:00:00'::time without time zone) AND ("rt"."startTme" <= '22:59:59'::time without time zone)) THEN 16
            WHEN (("rt"."startTme" >= '23:00:00'::time without time zone) AND ("rt"."startTme" <= '23:59:59'::time without time zone)) THEN 17
            WHEN (("rt"."startTme" >= '00:00:00'::time without time zone) AND ("rt"."startTme" <= '06:59:59'::time without time zone)) THEN 18
            ELSE 0
        END AS "time_slot",
        CASE
            WHEN (("rt"."startTme" >= '00:00:00'::time without time zone) AND ("rt"."startTme" <= '06:59:59'::time without time zone)) THEN 1
            ELSE 0
        END AS "is_next_day",
    "ll"."completed_by",
    "ll"."completed_by_nickname",
    "ll"."completed_at",
    "ll"."log_status",
    "ll"."log_descript",
    "ll"."ExpectedDateTime" AS "latest_expecteddatetime"
   FROM ((((("public"."A_Tasks" "t"
     LEFT JOIN "public"."A_Task_logs" "l" ON (("t"."id" = "l"."task_id")))
     LEFT JOIN "public"."A_Repeated_Task" "rt" ON (("t"."id" = "rt"."task_id")))
     LEFT JOIN "public"."residents" "r" ON (("t"."resident_id" = "r"."id")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("r"."s_zone" = "nz"."id")))
     LEFT JOIN "latest_logs" "ll" ON (("rt"."id" = "ll"."Task_Repeat_Id")))
  WHERE ("rt"."id" IS NOT NULL)
  GROUP BY "rt"."id", "t"."id", "r"."i_Name_Surname", "r"."s_zone", "r"."nursinghome_id", "nz"."zone", "rt"."recurrenceType", "rt"."recurrenceInterval", "rt"."start_Date", "rt"."end_Date", "rt"."startTme", "rt"."endTime", "rt"."timeBlock", "t"."taskType", "t"."form_url", "rt"."daysOfWeek", "rt"."recurNote", "rt"."recurring_dates", "rt"."sampleImageURL", "r"."s_status", "r"."s_special_status", "ll"."completed_by", "ll"."completed_by_nickname", "ll"."completed_at", "ll"."log_status", "ll"."log_descript", "ll"."ExpectedDateTime"
  ORDER BY "rt"."id", "t"."id";



CREATE OR REPLACE VIEW "public"."n8n_agent_resident_profile" WITH ("security_invoker"='on') AS
 SELECT "r"."nursinghome_id",
    "r"."id" AS "resident_id",
    "r"."i_Name_Surname" AS "full_name",
    "r"."i_gender" AS "gender",
    ("date_part"('year'::"text", "age"(("r"."i_DOB")::timestamp with time zone)))::integer AS "age",
    "r"."i_picture_url",
    "r"."s_special_status",
    COALESCE("string_agg"(DISTINCT "ud"."name", ', '::"text"), ''::"text") AS "underlying_diseases",
    "r"."m_past_history" AS "past_history",
    "r"."m_dietary" AS "dietary",
    "r"."s_reason_being_here" AS "chief_reason",
    COALESCE(( SELECT "string_agg"("p"."name", ', '::"text" ORDER BY "p"."id") AS "string_agg"
           FROM ("public"."resident_programs" "rp"
             JOIN "public"."programs" "p" ON (("rp"."program_id" = "p"."id")))
          WHERE ("rp"."resident_id" = "r"."id")), ''::"text") AS "program_list",
    "r"."medResponsible" AS "med_responsible",
    "r"."โรงพยาบาล" AS "hospital",
    "r"."SocialSecuruty" AS "social_security",
    "r"."m_fooddrug_allergy" AS "allergy",
    "r"."is_processed",
    ( SELECT "rlgi"."line_group_id"
           FROM "public"."resident_line_group_id" "rlgi"
          WHERE (("rlgi"."resident_id" = "r"."id") AND ("rlgi"."line_group_id" IS NOT NULL) AND ("btrim"("rlgi"."line_group_id") <> ''::"text"))
          ORDER BY "rlgi"."created_at" DESC, "rlgi"."id" DESC
         LIMIT 1) AS "line_group_id",
    COALESCE("nz"."zone", '-'::"text") AS "zone",
    "r"."updated_at" AS "last_update"
   FROM ((("public"."residents" "r"
     LEFT JOIN "public"."resident_underlying_disease" "rud" ON (("rud"."resident_id" = "r"."id")))
     LEFT JOIN "public"."underlying_disease" "ud" ON (("ud"."id" = "rud"."underlying_id")))
     LEFT JOIN "public"."nursinghome_zone" "nz" ON (("nz"."id" = "r"."s_zone")))
  WHERE ("r"."s_status" = 'Stay'::"text")
  GROUP BY "r"."id", "r"."updated_at", "nz"."zone", "r"."nursinghome_id";



CREATE OR REPLACE TRIGGER "fn_call_webhook_safely" AFTER INSERT ON "public"."vitalsign_sent_queue" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://n8nocr.ireneplus.app/webhook/498ef9ec-6c8b-430c-941f-6f6eb15e0a5e', 'POST', '{"Content-type":"application/json"}', '{}', '10000');



CREATE OR REPLACE TRIGGER "pushNotification" AFTER INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://amthgthvrxhlxpttioxu.supabase.co/functions/v1/push', 'POST', '{"Content-type":"application/json"}', '{}', '1000');



CREATE OR REPLACE TRIGGER "set_daysofweek" BEFORE INSERT OR UPDATE ON "public"."A_Repeated_Task" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_update_daysofweek"();



CREATE OR REPLACE TRIGGER "set_updated_at_on_residents" BEFORE UPDATE ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trg_check_fcm_token" BEFORE INSERT OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."check_fcm_token"();



CREATE OR REPLACE TRIGGER "trg_confirm_image_log_queue" AFTER UPDATE OF "confirmImage" ON "public"."A_Task_logs_ver2" FOR EACH ROW WHEN ((("new"."confirmImage" IS NOT NULL) AND ("btrim"("new"."confirmImage") <> ''::"text") AND (("old"."confirmImage" IS NULL) OR ("btrim"("old"."confirmImage") = ''::"text")))) EXECUTE FUNCTION "public"."fn_insert_log_line_queue"();



CREATE OR REPLACE TRIGGER "trg_insert_log_line_queue2" AFTER INSERT ON "public"."task_log_line_queue" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://n8nocr.ireneplus.app/webhook/e861f519-b674-4746-a0be-dae22e88661e', 'POST', '{}', '{}', '10000');



CREATE OR REPLACE TRIGGER "trg_insert_prn_post_queue" AFTER INSERT ON "public"."prn_post_queue" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://n8nocr.ireneplus.app/webhook/81f85f22-70c6-4958-9139-a5799f4f100e', 'POST', '{}', '{}', '10000');



CREATE OR REPLACE TRIGGER "trg_insert_vitalsign_sent_queue" AFTER INSERT ON "public"."vitalsign_sent_queue" FOR EACH ROW EXECUTE FUNCTION "public"."fn_call_webhook_safely"();



CREATE OR REPLACE TRIGGER "trg_post_id_update" AFTER UPDATE OF "post_id" ON "public"."A_Task_logs_ver2" FOR EACH ROW EXECUTE FUNCTION "public"."fn_process_post_id_update"();



CREATE OR REPLACE TRIGGER "trg_prn_enqueue_if_send_to_relative" AFTER INSERT OR UPDATE OF "Tag_Topics" ON "public"."Post" FOR EACH ROW EXECUTE FUNCTION "public"."post_enqueue_if_send_to_relative"();



CREATE OR REPLACE TRIGGER "trg_set_must_complete_by_image" BEFORE INSERT OR UPDATE ON "public"."A_Repeated_Task" FOR EACH ROW EXECUTE FUNCTION "public"."set_must_complete_by_image"();



CREATE OR REPLACE TRIGGER "trg_single_active_season" BEFORE INSERT OR UPDATE OF "is_active" ON "public"."training_seasons" FOR EACH ROW EXECUTE FUNCTION "public"."ensure_single_active_season"();



CREATE OR REPLACE TRIGGER "trg_vitalsign_queue_ai" AFTER INSERT ON "public"."vitalSign" FOR EACH ROW EXECUTE FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"();



CREATE OR REPLACE TRIGGER "trigger_add_resident_report_relations" AFTER INSERT ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."add_resident_report_relations"();



CREATE OR REPLACE TRIGGER "trigger_add_resident_template_gen_report_entry" AFTER INSERT ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."add_resident_template_gen_report_entry"();



CREATE OR REPLACE TRIGGER "trigger_assign_pastel_color" BEFORE INSERT ON "public"."underlying_disease" FOR EACH ROW EXECUTE FUNCTION "public"."assign_pastel_color"();



CREATE OR REPLACE TRIGGER "trigger_assign_program_pastel_color" BEFORE INSERT ON "public"."programs" FOR EACH ROW EXECUTE FUNCTION "public"."assign_program_pastel_color"();



CREATE OR REPLACE TRIGGER "trigger_cancel_all_cron_jobs" AFTER UPDATE OF "cancel_snooze" ON "public"."user_info" FOR EACH ROW WHEN (("new"."cancel_snooze" IS TRUE)) EXECUTE FUNCTION "public"."cancel_all_cron_jobs"();



CREATE OR REPLACE TRIGGER "trigger_cleanup_snooze" AFTER UPDATE OF "snooze" ON "public"."user_info" FOR EACH ROW WHEN ((("old"."snooze" IS TRUE) AND ("new"."snooze" IS FALSE))) EXECUTE FUNCTION "public"."cleanup_snooze_cron"();



CREATE OR REPLACE TRIGGER "trigger_create_post_tag_entries" AFTER INSERT OR UPDATE ON "public"."Post" FOR EACH ROW EXECUTE FUNCTION "public"."create_post_tag_entries"();



CREATE OR REPLACE TRIGGER "trigger_create_resident_underlying_disease" AFTER INSERT OR UPDATE ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."create_resident_underlying_disease_entries"();



CREATE OR REPLACE TRIGGER "trigger_notify_new_comment" AFTER INSERT ON "public"."CommentPost" FOR EACH ROW EXECUTE FUNCTION "public"."notify_new_comment"();



CREATE OR REPLACE TRIGGER "trigger_schedule_snooze" AFTER UPDATE OF "snooze" ON "public"."user_info" FOR EACH ROW WHEN (("new"."snooze" IS TRUE)) EXECUTE FUNCTION "public"."schedule_snooze_cron"();



CREATE OR REPLACE TRIGGER "trigger_update_resident_report_relation" AFTER UPDATE OF "Report_Scale_Day", "Report_Scale_Night" ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."update_resident_report_relation"();



CREATE OR REPLACE TRIGGER "trigger_update_zone_id" AFTER INSERT OR UPDATE OF "zone_text" ON "public"."residents" FOR EACH ROW EXECUTE FUNCTION "public"."update_zone_id_based_on_text"();



CREATE OR REPLACE TRIGGER "uCoJ15RUTxlCvQThOUGJ/b84064d9-c81f-42b8-a0e2-f10f30899c91" AFTER INSERT ON "public"."B_Ticket" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://dov46t.buildship.run/executeWorkflow/uCoJ15RUTxlCvQThOUGJ/b84064d9-c81f-42b8-a0e2-f10f30899c91', 'POST', '{"Content-Type":"application/json"}', '{}', '5000');



ALTER TABLE ONLY "public"."A_Med_Error_Log"
    ADD CONSTRAINT "A_Med_Error_Log_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_2C_completed_by_fkey" FOREIGN KEY ("2C_completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_2C_completed_by_fkey1" FOREIGN KEY ("2C_completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_3C_Compleated_by_fkey" FOREIGN KEY ("3C_Compleated_by") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_ArrangeMed_by_fkey" FOREIGN KEY ("ArrangeMed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Med_logs"
    ADD CONSTRAINT "A_Med_logs_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."A_Repeated_Task"
    ADD CONSTRAINT "A_Repeated_Task_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."A_Tasks"("id");



ALTER TABLE ONLY "public"."A_Task_History_Seen"
    ADD CONSTRAINT "A_Task_History_Seen_relatedTaskId_fkey" FOREIGN KEY ("relatedTaskId") REFERENCES "public"."A_Tasks"("id");



ALTER TABLE ONLY "public"."A_Task_logs"
    ADD CONSTRAINT "A_Task_logs_Task_Repeat_Id_fkey" FOREIGN KEY ("Task_Repeat_Id") REFERENCES "public"."A_Repeated_Task"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Task_logs"
    ADD CONSTRAINT "A_Task_logs_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."A_Task_logs"
    ADD CONSTRAINT "A_Task_logs_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Task_logs"
    ADD CONSTRAINT "A_Task_logs_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."A_Tasks"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_c_task_id_fkey" FOREIGN KEY ("c_task_id") REFERENCES "public"."C_Tasks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2_n8n"
    ADD CONSTRAINT "A_Task_logs_ver2_n8n_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2_n8n"
    ADD CONSTRAINT "A_Task_logs_ver2_n8n_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2_n8n"
    ADD CONSTRAINT "A_Task_logs_ver2_n8n_postpone_from_fkey" FOREIGN KEY ("postpone_from") REFERENCES "public"."A_Task_logs_ver2"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2_n8n"
    ADD CONSTRAINT "A_Task_logs_ver2_n8n_postpone_to_fkey" FOREIGN KEY ("postpone_to") REFERENCES "public"."A_Task_logs_ver2"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_postpone_from_fkey" FOREIGN KEY ("postpone_from") REFERENCES "public"."A_Task_logs_ver2"("id");



ALTER TABLE ONLY "public"."A_Task_logs_ver2"
    ADD CONSTRAINT "A_Task_logs_ver2_postpone_to_fkey" FOREIGN KEY ("postpone_to") REFERENCES "public"."A_Task_logs_ver2"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_Subtask_of_fkey" FOREIGN KEY ("Subtask_of") REFERENCES "public"."A_Tasks"("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_assign_to_fkey" FOREIGN KEY ("assign_to") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_assign_to_fkey1" FOREIGN KEY ("assign_to") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_calendar_id_fkey" FOREIGN KEY ("calendar_id") REFERENCES "public"."C_Calendar"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_creator_id_fkey1" FOREIGN KEY ("creator_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."A_Tasks"
    ADD CONSTRAINT "A_Tasks_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_created_by_fkey1" FOREIGN KEY ("created_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_med_list_id_fkey" FOREIGN KEY ("med_list_id") REFERENCES "public"."medicine_List"("id");



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id");



ALTER TABLE ONLY "public"."B_Ticket"
    ADD CONSTRAINT "B_Ticket_template_ticket_id_fkey" FOREIGN KEY ("template_ticket_id") REFERENCES "public"."Template_Ticket"("id");



ALTER TABLE ONLY "public"."C_Calendar"
    ADD CONSTRAINT "C_Calendar_assignNA_fkey" FOREIGN KEY ("assignNA") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."C_Calendar"
    ADD CONSTRAINT "C_Calendar_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."C_Calendar"
    ADD CONSTRAINT "C_Calendar_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."C_Calendar"
    ADD CONSTRAINT "C_Calendar_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."C_Calendar_with_Post"
    ADD CONSTRAINT "C_Calendar_with_Post_CalendarId_fkey" FOREIGN KEY ("CalendarId") REFERENCES "public"."C_Calendar"("id");



ALTER TABLE ONLY "public"."C_Calendar_with_Post"
    ADD CONSTRAINT "C_Calendar_with_Post_PostId_fkey" FOREIGN KEY ("PostId") REFERENCES "public"."Post"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_Subtask_of_fkey" FOREIGN KEY ("Subtask_of") REFERENCES "public"."A_Tasks"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_assign_to_fkey" FOREIGN KEY ("assign_to") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_assign_to_fkey1" FOREIGN KEY ("assign_to") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_calendar_id_fkey" FOREIGN KEY ("calendar_id") REFERENCES "public"."C_Calendar"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_creator_id_fkey1" FOREIGN KEY ("creator_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."C_Tasks"
    ADD CONSTRAINT "C_Tasks_self_ticket_id_fkey" FOREIGN KEY ("self_ticket_id") REFERENCES "public"."B_Ticket"("id");



ALTER TABLE ONLY "public"."clock_in_out_ver2"
    ADD CONSTRAINT "Clock In Out_ver2_duty_buyer_fkey" FOREIGN KEY ("duty_buyer") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."clock_in_out_ver2"
    ADD CONSTRAINT "Clock In Out_ver2_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."clock_in_out_ver2"
    ADD CONSTRAINT "Clock In Out_ver2_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."clock_in_out_ver2"
    ADD CONSTRAINT "Clock In Out_ver2_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Clock Special Record"
    ADD CONSTRAINT "Clock Special Record_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Clock Special Record"
    ADD CONSTRAINT "Clock Special Record_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Clock Special Record"
    ADD CONSTRAINT "Clock Special Record_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."CommentPost"
    ADD CONSTRAINT "CommentPost_Post_id_fkey" FOREIGN KEY ("Post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DD_Record_Clock"
    ADD CONSTRAINT "DD_Record_aproover_id_fkey" FOREIGN KEY ("aproover_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."DD_Record_Clock"
    ADD CONSTRAINT "DD_Record_calendar_appointment_id_fkey" FOREIGN KEY ("calendar_appointment_id") REFERENCES "public"."C_Calendar"("id");



ALTER TABLE ONLY "public"."DD_Record_Clock"
    ADD CONSTRAINT "DD_Record_calendar_bill_id_fkey" FOREIGN KEY ("calendar_bill_id") REFERENCES "public"."C_Calendar"("id");



ALTER TABLE ONLY "public"."DD_Record_Clock"
    ADD CONSTRAINT "DD_Record_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Doc_Bowel_Movement"
    ADD CONSTRAINT "Doc_Bowel_Movement_latest_Update_by_fkey" FOREIGN KEY ("latest_Update_by") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Doc_Bowel_Movement"
    ADD CONSTRAINT "Doc_Bowel_Movement_task_log_id_fkey" FOREIGN KEY ("task_log_id") REFERENCES "public"."A_Task_logs_ver2"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Doc_Bowel_Movement"
    ADD CONSTRAINT "Doc_Bowel_Movement_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Duty_Transaction_Clock"
    ADD CONSTRAINT "Duty_Transaction_Clock_user_1_fkey" FOREIGN KEY ("user_1") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Duty_Transaction_Clock"
    ADD CONSTRAINT "Duty_Transaction_Clock_user_2_fkey" FOREIGN KEY ("user_2") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."F_timeBlock"
    ADD CONSTRAINT "F_timeBlock_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Inbox"
    ADD CONSTRAINT "Inbox_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Inbox"
    ADD CONSTRAINT "Inbox_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Medication Error Rate"
    ADD CONSTRAINT "Medication Error Rate_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."New_Manual"
    ADD CONSTRAINT "New_Manual_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."New_Manual"
    ADD CONSTRAINT "New_Manual_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."New_Manual"
    ADD CONSTRAINT "New_Manual_refered_post_id_fkey" FOREIGN KEY ("refered_post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."New_Manual"
    ADD CONSTRAINT "New_Manual_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Point_Transaction"
    ADD CONSTRAINT "Point_Transaction_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_DD_id_fkey" FOREIGN KEY ("DD_id") REFERENCES "public"."DD_Record_Clock"("id");



ALTER TABLE ONLY "public"."Post_Quest_Accept"
    ADD CONSTRAINT "Post_Quest_Accept_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Post_Resident_id"
    ADD CONSTRAINT "Post_Resident_id_Post_id_fkey" FOREIGN KEY ("Post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post_Resident_id"
    ADD CONSTRAINT "Post_Resident_id_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post_Tags"
    ADD CONSTRAINT "Post_Tags_Post_id_fkey" FOREIGN KEY ("Post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post_Tags"
    ADD CONSTRAINT "Post_Tags_Tag_id_fkey" FOREIGN KEY ("Tag_id") REFERENCES "public"."TagsLabel"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post_likes"
    ADD CONSTRAINT "Post_likes_Comment_id_fkey" FOREIGN KEY ("Comment_id") REFERENCES "public"."CommentPost"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post_likes"
    ADD CONSTRAINT "Post_likes_Post_id_fkey" FOREIGN KEY ("Post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_qa_id_fkey" FOREIGN KEY ("qa_id") REFERENCES "public"."QATable"("id");



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_reply_to_fkey" FOREIGN KEY ("reply_to") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Post"
    ADD CONSTRAINT "Post_vitalSign_id_fkey" FOREIGN KEY ("vitalSign_id") REFERENCES "public"."vitalSign"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Relation_TagTopic_UserGroup"
    ADD CONSTRAINT "Relation_TagTopic_UserGroup_tagTopic_fkey" FOREIGN KEY ("tagTopic") REFERENCES "public"."TagsLabel"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Relation_TagTopic_UserGroup"
    ADD CONSTRAINT "Relation_TagTopic_UserGroup_userGroup_fkey" FOREIGN KEY ("userGroup") REFERENCES "public"."user_group"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."SOAPNote"
    ADD CONSTRAINT "SOAPNote_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id");



ALTER TABLE ONLY "public"."SOAPNote"
    ADD CONSTRAINT "SOAPNote_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."TagsLabel"
    ADD CONSTRAINT "TagsLabel_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Task_Type"
    ADD CONSTRAINT "Task_Type_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Template_Tasks_ass_template_Ticket_fkey" FOREIGN KEY ("ass_template_Ticket") REFERENCES "public"."Template_Ticket"("id");



ALTER TABLE ONLY "public"."Template_Ticket"
    ADD CONSTRAINT "Template_Ticket_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Template_Ticket"
    ADD CONSTRAINT "Template_Ticket_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_Subtask_of_fkey" FOREIGN KEY ("Subtask_of") REFERENCES "public"."A_Tasks"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_assign_to_fkey" FOREIGN KEY ("assign_to") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_assign_to_fkey1" FOREIGN KEY ("assign_to") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_calendar_id_fkey" FOREIGN KEY ("calendar_id") REFERENCES "public"."C_Calendar"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_completed_by_fkey1" FOREIGN KEY ("completed_by") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_creator_id_fkey1" FOREIGN KEY ("creator_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Template_Tasks"
    ADD CONSTRAINT "Ticket_Template_Tasks_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Workday"
    ADD CONSTRAINT "Workday_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."abnormal_value_Dashboard"
    ADD CONSTRAINT "abnormal_value_Dashboard_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."abnormal_value_Dashboard"
    ADD CONSTRAINT "abnormal_value_Dashboard_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."abnormal_value_Dashboard"
    ADD CONSTRAINT "abnormal_value_Dashboard_seen_user_id_fkey" FOREIGN KEY ("seen_user_id") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET DEFAULT;



ALTER TABLE ONLY "public"."abnormal_value_and_Ticket_Calendar"
    ADD CONSTRAINT "abnormal_value_and_Ticket_Calendar_abnormal_value_id_fkey" FOREIGN KEY ("abnormal_value_id") REFERENCES "public"."abnormal_value_Dashboard"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."abnormal_value_and_Ticket_Calendar"
    ADD CONSTRAINT "abnormal_value_and_Ticket_Calendar_calendar_id_fkey" FOREIGN KEY ("calendar_id") REFERENCES "public"."C_Calendar"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clock_break_time_nursinghome"
    ADD CONSTRAINT "break_time_nursinghome_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_nursinghome_ID_fkey" FOREIGN KEY ("nursinghome_ID") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."medMadeChange"
    ADD CONSTRAINT "medMadeChange_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."C_Calendar"("id");



ALTER TABLE ONLY "public"."medMadeChange"
    ADD CONSTRAINT "medMadeChange_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id");



ALTER TABLE ONLY "public"."med_DB"
    ADD CONSTRAINT "med_DB_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."med_example"
    ADD CONSTRAINT "med_example_med_log_start_id_fkey" FOREIGN KEY ("med_log_start_id") REFERENCES "public"."A_Med_logs"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."med_example"
    ADD CONSTRAINT "med_example_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."med_example"
    ADD CONSTRAINT "med_example_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."med_history"
    ADD CONSTRAINT "med_history_med_list_id_fkey" FOREIGN KEY ("med_list_id") REFERENCES "public"."medicine_List"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."med_history"
    ADD CONSTRAINT "med_history_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."medicine_List"
    ADD CONSTRAINT "medicine_List_med_DB_id_fkey" FOREIGN KEY ("med_DB_id") REFERENCES "public"."med_DB"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medicine_List"
    ADD CONSTRAINT "medicine_List_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medicine_tag"
    ADD CONSTRAINT "medicine_tag_med_list_id_fkey" FOREIGN KEY ("med_list_id") REFERENCES "public"."medicine_List"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medicine_tag"
    ADD CONSTRAINT "medicine_tag_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."quickSnap_picture"
    ADD CONSTRAINT "my_Picture_uuid_fkey" FOREIGN KEY ("uuid") REFERENCES "public"."user_info"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nursinghome_zone"
    ADD CONSTRAINT "nursinghome_zone_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_status"
    ADD CONSTRAINT "patient_status_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."postDoneBy"
    ADD CONSTRAINT "postDoneBy_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."postReferenceId"
    ADD CONSTRAINT "postReferenceId_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."postReferenceId"
    ADD CONSTRAINT "postReferenceId_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."A_Tasks"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."prn_post_queue"
    ADD CONSTRAINT "prn_post_queue_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."programs"
    ADD CONSTRAINT "programs_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Post_Quest_Accept"
    ADD CONSTRAINT "public_Post_Quest_Accept_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Report_Choice"
    ADD CONSTRAINT "public_Report_Choice_Subject_fkey" FOREIGN KEY ("Subject") REFERENCES "public"."Report_Subject"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Report_Subject"
    ADD CONSTRAINT "public_Report_Subject_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."Resident_Report_Relation"
    ADD CONSTRAINT "public_Resident_Report_Relation_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Resident_Report_Relation"
    ADD CONSTRAINT "public_Resident_Report_Relation_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "public"."Report_Subject"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "public_Scale_Report_Log_Choice_id_fkey" FOREIGN KEY ("Choice_id") REFERENCES "public"."Report_Choice"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "public_Scale_Report_Log_Relation_id_fkey" FOREIGN KEY ("Relation_id") REFERENCES "public"."Resident_Report_Relation"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "public_Scale_Report_Log_Subject_id_fkey" FOREIGN KEY ("Subject_id") REFERENCES "public"."Report_Subject"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "public_Scale_Report_Log_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Scale_Report_Log"
    ADD CONSTRAINT "public_Scale_Report_Log_vital_sign_id_fkey" FOREIGN KEY ("vital_sign_id") REFERENCES "public"."vitalSign"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medicine_List"
    ADD CONSTRAINT "public_medicine_List_MedString_fkey" FOREIGN KEY ("MedString") REFERENCES "public"."medicine_List"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."postDoneBy"
    ADD CONSTRAINT "public_postDoneBy_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."Post"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."resident_caution_manual"
    ADD CONSTRAINT "resident_caution_manual_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."resident_caution_manual"
    ADD CONSTRAINT "resident_caution_manual_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."resident_line_group_id"
    ADD CONSTRAINT "resident_line_group_id_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."resident_programs"
    ADD CONSTRAINT "resident_programs_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."resident_programs"
    ADD CONSTRAINT "resident_programs_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."resident_relatives"
    ADD CONSTRAINT "resident_relatives_relatives_id_fkey" FOREIGN KEY ("relatives_id") REFERENCES "public"."relatives"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."resident_relatives"
    ADD CONSTRAINT "resident_relatives_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Resident_Template_Gen_Report"
    ADD CONSTRAINT "resident_template_gen_report_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."resident_underlying_disease"
    ADD CONSTRAINT "resident_underlying_disease_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."resident_underlying_disease"
    ADD CONSTRAINT "resident_underlying_disease_underlying_id_fkey" FOREIGN KEY ("underlying_id") REFERENCES "public"."underlying_disease"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."residents"
    ADD CONSTRAINT "residents_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."residents"
    ADD CONSTRAINT "residents_s_zone_fkey" FOREIGN KEY ("s_zone") REFERENCES "public"."nursinghome_zone"("id");



ALTER TABLE ONLY "public"."send_out_user_resident"
    ADD CONSTRAINT "send_out_user_resident_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."send_out_user_resident"
    ADD CONSTRAINT "send_out_user_resident_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."training_content"
    ADD CONSTRAINT "training_content_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id");



ALTER TABLE ONLY "public"."training_content"
    ADD CONSTRAINT "training_content_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "public"."training_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_questions"
    ADD CONSTRAINT "training_questions_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id");



ALTER TABLE ONLY "public"."training_questions"
    ADD CONSTRAINT "training_questions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "public"."training_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_answers"
    ADD CONSTRAINT "training_quiz_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."training_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_answers"
    ADD CONSTRAINT "training_quiz_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."training_quiz_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_sessions"
    ADD CONSTRAINT "training_quiz_sessions_progress_id_fkey" FOREIGN KEY ("progress_id") REFERENCES "public"."training_user_progress"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_sessions"
    ADD CONSTRAINT "training_quiz_sessions_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_sessions"
    ADD CONSTRAINT "training_quiz_sessions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "public"."training_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_quiz_sessions"
    ADD CONSTRAINT "training_quiz_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_streaks"
    ADD CONSTRAINT "training_streaks_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_streaks"
    ADD CONSTRAINT "training_streaks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_user_badges"
    ADD CONSTRAINT "training_user_badges_badge_id_fkey" FOREIGN KEY ("badge_id") REFERENCES "public"."training_badges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_user_badges"
    ADD CONSTRAINT "training_user_badges_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id");



ALTER TABLE ONLY "public"."training_user_badges"
    ADD CONSTRAINT "training_user_badges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_user_progress"
    ADD CONSTRAINT "training_user_progress_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."training_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_user_progress"
    ADD CONSTRAINT "training_user_progress_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "public"."training_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_user_progress"
    ADD CONSTRAINT "training_user_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."underlying_disease"
    ADD CONSTRAINT "underlying_disease_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."user-QA"
    ADD CONSTRAINT "user-QA_QA_id_fkey" FOREIGN KEY ("QA_id") REFERENCES "public"."QATable"("id");



ALTER TABLE ONLY "public"."user-QA"
    ADD CONSTRAINT "user-QA_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."user_group"
    ADD CONSTRAINT "user_group_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id");



ALTER TABLE ONLY "public"."user_info"
    ADD CONSTRAINT "user_info_group_fkey" FOREIGN KEY ("group") REFERENCES "public"."user_group"("id");



ALTER TABLE ONLY "public"."user_info"
    ADD CONSTRAINT "user_info_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_task_seen"
    ADD CONSTRAINT "user_task_seen_Task_seen_id_fkey" FOREIGN KEY ("Task_seen_id") REFERENCES "public"."A_Task_History_Seen"("id");



ALTER TABLE ONLY "public"."user_with_user_group"
    ADD CONSTRAINT "user_with_user_group_user_group_id_fkey" FOREIGN KEY ("user_group_id") REFERENCES "public"."user_group"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_with_user_group"
    ADD CONSTRAINT "user_with_user_group_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vitalSign"
    ADD CONSTRAINT "vitalSign_nursinghome_id_fkey" FOREIGN KEY ("nursinghome_id") REFERENCES "public"."nursinghomes"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vitalSign"
    ADD CONSTRAINT "vitalSign_resident_id_fkey" FOREIGN KEY ("resident_id") REFERENCES "public"."residents"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vitalSign"
    ADD CONSTRAINT "vitalSign_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."user_info"("id");



ALTER TABLE ONLY "public"."vitalsign_sent_queue"
    ADD CONSTRAINT "vitalsign_sent_queue_vitalsign_id_fkey" FOREIGN KEY ("vitalsign_id") REFERENCES "public"."vitalSign"("id");



ALTER TABLE "public"."A_Med_Error_Log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Med_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Repeated_Task" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Task_History_Seen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Task_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Task_logs_ver2" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Task_logs_ver2_n8n" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Task_with_Post" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."A_Tasks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Allow authenticated users to view webhook logs" ON "public"."webhook_trigger_logs" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."B_Ticket" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."C_Calendar" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."C_Calendar_with_Post" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."C_Tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Calendar_Subject" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Clock Special Record" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CommentPost" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DD_Record_Clock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Doc_Bowel_Movement" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Duty_Transaction_Clock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."F_timeBlock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Inbox" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Medication Error Rate" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."New_Manual" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Point_Transaction" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Post" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Post_Quest_Accept" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Post_Resident_id" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Post_Tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Post_likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Public can view roles" ON "public"."roles" FOR SELECT TO "anon", "authenticated" USING (true);



CREATE POLICY "Public can view users_roles" ON "public"."users_roles" FOR SELECT TO "anon", "authenticated" USING (true);



ALTER TABLE "public"."QATable" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Relation_TagTopic_UserGroup" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Report_Choice" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Report_Subject" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Resident_Report_Relation" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Resident_Template_Gen_Report" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."SOAPNote" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Scale_Report_Log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Service role can delete roles" ON "public"."roles" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can delete users_roles" ON "public"."users_roles" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can insert roles" ON "public"."roles" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can insert users_roles" ON "public"."users_roles" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can update roles" ON "public"."roles" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Service role can update users_roles" ON "public"."users_roles" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."TagsLabel" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Task_Type" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Template_Tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Template_Ticket" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Workday" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."abnormal_value_Dashboard" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."abnormal_value_and_Ticket_Calendar" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "allow all" ON "public"."training_topics" USING (true) WITH CHECK (true);



CREATE POLICY "allowAll" ON "public"."Doc_Bowel_Movement" USING (true);



CREATE POLICY "allowAll" ON "public"."SOAPNote" USING (true);



CREATE POLICY "allowAll" ON "public"."quickSnap_picture" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."A_Med_Error_Log" USING (true);



CREATE POLICY "allowall" ON "public"."A_Med_logs" USING (true);



CREATE POLICY "allowall" ON "public"."A_Repeated_Task" USING (true);



CREATE POLICY "allowall" ON "public"."A_Task_History_Seen" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."A_Task_logs" USING (true);



CREATE POLICY "allowall" ON "public"."A_Task_logs_ver2" USING (true);



CREATE POLICY "allowall" ON "public"."A_Task_logs_ver2_n8n" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."A_Task_with_Post" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."A_Tasks" USING (true);



CREATE POLICY "allowall" ON "public"."B_Ticket" USING (true);



CREATE POLICY "allowall" ON "public"."C_Calendar" USING (true);



CREATE POLICY "allowall" ON "public"."C_Calendar_with_Post" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."C_Tasks" USING (true);



CREATE POLICY "allowall" ON "public"."Calendar_Subject" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Clock Special Record" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."CommentPost" USING (true);



CREATE POLICY "allowall" ON "public"."DD_Record_Clock" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Duty_Transaction_Clock" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."F_timeBlock" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Inbox" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Medication Error Rate" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."New_Manual" USING (true);



CREATE POLICY "allowall" ON "public"."Point_Transaction" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Post" USING (true);



CREATE POLICY "allowall" ON "public"."Post_Quest_Accept" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Post_Tags" USING (true);



CREATE POLICY "allowall" ON "public"."Post_likes" USING (true);



CREATE POLICY "allowall" ON "public"."QATable" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Relation_TagTopic_UserGroup" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Report_Choice" USING (true);



CREATE POLICY "allowall" ON "public"."Report_Subject" USING (true);



CREATE POLICY "allowall" ON "public"."Resident_Report_Relation" USING (true);



CREATE POLICY "allowall" ON "public"."Resident_Template_Gen_Report" USING (true);



CREATE POLICY "allowall" ON "public"."Scale_Report_Log" USING (true);



CREATE POLICY "allowall" ON "public"."TagsLabel" USING (true);



CREATE POLICY "allowall" ON "public"."Task_Type" USING (true);



CREATE POLICY "allowall" ON "public"."Template_Tasks" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Template_Ticket" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."Workday" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."abnormal_value_Dashboard" USING (true);



CREATE POLICY "allowall" ON "public"."abnormal_value_and_Ticket_Calendar" USING (true);



CREATE POLICY "allowall" ON "public"."cleanup_snooze_log" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."clock_break_time_nursinghome" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."clock_in_out_ver2" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."dummyFinishDutyTable" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."invitations" USING (true);



CREATE POLICY "allowall" ON "public"."medMadeChange" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."med_DB" USING (true);



CREATE POLICY "allowall" ON "public"."med_example" USING (true);



CREATE POLICY "allowall" ON "public"."med_history" USING (true);



CREATE POLICY "allowall" ON "public"."medicine_List" USING (true);



CREATE POLICY "allowall" ON "public"."medicine_tag" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."notifications" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."nursinghome_zone" USING (true);



CREATE POLICY "allowall" ON "public"."nursinghomes" USING (true);



CREATE POLICY "allowall" ON "public"."pastel_color" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."patient_status" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."postDoneBy" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."postReferenceId" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."prn_post_queue" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."profiles" USING (true);



CREATE POLICY "allowall" ON "public"."program_summary_daily" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."programs" USING (true);



CREATE POLICY "allowall" ON "public"."relatives" USING (true);



CREATE POLICY "allowall" ON "public"."resident_caution_manual" USING (true);



CREATE POLICY "allowall" ON "public"."resident_line_group_id" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."resident_programs" USING (true);



CREATE POLICY "allowall" ON "public"."resident_relatives" USING (true);



CREATE POLICY "allowall" ON "public"."resident_underlying_disease" USING (true);



CREATE POLICY "allowall" ON "public"."residents" USING (true);



CREATE POLICY "allowall" ON "public"."send_out_user_resident" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."task_log_line_queue" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."task_summary" USING (true);



CREATE POLICY "allowall" ON "public"."underlying_disease" USING (true);



CREATE POLICY "allowall" ON "public"."user-QA" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."user_group" USING (true);



CREATE POLICY "allowall" ON "public"."user_task_seen" USING (true) WITH CHECK (true);



CREATE POLICY "allowall" ON "public"."user_with_user_group" USING (true);



CREATE POLICY "allowall" ON "public"."vitalSign" USING (true);



CREATE POLICY "allowall" ON "public"."vitalsign_sent_queue" USING (true) WITH CHECK (true);



CREATE POLICY "allowall2" ON "public"."Post_Resident_id" USING (true) WITH CHECK (true);



CREATE POLICY "allowall2" ON "public"."user_info" USING (true) WITH CHECK (true);



ALTER TABLE "public"."cleanup_snooze_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clock_break_time_nursinghome" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clock_in_out_ver2" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dummyFinishDutyTable" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "insert_own_badges" ON "public"."training_user_badges" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."invitations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lloell" ON "public"."trigger_schedule_snooze_log" USING (true) WITH CHECK (true);



ALTER TABLE "public"."medMadeChange" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."med_DB" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."med_example" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."med_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medicine_List" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medicine_tag" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."nursinghome_zone" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."nursinghomes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "own_answers" ON "public"."training_quiz_answers" USING ((EXISTS ( SELECT 1
   FROM "public"."training_quiz_sessions"
  WHERE (("training_quiz_sessions"."id" = "training_quiz_answers"."session_id") AND ("training_quiz_sessions"."user_id" = "auth"."uid"())))));



CREATE POLICY "own_progress" ON "public"."training_user_progress" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "own_sessions" ON "public"."training_quiz_sessions" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "own_streaks" ON "public"."training_streaks" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."pastel_color" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patient_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."postDoneBy" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."postReferenceId" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prn_post_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."program_summary_daily" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."programs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quickSnap_picture" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "read_badges" ON "public"."training_badges" FOR SELECT USING (("is_active" = true));



CREATE POLICY "read_content" ON "public"."training_content" FOR SELECT USING (("is_active" = true));



CREATE POLICY "read_questions" ON "public"."training_questions" FOR SELECT USING (("is_active" = true));



CREATE POLICY "read_seasons" ON "public"."training_seasons" FOR SELECT USING (true);



CREATE POLICY "read_streaks" ON "public"."training_streaks" FOR SELECT USING (true);



CREATE POLICY "read_topics" ON "public"."training_topics" FOR SELECT USING (("is_active" = true));



CREATE POLICY "read_user_badges" ON "public"."training_user_badges" FOR SELECT USING (true);



ALTER TABLE "public"."relatives" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."resident_caution_manual" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."resident_line_group_id" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."resident_programs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."resident_relatives" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."resident_underlying_disease" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."residents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."send_out_user_resident" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_log_line_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_summary" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_content" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_quiz_answers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_quiz_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_seasons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_streaks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_topics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_user_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."training_user_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trigger_schedule_snooze_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."underlying_disease" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user-QA" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_group" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_info" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_task_seen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_with_user_group" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vitalSign" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vitalsign_sent_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."webhook_trigger_logs" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";










ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."A_Task_logs_ver2";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."A_Task_logs_ver2_n8n";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."Post";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."clock_in_out_ver2";






GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "postgres";
















































GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";




























































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."add_abnormal_value_to_dashboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_abnormal_value_to_dashboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_abnormal_value_to_dashboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."add_resident_report_relations"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_resident_report_relations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_resident_report_relations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."add_resident_template_gen_report_entry"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_resident_template_gen_report_entry"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_resident_template_gen_report_entry"() TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_pastel_color"() TO "anon";
GRANT ALL ON FUNCTION "public"."assign_pastel_color"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_pastel_color"() TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_program_pastel_color"() TO "anon";
GRANT ALL ON FUNCTION "public"."assign_program_pastel_color"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_program_pastel_color"() TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_fill_active_season"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_fill_active_season"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_fill_active_season"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_all_cron_jobs"() TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_all_cron_jobs"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_all_cron_jobs"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_and_award_badges"("p_user_id" "uuid", "p_season_id" "uuid", "p_session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_and_award_badges"("p_user_id" "uuid", "p_season_id" "uuid", "p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_and_award_badges"("p_user_id" "uuid", "p_season_id" "uuid", "p_session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_clock_in_out_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_clock_in_out_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_clock_in_out_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_fcm_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_fcm_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_fcm_token"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_secondcpictureurl_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_secondcpictureurl_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_secondcpictureurl_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_snooze_cron"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_snooze_cron"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_snooze_cron"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_post_tag_entries"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_post_tag_entries"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_post_tag_entries"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_resident_program_entries"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_resident_program_entries"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_resident_program_entries"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_resident_underlying_disease_entries"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_resident_underlying_disease_entries"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_resident_underlying_disease_entries"() TO "service_role";



GRANT ALL ON FUNCTION "public"."date_only"("ts" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."date_only"("ts" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."date_only"("ts" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."debug_insert_log_line_queue"() TO "anon";
GRANT ALL ON FUNCTION "public"."debug_insert_log_line_queue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."debug_insert_log_line_queue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."debug_update_log"() TO "anon";
GRANT ALL ON FUNCTION "public"."debug_update_log"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."debug_update_log"() TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_single_active_season"() TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_single_active_season"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_single_active_season"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_call_webhook_safely"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_call_webhook_safely"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_call_webhook_safely"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_enqueue_from_scale_log"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_enqueue_from_scale_log"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_enqueue_from_scale_log"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_enqueue_vitalsign_sent_queue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_insert_log_line_queue"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_insert_log_line_queue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_insert_log_line_queue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_log_webhook_trigger"("p_webhook_id" "text", "p_event_type" "text", "p_payload" "jsonb", "p_response_status" integer, "p_response_body" "text", "p_error_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."fn_log_webhook_trigger"("p_webhook_id" "text", "p_event_type" "text", "p_payload" "jsonb", "p_response_status" integer, "p_response_body" "text", "p_error_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_log_webhook_trigger"("p_webhook_id" "text", "p_event_type" "text", "p_payload" "jsonb", "p_response_status" integer, "p_response_body" "text", "p_error_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_process_post_id_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_process_post_id_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_process_post_id_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_active_season"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_season"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_season"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_progress"("p_user_id" "uuid", "p_topic_id" "text", "p_season_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_progress"("p_user_id" "uuid", "p_topic_id" "text", "p_season_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_progress"("p_user_id" "uuid", "p_topic_id" "text", "p_season_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_random_questions"("p_topic_id" "text", "p_count" integer, "p_season_id" "uuid", "p_exclude_session_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_random_questions"("p_topic_id" "text", "p_count" integer, "p_season_id" "uuid", "p_exclude_session_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_random_questions"("p_topic_id" "text", "p_count" integer, "p_season_id" "uuid", "p_exclude_session_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_service_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_service_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_service_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_dashboard"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_dashboard"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_dashboard"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."insert_task_summary"() TO "anon";
GRANT ALL ON FUNCTION "public"."insert_task_summary"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_task_summary"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_new_comment"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_new_comment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_new_comment"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_new_post"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_new_post"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_new_post"() TO "service_role";



GRANT ALL ON FUNCTION "public"."post_enqueue_if_send_to_relative"() TO "anon";
GRANT ALL ON FUNCTION "public"."post_enqueue_if_send_to_relative"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."post_enqueue_if_send_to_relative"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_third_check_img"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_third_check_img"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_third_check_img"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_program_summary_daily"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_program_summary_daily"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_program_summary_daily"() TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_duplicates_from_lists"() TO "anon";
GRANT ALL ON FUNCTION "public"."remove_duplicates_from_lists"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_duplicates_from_lists"() TO "service_role";



GRANT ALL ON FUNCTION "public"."schedule_snooze_cron"() TO "anon";
GRANT ALL ON FUNCTION "public"."schedule_snooze_cron"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."schedule_snooze_cron"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_active_season_for_question"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_active_season_for_question"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_active_season_for_question"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_must_complete_by_image"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_must_complete_by_image"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_must_complete_by_image"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."track_content_read"("p_user_id" "uuid", "p_topic_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."track_content_read"("p_user_id" "uuid", "p_topic_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."track_content_read"("p_user_id" "uuid", "p_topic_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_update_daysofweek"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_update_daysofweek"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_update_daysofweek"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_daysofweek"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_daysofweek"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_daysofweek"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_index"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_index"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_index"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_notification_on_like"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_notification_on_like"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_notification_on_like"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_notification_on_unlike"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_notification_on_unlike"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_notification_on_unlike"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_progress_on_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_progress_on_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_progress_on_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_resident_report_relation"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_resident_report_relation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_resident_report_relation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_streak"("p_user_id" "uuid", "p_season_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_streak"("p_user_id" "uuid", "p_season_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_streak"("p_user_id" "uuid", "p_season_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_zone_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_zone_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_zone_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"("resident_id_input" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"("resident_id_input" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_zone_id_based_on_text"("resident_id_input" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";










































GRANT ALL ON TABLE "public"."A_Med_Error_Log" TO "anon";
GRANT ALL ON TABLE "public"."A_Med_Error_Log" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Med_Error_Log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Med_Error_Log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Med_Error_Log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Med_Error_Log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Med_logs" TO "anon";
GRANT ALL ON TABLE "public"."A_Med_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Med_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Med_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Med_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Med_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Repeated_Task" TO "anon";
GRANT ALL ON TABLE "public"."A_Repeated_Task" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Repeated_Task" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Repeated_Task_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Repeated_Task_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Repeated_Task_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Task_History_Seen" TO "anon";
GRANT ALL ON TABLE "public"."A_Task_History_Seen" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Task_History_Seen" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Task_History_Seen_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Task_History_Seen_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Task_History_Seen_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Task_logs" TO "anon";
GRANT ALL ON TABLE "public"."A_Task_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Task_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Task_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Task_logs_ver2" TO "anon";
GRANT ALL ON TABLE "public"."A_Task_logs_ver2" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Task_logs_ver2" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Task_logs_ver2_n8n" TO "anon";
GRANT ALL ON TABLE "public"."A_Task_logs_ver2_n8n" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Task_logs_ver2_n8n" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_n8n_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_n8n_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Task_logs_ver2_n8n_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Task_with_Post" TO "anon";
GRANT ALL ON TABLE "public"."A_Task_with_Post" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Task_with_Post" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Task_with_Post_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Task_with_Post_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Task_with_Post_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."A_Tasks" TO "anon";
GRANT ALL ON TABLE "public"."A_Tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."A_Tasks" TO "service_role";



GRANT ALL ON SEQUENCE "public"."A_Tasks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."A_Tasks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."A_Tasks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."B_Ticket" TO "anon";
GRANT ALL ON TABLE "public"."B_Ticket" TO "authenticated";
GRANT ALL ON TABLE "public"."B_Ticket" TO "service_role";



GRANT ALL ON SEQUENCE "public"."B_Ticket_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."B_Ticket_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."B_Ticket_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."C_Tasks" TO "anon";
GRANT ALL ON TABLE "public"."C_Tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."C_Tasks" TO "service_role";



GRANT ALL ON TABLE "public"."residents" TO "anon";
GRANT ALL ON TABLE "public"."residents" TO "authenticated";
GRANT ALL ON TABLE "public"."residents" TO "service_role";



GRANT ALL ON TABLE "public"."user_info" TO "anon";
GRANT ALL ON TABLE "public"."user_info" TO "authenticated";
GRANT ALL ON TABLE "public"."user_info" TO "service_role";



GRANT ALL ON TABLE "public"."B_Ticket_view" TO "anon";
GRANT ALL ON TABLE "public"."B_Ticket_view" TO "authenticated";
GRANT ALL ON TABLE "public"."B_Ticket_view" TO "service_role";



GRANT ALL ON TABLE "public"."C_Calendar" TO "anon";
GRANT ALL ON TABLE "public"."C_Calendar" TO "authenticated";
GRANT ALL ON TABLE "public"."C_Calendar" TO "service_role";



GRANT ALL ON SEQUENCE "public"."C_Calendar_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."C_Calendar_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."C_Calendar_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."C_Calendar_with_Post" TO "anon";
GRANT ALL ON TABLE "public"."C_Calendar_with_Post" TO "authenticated";
GRANT ALL ON TABLE "public"."C_Calendar_with_Post" TO "service_role";



GRANT ALL ON SEQUENCE "public"."C_Calendar_with_Post_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."C_Calendar_with_Post_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."C_Calendar_with_Post_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."C_Tasks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."C_Tasks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."C_Tasks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Calendar_Subject" TO "anon";
GRANT ALL ON TABLE "public"."Calendar_Subject" TO "authenticated";
GRANT ALL ON TABLE "public"."Calendar_Subject" TO "service_role";



GRANT ALL ON TABLE "public"."clock_in_out_ver2" TO "anon";
GRANT ALL ON TABLE "public"."clock_in_out_ver2" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_in_out_ver2" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Clock In Out_ver2_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Clock In Out_ver2_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Clock In Out_ver2_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Clock Special Record" TO "anon";
GRANT ALL ON TABLE "public"."Clock Special Record" TO "authenticated";
GRANT ALL ON TABLE "public"."Clock Special Record" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Clock Special Record_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Clock Special Record_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Clock Special Record_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."CommentPost" TO "anon";
GRANT ALL ON TABLE "public"."CommentPost" TO "authenticated";
GRANT ALL ON TABLE "public"."CommentPost" TO "service_role";



GRANT ALL ON SEQUENCE "public"."CommentPost_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."CommentPost_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."CommentPost_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."DD_Record_Clock" TO "anon";
GRANT ALL ON TABLE "public"."DD_Record_Clock" TO "authenticated";
GRANT ALL ON TABLE "public"."DD_Record_Clock" TO "service_role";



GRANT ALL ON SEQUENCE "public"."DD_Record_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."DD_Record_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."DD_Record_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Doc_Bowel_Movement" TO "anon";
GRANT ALL ON TABLE "public"."Doc_Bowel_Movement" TO "authenticated";
GRANT ALL ON TABLE "public"."Doc_Bowel_Movement" TO "service_role";



GRANT ALL ON TABLE "public"."Doc_Bowel_Movement_View" TO "anon";
GRANT ALL ON TABLE "public"."Doc_Bowel_Movement_View" TO "authenticated";
GRANT ALL ON TABLE "public"."Doc_Bowel_Movement_View" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Doc_Bowel_Movement_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Doc_Bowel_Movement_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Doc_Bowel_Movement_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Duty_Transaction_Clock" TO "anon";
GRANT ALL ON TABLE "public"."Duty_Transaction_Clock" TO "authenticated";
GRANT ALL ON TABLE "public"."Duty_Transaction_Clock" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Duty_Transaction_Clock_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Duty_Transaction_Clock_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Duty_Transaction_Clock_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."F_timeBlock" TO "anon";
GRANT ALL ON TABLE "public"."F_timeBlock" TO "authenticated";
GRANT ALL ON TABLE "public"."F_timeBlock" TO "service_role";



GRANT ALL ON SEQUENCE "public"."F_timeBlock_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."F_timeBlock_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."F_timeBlock_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Inbox" TO "anon";
GRANT ALL ON TABLE "public"."Inbox" TO "authenticated";
GRANT ALL ON TABLE "public"."Inbox" TO "service_role";



GRANT ALL ON TABLE "public"."med_DB" TO "anon";
GRANT ALL ON TABLE "public"."med_DB" TO "authenticated";
GRANT ALL ON TABLE "public"."med_DB" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Med_DB_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Med_DB_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Med_DB_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Medication Error Rate" TO "anon";
GRANT ALL ON TABLE "public"."Medication Error Rate" TO "authenticated";
GRANT ALL ON TABLE "public"."Medication Error Rate" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Medication Error Rate_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Medication Error Rate_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Medication Error Rate_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."New_Manual" TO "anon";
GRANT ALL ON TABLE "public"."New_Manual" TO "authenticated";
GRANT ALL ON TABLE "public"."New_Manual" TO "service_role";



GRANT ALL ON SEQUENCE "public"."New_Manual_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."New_Manual_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."New_Manual_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Notification_Center_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Notification_Center_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Notification_Center_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Point_Transaction" TO "anon";
GRANT ALL ON TABLE "public"."Point_Transaction" TO "authenticated";
GRANT ALL ON TABLE "public"."Point_Transaction" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Point_Transaction_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Point_Transaction_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Point_Transaction_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Post" TO "anon";
GRANT ALL ON TABLE "public"."Post" TO "authenticated";
GRANT ALL ON TABLE "public"."Post" TO "service_role";



GRANT ALL ON TABLE "public"."Post_Quest_Accept" TO "anon";
GRANT ALL ON TABLE "public"."Post_Quest_Accept" TO "authenticated";
GRANT ALL ON TABLE "public"."Post_Quest_Accept" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_Quest_Accept_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_Quest_Accept_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_Quest_Accept_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Post_Resident_id" TO "anon";
GRANT ALL ON TABLE "public"."Post_Resident_id" TO "authenticated";
GRANT ALL ON TABLE "public"."Post_Resident_id" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_Resident_id_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_Resident_id_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_Resident_id_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Post_Tags" TO "anon";
GRANT ALL ON TABLE "public"."Post_Tags" TO "authenticated";
GRANT ALL ON TABLE "public"."Post_Tags" TO "service_role";



GRANT ALL ON TABLE "public"."TagsLabel" TO "anon";
GRANT ALL ON TABLE "public"."TagsLabel" TO "authenticated";
GRANT ALL ON TABLE "public"."TagsLabel" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq1" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq1" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_Tags_id_seq1" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Post_likes" TO "anon";
GRANT ALL ON TABLE "public"."Post_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."Post_likes" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Post_likes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Post_likes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Post_likes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."QATable" TO "anon";
GRANT ALL ON TABLE "public"."QATable" TO "authenticated";
GRANT ALL ON TABLE "public"."QATable" TO "service_role";



GRANT ALL ON SEQUENCE "public"."QATable_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."QATable_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."QATable_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Relation_TagTopic_UserGroup" TO "anon";
GRANT ALL ON TABLE "public"."Relation_TagTopic_UserGroup" TO "authenticated";
GRANT ALL ON TABLE "public"."Relation_TagTopic_UserGroup" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Relation_TagTopic_UserGroup_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Relation_TagTopic_UserGroup_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Relation_TagTopic_UserGroup_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."relatives" TO "anon";
GRANT ALL ON TABLE "public"."relatives" TO "authenticated";
GRANT ALL ON TABLE "public"."relatives" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Relatives_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Relatives_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Relatives_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Report_Choice" TO "anon";
GRANT ALL ON TABLE "public"."Report_Choice" TO "authenticated";
GRANT ALL ON TABLE "public"."Report_Choice" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Report_Choice_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Report_Choice_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Report_Choice_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Report_Subject" TO "anon";
GRANT ALL ON TABLE "public"."Report_Subject" TO "authenticated";
GRANT ALL ON TABLE "public"."Report_Subject" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Report_Subject_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Report_Subject_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Report_Subject_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."resident_caution_manual" TO "anon";
GRANT ALL ON TABLE "public"."resident_caution_manual" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_caution_manual" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Resident_Caution_Manual_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Resident_Caution_Manual_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Resident_Caution_Manual_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Resident_Report_Relation" TO "anon";
GRANT ALL ON TABLE "public"."Resident_Report_Relation" TO "authenticated";
GRANT ALL ON TABLE "public"."Resident_Report_Relation" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Resident_Report_Relation_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Resident_Report_Relation_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Resident_Report_Relation_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Resident_Template_Gen_Report" TO "anon";
GRANT ALL ON TABLE "public"."Resident_Template_Gen_Report" TO "authenticated";
GRANT ALL ON TABLE "public"."Resident_Template_Gen_Report" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Resident_Template_Gen_Report_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Resident_Template_Gen_Report_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Resident_Template_Gen_Report_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."SOAPNote" TO "anon";
GRANT ALL ON TABLE "public"."SOAPNote" TO "authenticated";
GRANT ALL ON TABLE "public"."SOAPNote" TO "service_role";



GRANT ALL ON SEQUENCE "public"."SOAPNote_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."SOAPNote_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."SOAPNote_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Scale_Report_Log" TO "anon";
GRANT ALL ON TABLE "public"."Scale_Report_Log" TO "authenticated";
GRANT ALL ON TABLE "public"."Scale_Report_Log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Scale_Report_Log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Scale_Report_Log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Scale_Report_Log_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."SubjectCalendarType_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."SubjectCalendarType_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."SubjectCalendarType_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Task_Type" TO "anon";
GRANT ALL ON TABLE "public"."Task_Type" TO "authenticated";
GRANT ALL ON TABLE "public"."Task_Type" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Task_Type_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Task_Type_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Task_Type_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Template_Tasks" TO "anon";
GRANT ALL ON TABLE "public"."Template_Tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."Template_Tasks" TO "service_role";



GRANT ALL ON TABLE "public"."Template_Ticket" TO "anon";
GRANT ALL ON TABLE "public"."Template_Ticket" TO "authenticated";
GRANT ALL ON TABLE "public"."Template_Ticket" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Template_Ticket_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Template_Ticket_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Template_Ticket_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Ticket_Template_Tasks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Ticket_Template_Tasks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Ticket_Template_Tasks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."Workday" TO "anon";
GRANT ALL ON TABLE "public"."Workday" TO "authenticated";
GRANT ALL ON TABLE "public"."Workday" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Workday_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Workday_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Workday_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."a_med_error_log_view" TO "anon";
GRANT ALL ON TABLE "public"."a_med_error_log_view" TO "authenticated";
GRANT ALL ON TABLE "public"."a_med_error_log_view" TO "service_role";



GRANT ALL ON TABLE "public"."abnormal_value_Dashboard" TO "anon";
GRANT ALL ON TABLE "public"."abnormal_value_Dashboard" TO "authenticated";
GRANT ALL ON TABLE "public"."abnormal_value_Dashboard" TO "service_role";



GRANT ALL ON SEQUENCE "public"."abnormal_value_Dashboard_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."abnormal_value_Dashboard_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."abnormal_value_Dashboard_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."abnormal_value_and_Ticket_Calendar" TO "anon";
GRANT ALL ON TABLE "public"."abnormal_value_and_Ticket_Calendar" TO "authenticated";
GRANT ALL ON TABLE "public"."abnormal_value_and_Ticket_Calendar" TO "service_role";



GRANT ALL ON SEQUENCE "public"."abnormal_value_and_Ticket_Calendar_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."abnormal_value_and_Ticket_Calendar_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."abnormal_value_and_Ticket_Calendar_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."nursinghomes" TO "anon";
GRANT ALL ON TABLE "public"."nursinghomes" TO "authenticated";
GRANT ALL ON TABLE "public"."nursinghomes" TO "service_role";



GRANT ALL ON TABLE "public"."abnormal_value_dashboard_view" TO "anon";
GRANT ALL ON TABLE "public"."abnormal_value_dashboard_view" TO "authenticated";
GRANT ALL ON TABLE "public"."abnormal_value_dashboard_view" TO "service_role";



GRANT ALL ON TABLE "public"."nursinghome_zone" TO "anon";
GRANT ALL ON TABLE "public"."nursinghome_zone" TO "authenticated";
GRANT ALL ON TABLE "public"."nursinghome_zone" TO "service_role";



GRANT ALL ON TABLE "public"."programs" TO "anon";
GRANT ALL ON TABLE "public"."programs" TO "authenticated";
GRANT ALL ON TABLE "public"."programs" TO "service_role";



GRANT ALL ON TABLE "public"."resident_programs" TO "anon";
GRANT ALL ON TABLE "public"."resident_programs" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_programs" TO "service_role";



GRANT ALL ON TABLE "public"."api_resident_details_view" TO "anon";
GRANT ALL ON TABLE "public"."api_resident_details_view" TO "authenticated";
GRANT ALL ON TABLE "public"."api_resident_details_view" TO "service_role";



GRANT ALL ON TABLE "public"."vitalSign" TO "anon";
GRANT ALL ON TABLE "public"."vitalSign" TO "authenticated";
GRANT ALL ON TABLE "public"."vitalSign" TO "service_role";



GRANT ALL ON TABLE "public"."api_vitalsign" TO "anon";
GRANT ALL ON TABLE "public"."api_vitalsign" TO "authenticated";
GRANT ALL ON TABLE "public"."api_vitalsign" TO "service_role";



GRANT ALL ON TABLE "public"."clock_break_time_nursinghome" TO "anon";
GRANT ALL ON TABLE "public"."clock_break_time_nursinghome" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_break_time_nursinghome" TO "service_role";



GRANT ALL ON SEQUENCE "public"."break_time_nursinghome_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."break_time_nursinghome_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."break_time_nursinghome_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."byDate_Doc_Bowel_Movement_Summary_View" TO "anon";
GRANT ALL ON TABLE "public"."byDate_Doc_Bowel_Movement_Summary_View" TO "authenticated";
GRANT ALL ON TABLE "public"."byDate_Doc_Bowel_Movement_Summary_View" TO "service_role";



GRANT ALL ON TABLE "public"."bydate_c_calendar_summary_view" TO "anon";
GRANT ALL ON TABLE "public"."bydate_c_calendar_summary_view" TO "authenticated";
GRANT ALL ON TABLE "public"."bydate_c_calendar_summary_view" TO "service_role";



GRANT ALL ON TABLE "public"."v_tasks_only_without_repeat" TO "anon";
GRANT ALL ON TABLE "public"."v_tasks_only_without_repeat" TO "authenticated";
GRANT ALL ON TABLE "public"."v_tasks_only_without_repeat" TO "service_role";



GRANT ALL ON TABLE "public"."cCalendarCounts" TO "anon";
GRANT ALL ON TABLE "public"."cCalendarCounts" TO "authenticated";
GRANT ALL ON TABLE "public"."cCalendarCounts" TO "service_role";



GRANT ALL ON TABLE "public"."cCalendarCounts2" TO "anon";
GRANT ALL ON TABLE "public"."cCalendarCounts2" TO "authenticated";
GRANT ALL ON TABLE "public"."cCalendarCounts2" TO "service_role";



GRANT ALL ON TABLE "public"."cCalendarWithDate" TO "anon";
GRANT ALL ON TABLE "public"."cCalendarWithDate" TO "authenticated";
GRANT ALL ON TABLE "public"."cCalendarWithDate" TO "service_role";



GRANT ALL ON TABLE "public"."cCalendarWithDateNew" TO "anon";
GRANT ALL ON TABLE "public"."cCalendarWithDateNew" TO "authenticated";
GRANT ALL ON TABLE "public"."cCalendarWithDateNew" TO "service_role";



GRANT ALL ON TABLE "public"."calendar_basic_view" TO "anon";
GRANT ALL ON TABLE "public"."calendar_basic_view" TO "authenticated";
GRANT ALL ON TABLE "public"."calendar_basic_view" TO "service_role";



GRANT ALL ON TABLE "public"."ccalendarcountsbyresident" TO "anon";
GRANT ALL ON TABLE "public"."ccalendarcountsbyresident" TO "authenticated";
GRANT ALL ON TABLE "public"."ccalendarcountsbyresident" TO "service_role";



GRANT ALL ON TABLE "public"."cleanup_snooze_log" TO "anon";
GRANT ALL ON TABLE "public"."cleanup_snooze_log" TO "authenticated";
GRANT ALL ON TABLE "public"."cleanup_snooze_log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."cleanup_snooze_log_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."cleanup_snooze_log_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."cleanup_snooze_log_log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."clock_in_out_summary" TO "anon";
GRANT ALL ON TABLE "public"."clock_in_out_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_in_out_summary" TO "service_role";



GRANT ALL ON TABLE "public"."clock_in_out_monthly_summary" TO "anon";
GRANT ALL ON TABLE "public"."clock_in_out_monthly_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_in_out_monthly_summary" TO "service_role";



GRANT ALL ON TABLE "public"."clock_shift_headcount_na_2m" TO "anon";
GRANT ALL ON TABLE "public"."clock_shift_headcount_na_2m" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_shift_headcount_na_2m" TO "service_role";



GRANT ALL ON TABLE "public"."clock_shift_roster_na_2m" TO "anon";
GRANT ALL ON TABLE "public"."clock_shift_roster_na_2m" TO "authenticated";
GRANT ALL ON TABLE "public"."clock_shift_roster_na_2m" TO "service_role";



GRANT ALL ON TABLE "public"."resident_underlying_disease" TO "anon";
GRANT ALL ON TABLE "public"."resident_underlying_disease" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_underlying_disease" TO "service_role";



GRANT ALL ON TABLE "public"."underlying_disease" TO "anon";
GRANT ALL ON TABLE "public"."underlying_disease" TO "authenticated";
GRANT ALL ON TABLE "public"."underlying_disease" TO "service_role";



GRANT ALL ON TABLE "public"."combined_vitalsign_details_view" TO "anon";
GRANT ALL ON TABLE "public"."combined_vitalsign_details_view" TO "authenticated";
GRANT ALL ON TABLE "public"."combined_vitalsign_details_view" TO "service_role";



GRANT ALL ON TABLE "public"."med_history" TO "anon";
GRANT ALL ON TABLE "public"."med_history" TO "authenticated";
GRANT ALL ON TABLE "public"."med_history" TO "service_role";



GRANT ALL ON TABLE "public"."med_logs_with_nickname" TO "anon";
GRANT ALL ON TABLE "public"."med_logs_with_nickname" TO "authenticated";
GRANT ALL ON TABLE "public"."med_logs_with_nickname" TO "service_role";



GRANT ALL ON TABLE "public"."medicine_List" TO "anon";
GRANT ALL ON TABLE "public"."medicine_List" TO "authenticated";
GRANT ALL ON TABLE "public"."medicine_List" TO "service_role";



GRANT ALL ON TABLE "public"."medicine_tag" TO "anon";
GRANT ALL ON TABLE "public"."medicine_tag" TO "authenticated";
GRANT ALL ON TABLE "public"."medicine_tag" TO "service_role";



GRANT ALL ON TABLE "public"."medicine_summary" TO "anon";
GRANT ALL ON TABLE "public"."medicine_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."medicine_summary" TO "service_role";



GRANT ALL ON TABLE "public"."resident_diseases_view" TO "anon";
GRANT ALL ON TABLE "public"."resident_diseases_view" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_diseases_view" TO "service_role";



GRANT ALL ON TABLE "public"."resident_line_group_id" TO "anon";
GRANT ALL ON TABLE "public"."resident_line_group_id" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_line_group_id" TO "service_role";



GRANT ALL ON TABLE "public"."resident_programs_view" TO "anon";
GRANT ALL ON TABLE "public"."resident_programs_view" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_programs_view" TO "service_role";



GRANT ALL ON TABLE "public"."resident_relatives" TO "anon";
GRANT ALL ON TABLE "public"."resident_relatives" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_relatives" TO "service_role";



GRANT ALL ON TABLE "public"."combined_resident_details_view" TO "anon";
GRANT ALL ON TABLE "public"."combined_resident_details_view" TO "authenticated";
GRANT ALL ON TABLE "public"."combined_resident_details_view" TO "service_role";



GRANT ALL ON TABLE "public"."ddRecordWithCalendar_Clock" TO "anon";
GRANT ALL ON TABLE "public"."ddRecordWithCalendar_Clock" TO "authenticated";
GRANT ALL ON TABLE "public"."ddRecordWithCalendar_Clock" TO "service_role";



GRANT ALL ON TABLE "public"."dummyFinishDutyTable" TO "anon";
GRANT ALL ON TABLE "public"."dummyFinishDutyTable" TO "authenticated";
GRANT ALL ON TABLE "public"."dummyFinishDutyTable" TO "service_role";



GRANT ALL ON TABLE "public"."invitations" TO "anon";
GRANT ALL ON TABLE "public"."invitations" TO "authenticated";
GRANT ALL ON TABLE "public"."invitations" TO "service_role";



GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."invitations_with_nursinghomes" TO "anon";
GRANT ALL ON TABLE "public"."invitations_with_nursinghomes" TO "authenticated";
GRANT ALL ON TABLE "public"."invitations_with_nursinghomes" TO "service_role";



GRANT ALL ON TABLE "public"."medMadeChange" TO "anon";
GRANT ALL ON TABLE "public"."medMadeChange" TO "authenticated";
GRANT ALL ON TABLE "public"."medMadeChange" TO "service_role";



GRANT ALL ON SEQUENCE "public"."medMadeChange_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."medMadeChange_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."medMadeChange_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."med_db_search_view" TO "anon";
GRANT ALL ON TABLE "public"."med_db_search_view" TO "authenticated";
GRANT ALL ON TABLE "public"."med_db_search_view" TO "service_role";



GRANT ALL ON TABLE "public"."med_db_with_placeholders" TO "anon";
GRANT ALL ON TABLE "public"."med_db_with_placeholders" TO "authenticated";
GRANT ALL ON TABLE "public"."med_db_with_placeholders" TO "service_role";



GRANT ALL ON TABLE "public"."med_db_with_residents" TO "anon";
GRANT ALL ON TABLE "public"."med_db_with_residents" TO "authenticated";
GRANT ALL ON TABLE "public"."med_db_with_residents" TO "service_role";



GRANT ALL ON TABLE "public"."med_example" TO "anon";
GRANT ALL ON TABLE "public"."med_example" TO "authenticated";
GRANT ALL ON TABLE "public"."med_example" TO "service_role";



GRANT ALL ON SEQUENCE "public"."med_example_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."med_example_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."med_example_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."med_history_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."med_history_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."med_history_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."med_history_summary" TO "anon";
GRANT ALL ON TABLE "public"."med_history_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."med_history_summary" TO "service_role";



GRANT ALL ON SEQUENCE "public"."medicine_List_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."medicine_List_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."medicine_List_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."medicine_tag_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."medicine_tag_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."medicine_tag_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."quickSnap_picture" TO "anon";
GRANT ALL ON TABLE "public"."quickSnap_picture" TO "authenticated";
GRANT ALL ON TABLE "public"."quickSnap_picture" TO "service_role";



GRANT ALL ON SEQUENCE "public"."my_Picture_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."my_Picture_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."my_Picture_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."n8n_agent_resident_profile" TO "anon";
GRANT ALL ON TABLE "public"."n8n_agent_resident_profile" TO "authenticated";
GRANT ALL ON TABLE "public"."n8n_agent_resident_profile" TO "service_role";



GRANT ALL ON TABLE "public"."n8n_medicine_summary" TO "anon";
GRANT ALL ON TABLE "public"."n8n_medicine_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."n8n_medicine_summary" TO "service_role";



GRANT ALL ON TABLE "public"."new_manual_with_nickname" TO "anon";
GRANT ALL ON TABLE "public"."new_manual_with_nickname" TO "authenticated";
GRANT ALL ON TABLE "public"."new_manual_with_nickname" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."nursinghome_zone_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."nursinghome_zone_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."nursinghome_zone_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."nursinghome_zone_not_done_task" TO "anon";
GRANT ALL ON TABLE "public"."nursinghome_zone_not_done_task" TO "authenticated";
GRANT ALL ON TABLE "public"."nursinghome_zone_not_done_task" TO "service_role";



GRANT ALL ON TABLE "public"."nursinghome_zone_resident_count" TO "anon";
GRANT ALL ON TABLE "public"."nursinghome_zone_resident_count" TO "authenticated";
GRANT ALL ON TABLE "public"."nursinghome_zone_resident_count" TO "service_role";



GRANT ALL ON SEQUENCE "public"."nursinghomes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."nursinghomes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."nursinghomes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."pastel_color" TO "anon";
GRANT ALL ON TABLE "public"."pastel_color" TO "authenticated";
GRANT ALL ON TABLE "public"."pastel_color" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pastel color_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pastel color_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pastel color_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."patient_status" TO "anon";
GRANT ALL ON TABLE "public"."patient_status" TO "authenticated";
GRANT ALL ON TABLE "public"."patient_status" TO "service_role";



GRANT ALL ON SEQUENCE "public"."patient_status_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."patient_status_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."patient_status_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."postDoneBy" TO "anon";
GRANT ALL ON TABLE "public"."postDoneBy" TO "authenticated";
GRANT ALL ON TABLE "public"."postDoneBy" TO "service_role";



GRANT ALL ON SEQUENCE "public"."postDoneBy_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."postDoneBy_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."postDoneBy_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."postReferenceId" TO "anon";
GRANT ALL ON TABLE "public"."postReferenceId" TO "authenticated";
GRANT ALL ON TABLE "public"."postReferenceId" TO "service_role";



GRANT ALL ON SEQUENCE "public"."postReferenceId_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."postReferenceId_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."postReferenceId_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."post_tab_likes_14d" TO "anon";
GRANT ALL ON TABLE "public"."post_tab_likes_14d" TO "authenticated";
GRANT ALL ON TABLE "public"."post_tab_likes_14d" TO "service_role";



GRANT ALL ON TABLE "public"."prn_post_queue" TO "anon";
GRANT ALL ON TABLE "public"."prn_post_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."prn_post_queue" TO "service_role";



GRANT ALL ON TABLE "public"."task_log_line_queue" TO "anon";
GRANT ALL ON TABLE "public"."task_log_line_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."task_log_line_queue" TO "service_role";



GRANT ALL ON TABLE "public"."user-QA" TO "anon";
GRANT ALL ON TABLE "public"."user-QA" TO "authenticated";
GRANT ALL ON TABLE "public"."user-QA" TO "service_role";



GRANT ALL ON TABLE "public"."user_group" TO "anon";
GRANT ALL ON TABLE "public"."user_group" TO "authenticated";
GRANT ALL ON TABLE "public"."user_group" TO "service_role";



GRANT ALL ON TABLE "public"."postwithuserinfo" TO "anon";
GRANT ALL ON TABLE "public"."postwithuserinfo" TO "authenticated";
GRANT ALL ON TABLE "public"."postwithuserinfo" TO "service_role";



GRANT ALL ON SEQUENCE "public"."prn_post_queue_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."prn_post_queue_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."prn_post_queue_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."program_summary_daily" TO "anon";
GRANT ALL ON TABLE "public"."program_summary_daily" TO "authenticated";
GRANT ALL ON TABLE "public"."program_summary_daily" TO "service_role";



GRANT ALL ON TABLE "public"."program_summary_view" TO "anon";
GRANT ALL ON TABLE "public"."program_summary_view" TO "authenticated";
GRANT ALL ON TABLE "public"."program_summary_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."programs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."programs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."programs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."quicksnap_picture_view" TO "anon";
GRANT ALL ON TABLE "public"."quicksnap_picture_view" TO "authenticated";
GRANT ALL ON TABLE "public"."quicksnap_picture_view" TO "service_role";



GRANT ALL ON TABLE "public"."relatives_with_resident_ids" TO "anon";
GRANT ALL ON TABLE "public"."relatives_with_resident_ids" TO "authenticated";
GRANT ALL ON TABLE "public"."relatives_with_resident_ids" TO "service_role";



GRANT ALL ON TABLE "public"."report_subject_summary_view" TO "anon";
GRANT ALL ON TABLE "public"."report_subject_summary_view" TO "authenticated";
GRANT ALL ON TABLE "public"."report_subject_summary_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."resident&relatives_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."resident&relatives_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."resident&relatives_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."resident_basic_info_view" TO "anon";
GRANT ALL ON TABLE "public"."resident_basic_info_view" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_basic_info_view" TO "service_role";



GRANT ALL ON TABLE "public"."resident_full_program_view" TO "anon";
GRANT ALL ON TABLE "public"."resident_full_program_view" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_full_program_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."resident_line_group_id_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."resident_line_group_id_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."resident_line_group_id_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."resident_programs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."resident_programs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."resident_programs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."resident_ticket_status_view" TO "anon";
GRANT ALL ON TABLE "public"."resident_ticket_status_view" TO "authenticated";
GRANT ALL ON TABLE "public"."resident_ticket_status_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."resident_underlying_disease_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."resident_underlying_disease_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."resident_underlying_disease_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."residents_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."residents_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."residents_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."scale_report_log_detailed_view" TO "anon";
GRANT ALL ON TABLE "public"."scale_report_log_detailed_view" TO "authenticated";
GRANT ALL ON TABLE "public"."scale_report_log_detailed_view" TO "service_role";



GRANT ALL ON TABLE "public"."send_out_user_resident" TO "anon";
GRANT ALL ON TABLE "public"."send_out_user_resident" TO "authenticated";
GRANT ALL ON TABLE "public"."send_out_user_resident" TO "service_role";



GRANT ALL ON SEQUENCE "public"."send_out_user_resident_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."send_out_user_resident_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."send_out_user_resident_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."soapnote_summary" TO "anon";
GRANT ALL ON TABLE "public"."soapnote_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."soapnote_summary" TO "service_role";



GRANT ALL ON TABLE "public"."tagslabel_with_usergroups" TO "anon";
GRANT ALL ON TABLE "public"."tagslabel_with_usergroups" TO "authenticated";
GRANT ALL ON TABLE "public"."tagslabel_with_usergroups" TO "service_role";



GRANT ALL ON SEQUENCE "public"."task_log_line_queue_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."task_log_line_queue_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."task_log_line_queue_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."task_summary" TO "anon";
GRANT ALL ON TABLE "public"."task_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."task_summary" TO "service_role";



GRANT ALL ON SEQUENCE "public"."task_summary_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."task_summary_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."task_summary_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."training_badges" TO "anon";
GRANT ALL ON TABLE "public"."training_badges" TO "authenticated";
GRANT ALL ON TABLE "public"."training_badges" TO "service_role";



GRANT ALL ON TABLE "public"."training_content" TO "anon";
GRANT ALL ON TABLE "public"."training_content" TO "authenticated";
GRANT ALL ON TABLE "public"."training_content" TO "service_role";



GRANT ALL ON TABLE "public"."training_questions" TO "anon";
GRANT ALL ON TABLE "public"."training_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."training_questions" TO "service_role";



GRANT ALL ON TABLE "public"."training_quiz_answers" TO "anon";
GRANT ALL ON TABLE "public"."training_quiz_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."training_quiz_answers" TO "service_role";



GRANT ALL ON TABLE "public"."training_quiz_sessions" TO "anon";
GRANT ALL ON TABLE "public"."training_quiz_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."training_quiz_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."training_seasons" TO "anon";
GRANT ALL ON TABLE "public"."training_seasons" TO "authenticated";
GRANT ALL ON TABLE "public"."training_seasons" TO "service_role";



GRANT ALL ON TABLE "public"."training_streaks" TO "anon";
GRANT ALL ON TABLE "public"."training_streaks" TO "authenticated";
GRANT ALL ON TABLE "public"."training_streaks" TO "service_role";



GRANT ALL ON TABLE "public"."training_topics" TO "anon";
GRANT ALL ON TABLE "public"."training_topics" TO "authenticated";
GRANT ALL ON TABLE "public"."training_topics" TO "service_role";



GRANT ALL ON TABLE "public"."training_user_badges" TO "anon";
GRANT ALL ON TABLE "public"."training_user_badges" TO "authenticated";
GRANT ALL ON TABLE "public"."training_user_badges" TO "service_role";



GRANT ALL ON TABLE "public"."training_user_progress" TO "anon";
GRANT ALL ON TABLE "public"."training_user_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."training_user_progress" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_badges" TO "anon";
GRANT ALL ON TABLE "public"."training_v_badges" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_badges" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_leaderboard" TO "anon";
GRANT ALL ON TABLE "public"."training_v_leaderboard" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_leaderboard" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_needs_review" TO "anon";
GRANT ALL ON TABLE "public"."training_v_needs_review" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_needs_review" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_quiz_history" TO "anon";
GRANT ALL ON TABLE "public"."training_v_quiz_history" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_quiz_history" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_thinking_analysis" TO "anon";
GRANT ALL ON TABLE "public"."training_v_thinking_analysis" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_thinking_analysis" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_topic_detail" TO "anon";
GRANT ALL ON TABLE "public"."training_v_topic_detail" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_topic_detail" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_topics_with_progress" TO "anon";
GRANT ALL ON TABLE "public"."training_v_topics_with_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_topics_with_progress" TO "service_role";



GRANT ALL ON TABLE "public"."training_v_user_stats" TO "anon";
GRANT ALL ON TABLE "public"."training_v_user_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."training_v_user_stats" TO "service_role";



GRANT ALL ON TABLE "public"."trigger_schedule_snooze_log" TO "anon";
GRANT ALL ON TABLE "public"."trigger_schedule_snooze_log" TO "authenticated";
GRANT ALL ON TABLE "public"."trigger_schedule_snooze_log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."trigger_schedule_snooze_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."trigger_schedule_snooze_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."trigger_schedule_snooze_log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."tt_template_tasks" TO "anon";
GRANT ALL ON TABLE "public"."tt_template_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tt_template_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."tt_template_ticket" TO "anon";
GRANT ALL ON TABLE "public"."tt_template_ticket" TO "authenticated";
GRANT ALL ON TABLE "public"."tt_template_ticket" TO "service_role";



GRANT ALL ON SEQUENCE "public"."underlying_disease_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."underlying_disease_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."underlying_disease_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."underlying_disease_summary_view" TO "anon";
GRANT ALL ON TABLE "public"."underlying_disease_summary_view" TO "authenticated";
GRANT ALL ON TABLE "public"."underlying_disease_summary_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user-QA_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user-QA_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user-QA_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_group_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_group_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_group_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_with_user_group" TO "anon";
GRANT ALL ON TABLE "public"."user_with_user_group" TO "authenticated";
GRANT ALL ON TABLE "public"."user_with_user_group" TO "service_role";



GRANT ALL ON TABLE "public"."user_info_with_nursinghomes" TO "anon";
GRANT ALL ON TABLE "public"."user_info_with_nursinghomes" TO "authenticated";
GRANT ALL ON TABLE "public"."user_info_with_nursinghomes" TO "service_role";



GRANT ALL ON TABLE "public"."user_points_with_info" TO "anon";
GRANT ALL ON TABLE "public"."user_points_with_info" TO "authenticated";
GRANT ALL ON TABLE "public"."user_points_with_info" TO "service_role";



GRANT ALL ON TABLE "public"."user_task_seen" TO "anon";
GRANT ALL ON TABLE "public"."user_task_seen" TO "authenticated";
GRANT ALL ON TABLE "public"."user_task_seen" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_task_seen_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_task_seen_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_task_seen_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_with_user_group_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_with_user_group_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_with_user_group_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."users_roles" TO "anon";
GRANT ALL ON TABLE "public"."users_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."users_roles" TO "service_role";



GRANT ALL ON TABLE "public"."v2_task_logs_with_daily_aggregation" TO "anon";
GRANT ALL ON TABLE "public"."v2_task_logs_with_daily_aggregation" TO "authenticated";
GRANT ALL ON TABLE "public"."v2_task_logs_with_daily_aggregation" TO "service_role";



GRANT ALL ON TABLE "public"."v2_task_logs_with_details" TO "anon";
GRANT ALL ON TABLE "public"."v2_task_logs_with_details" TO "authenticated";
GRANT ALL ON TABLE "public"."v2_task_logs_with_details" TO "service_role";



GRANT ALL ON TABLE "public"."v2_task_logs_with_details_n8n" TO "anon";
GRANT ALL ON TABLE "public"."v2_task_logs_with_details_n8n" TO "authenticated";
GRANT ALL ON TABLE "public"."v2_task_logs_with_details_n8n" TO "service_role";



GRANT ALL ON TABLE "public"."v2_task_summary" TO "anon";
GRANT ALL ON TABLE "public"."v2_task_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v2_task_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_duty_transaction_clock" TO "anon";
GRANT ALL ON TABLE "public"."v_duty_transaction_clock" TO "authenticated";
GRANT ALL ON TABLE "public"."v_duty_transaction_clock" TO "service_role";



GRANT ALL ON TABLE "public"."v_filtered_tasks_with_logs" TO "anon";
GRANT ALL ON TABLE "public"."v_filtered_tasks_with_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."v_filtered_tasks_with_logs" TO "service_role";



GRANT ALL ON TABLE "public"."v_prn_post_queue" TO "anon";
GRANT ALL ON TABLE "public"."v_prn_post_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."v_prn_post_queue" TO "service_role";



GRANT ALL ON TABLE "public"."v_program_membership" TO "anon";
GRANT ALL ON TABLE "public"."v_program_membership" TO "authenticated";
GRANT ALL ON TABLE "public"."v_program_membership" TO "service_role";



GRANT ALL ON TABLE "public"."v_repeated_task_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_repeated_task_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_repeated_task_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_task_log_queue_history" TO "anon";
GRANT ALL ON TABLE "public"."v_task_log_queue_history" TO "authenticated";
GRANT ALL ON TABLE "public"."v_task_log_queue_history" TO "service_role";



GRANT ALL ON TABLE "public"."v_task_logs_with_user_info" TO "anon";
GRANT ALL ON TABLE "public"."v_task_logs_with_user_info" TO "authenticated";
GRANT ALL ON TABLE "public"."v_task_logs_with_user_info" TO "service_role";



GRANT ALL ON TABLE "public"."v_tasks_with_logs" TO "anon";
GRANT ALL ON TABLE "public"."v_tasks_with_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."v_tasks_with_logs" TO "service_role";



GRANT ALL ON TABLE "public"."v_tasks_with_logs_by_task" TO "anon";
GRANT ALL ON TABLE "public"."v_tasks_with_logs_by_task" TO "authenticated";
GRANT ALL ON TABLE "public"."v_tasks_with_logs_by_task" TO "service_role";



GRANT ALL ON TABLE "public"."view_resident_caution_manual" TO "anon";
GRANT ALL ON TABLE "public"."view_resident_caution_manual" TO "authenticated";
GRANT ALL ON TABLE "public"."view_resident_caution_manual" TO "service_role";



GRANT ALL ON TABLE "public"."view_resident_template_reports" TO "anon";
GRANT ALL ON TABLE "public"."view_resident_template_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."view_resident_template_reports" TO "service_role";



GRANT ALL ON TABLE "public"."view_resident_underlying_disease" TO "anon";
GRANT ALL ON TABLE "public"."view_resident_underlying_disease" TO "authenticated";
GRANT ALL ON TABLE "public"."view_resident_underlying_disease" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vitalSign_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vitalSign_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vitalSign_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vitalsign_sent_queue" TO "anon";
GRANT ALL ON TABLE "public"."vitalsign_sent_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."vitalsign_sent_queue" TO "service_role";



GRANT ALL ON TABLE "public"."vitalsign_queue_view" TO "anon";
GRANT ALL ON TABLE "public"."vitalsign_queue_view" TO "authenticated";
GRANT ALL ON TABLE "public"."vitalsign_queue_view" TO "service_role";



GRANT ALL ON TABLE "public"."vitalsign_recent_basic_view" TO "anon";
GRANT ALL ON TABLE "public"."vitalsign_recent_basic_view" TO "authenticated";
GRANT ALL ON TABLE "public"."vitalsign_recent_basic_view" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vitalsign_sent_queue_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vitalsign_sent_queue_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vitalsign_sent_queue_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vw_comment_details" TO "anon";
GRANT ALL ON TABLE "public"."vw_comment_details" TO "authenticated";
GRANT ALL ON TABLE "public"."vw_comment_details" TO "service_role";



GRANT ALL ON TABLE "public"."vw_resident_report_relation" TO "anon";
GRANT ALL ON TABLE "public"."vw_resident_report_relation" TO "authenticated";
GRANT ALL ON TABLE "public"."vw_resident_report_relation" TO "service_role";



GRANT ALL ON TABLE "public"."vw_residents_with_relatives" TO "anon";
GRANT ALL ON TABLE "public"."vw_residents_with_relatives" TO "authenticated";
GRANT ALL ON TABLE "public"."vw_residents_with_relatives" TO "service_role";



GRANT ALL ON TABLE "public"."webhook_trigger_logs" TO "anon";
GRANT ALL ON TABLE "public"."webhook_trigger_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."webhook_trigger_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."webhook_trigger_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."webhook_trigger_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."webhook_trigger_logs_id_seq" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";



























RESET ALL;
