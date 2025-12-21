create or replace view "public"."combined_resident_details_view" as  WITH subject_sets AS (
         SELECT rrr.resident_id,
            array_agg(DISTINCT rrr.subject_id) FILTER (WHERE (rrr.shift = 'เวรเช้า'::text)) AS subject_ids_morning_shift,
            array_agg(DISTINCT rrr.subject_id) FILTER (WHERE (rrr.shift = 'เวรดึก'::text)) AS subject_ids_night_shift,
            array_agg(DISTINCT rrr.id) FILTER (WHERE (rrr.shift = 'เวรเช้า'::text)) AS morning_shift_relation_ids,
            array_agg(DISTINCT rrr.id) FILTER (WHERE (rrr.shift = 'เวรดึก'::text)) AS night_shift_relation_ids
           FROM public."Resident_Report_Relation" rrr
          GROUP BY rrr.resident_id
        )
 SELECT r.id AS resident_id,
    r.nursinghome_id,
    COALESCE(r."i_Name_Surname", '-'::text) AS "i_Name_Surname",
    COALESCE(r."i_National_ID_num", '-'::text) AS "i_National_ID_num",
    COALESCE(to_char((r."i_DOB")::timestamp with time zone, 'DD/MM/YYYY'::text), '-'::text) AS "i_DOB",
    r."i_DOB" AS i_dob_datetime,
    COALESCE((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (r."i_DOB")::timestamp with time zone)))::text, '-'::text) AS age,
    COALESCE(NULLIF(r.i_gender, ''::text), '-'::text) AS i_gender,
    COALESCE(NULLIF(r.i_picture_url, ''::text), 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/sign/user_Profile_Pic/profile%20blank.png'::text) AS i_picture_url,
    COALESCE(NULLIF(r.m_past_history, ''::text), '-'::text) AS m_past_history,
    COALESCE(NULLIF(r.m_dietary, ''::text), '-'::text) AS m_dietary,
    COALESCE(NULLIF(r.m_fooddrug_allergy, ''::text), '-'::text) AS m_fooddrug_allergy,
    COALESCE(r.s_status, '-'::text) AS s_status,
    COALESCE(NULLIF(r.s_bed, ''::text), '-'::text) AS s_bed,
    COALESCE(NULLIF(r.s_reason_being_here, ''::text), '-'::text) AS s_reason_being_here,
    COALESCE(to_char((r.s_contract_date)::timestamp with time zone, 'DD/MM/YYYY'::text), '-'::text) AS s_contract_date,
    r.s_contract_date AS s_contract_date_datetime,
    COALESCE(r.s_special_status, '-'::text) AS s_special_status,
    COALESCE(nh.name, '-'::text) AS nursinghome_name,
    COALESCE(rdv.diseases, '-'::text) AS diseases,
    COALESCE(rpv.programs, '-'::text) AS programs,
    COALESCE(max(first_rel.relative_id), ('-1'::integer)::bigint) AS relative_id,
    COALESCE(first_rel.r_name_surname, '-'::text) AS relative_name,
    COALESCE(first_rel.r_phone, '-'::text) AS relative_phone,
    COALESCE(first_rel.r_nickname, '-'::text) AS relative_nickname,
    COALESCE(( SELECT json_agg(json_build_object('id', rel_sub.id, 'name_surname', rel_sub.r_name_surname, 'nickname', rel_sub.r_nickname, 'phone', rel_sub.r_phone, 'detail', rel_sub.r_detail, 'key_person', rel_sub.key_person, 'line_user_id', rel_sub."lineUserId") ORDER BY rel_sub.key_person DESC NULLS LAST, rel_sub.r_name_surname) AS json_agg
           FROM (public.resident_relatives rr_sub
             JOIN public.relatives rel_sub ON ((rr_sub.relatives_id = rel_sub.id)))
          WHERE (rr_sub.resident_id = r.id)), '[]'::json) AS relatives_list,
    COALESCE(( SELECT count(*) AS count
           FROM public.resident_relatives rr_count
          WHERE (rr_count.resident_id = r.id)), (0)::bigint) AS relatives_count,
    COALESCE(ARRAY( SELECT sub_1.ud_name
           FROM ( SELECT rud_1.id AS occurrence_order,
                    ud_1.name AS ud_name
                   FROM (public.resident_underlying_disease rud_1
                     JOIN public.underlying_disease ud_1 ON ((rud_1.underlying_id = ud_1.id)))
                  WHERE (rud_1.resident_id = r.id)
                  ORDER BY rud_1.id) sub_1), '{}'::text[]) AS underlying_diseases_list,
    COALESCE(ARRAY( SELECT sub_2.ud_id
           FROM ( SELECT rud_2.id AS occurrence_order,
                    ud_2.id AS ud_id
                   FROM (public.resident_underlying_disease rud_2
                     JOIN public.underlying_disease ud_2 ON ((rud_2.underlying_id = ud_2.id)))
                  WHERE (rud_2.resident_id = r.id)
                  ORDER BY rud_2.id) sub_2), '{}'::bigint[]) AS underlying_disease_list_id,
    COALESCE(ARRAY( SELECT sub_1.pastel_color
           FROM ( SELECT rud_1.id AS occurrence_order,
                    ud_1.pastel_color
                   FROM (public.resident_underlying_disease rud_1
                     JOIN public.underlying_disease ud_1 ON ((rud_1.underlying_id = ud_1.id)))
                  WHERE (rud_1.resident_id = r.id)
                  ORDER BY rud_1.id) sub_1), '{}'::text[]) AS disease_pastel_color,
    COALESCE(latest_arrangemed.user_nickname_arrangemed, '-'::text) AS latest_user_nickname_arrangemed,
    COALESCE(med_error_summary.error_summary, '-'::text) AS current_day_med_error_summary,
    COALESCE(NULLIF(tag_summary.tag_summary, ''::text), '-'::text) AS current_day_med_tag_summary,
    COALESCE(arrange_med_today.arrangement_details, '-'::text) AS arrange_med_nickname_today,
    COALESCE(ARRAY( SELECT p.id
           FROM (public.resident_programs rp
             JOIN public.programs p ON ((rp.program_id = p.id)))
          WHERE (rp.resident_id = r.id)
          ORDER BY p.id), '{}'::bigint[]) AS program_ids_list,
    COALESCE(ARRAY( SELECT p.name
           FROM (public.resident_programs rp
             JOIN public.programs p ON ((rp.program_id = p.id)))
          WHERE (rp.resident_id = r.id)
          ORDER BY p.id), '{}'::text[]) AS programs_list,
    COALESCE(ARRAY( SELECT p.program_pastel_color
           FROM (public.resident_programs rp
             JOIN public.programs p ON ((rp.program_id = p.id)))
          WHERE (rp.resident_id = r.id)
          ORDER BY p.id), '{}'::text[]) AS program_pastel_color_list,
    COALESCE(nz.zone, '-'::text) AS s_zone,
    COALESCE(lmh.latest_med_history_created_at, ('1970-01-01 00:00:00'::timestamp without time zone)::timestamp with time zone) AS latest_med_history_created_at,
    nz.id AS zone_id,
        CASE
            WHEN (r.i_gender = 'ชาย'::text) THEN '#2F73FD'::text
            WHEN (r.i_gender = 'หญิง'::text) THEN '#CC5FB9'::text
            ELSE '#e0e3e7'::text
        END AS gender_color,
        CASE
            WHEN (age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone) < '1 mon'::interval) THEN (EXTRACT(day FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone)) || 'ว'::text)
            WHEN (age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone) < '1 year'::interval) THEN (((EXTRACT(month FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone)) || 'ด '::text) || EXTRACT(day FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone))) || 'ว'::text)
            ELSE (((((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone)) || 'ป '::text) || EXTRACT(month FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone))) || 'ด '::text) || EXTRACT(day FROM age((CURRENT_DATE)::timestamp with time zone, (r.s_contract_date)::timestamp with time zone))) || ' ว'::text)
        END AS s_stay_period,
    r."DTX/insulin",
    cvs.vital_signs_status,
        CASE
            WHEN (cvs.vital_signs_status <> 'สัญญาณชีพล่าสุดปกติ'::text) THEN '#A90000'::text
            ELSE '#5A5C60'::text
        END AS vital_signs_color,
    r."Report_Amount",
    cvs.latest_vital_sign_id,
    cvs.latest_vital_sign_date,
    last_vs."Sent" AS latest_sent_status,
    cvs.user_nickname AS latest_vital_sign_creator_nickname,
    max(COALESCE(med_summary.on_count, (0)::bigint)) AS current_medication_count,
    max(COALESCE(med_summary.total_count, (0)::bigint)) AS total_medication_count,
    ((max(COALESCE(med_summary.on_count, (0)::bigint)) || '/'::text) || max(COALESCE(med_summary.total_count, (0)::bigint))) AS medication_summary,
    COALESCE(max(last_vs.shift), '-'::text) AS latest_shift,
    COALESCE(current_day_med_correct_summary.correct_summary, '-'::text) AS current_day_med_correct_summary,
    COALESCE(med_summary.run_out_within_15_days, false) AS run_out_within_15_days,
    COALESCE(med_summary.run_out_within_7_days, false) AS run_out_within_7_days,
    COALESCE(ss.subject_ids_morning_shift, '{}'::bigint[]) AS subject_ids_morning_shift,
    COALESCE(ss.subject_ids_night_shift, '{}'::bigint[]) AS subject_ids_night_shift,
    COALESCE(ss.morning_shift_relation_ids, '{}'::bigint[]) AS morning_shift_relation_ids,
    COALESCE(ss.night_shift_relation_ids, '{}'::bigint[]) AS night_shift_relation_ids,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM public."A_Med_Error_Log"
              WHERE (("A_Med_Error_Log".resident_id = r.id) AND ("A_Med_Error_Log"."CalendarDate" = CURRENT_DATE) AND ("A_Med_Error_Log"."reply_nurseMark" = 'ไม่ถูกต้อง'::text)))) THEN true
            ELSE false
        END AS incorrect_nurse_mark,
    COALESCE(rlgi.line_group_id, '-'::text) AS line_group_id
   FROM ((((((((((((((((public.residents r
     LEFT JOIN ( SELECT "A_Med_Error_Log".resident_id,
            string_agg(concat(to_char(("A_Med_Error_Log"."CalendarDate")::timestamp with time zone, 'DD/MM/YYYY'::text), ' ', "A_Med_Error_Log".meal, ': ', "A_Med_Error_Log"."reply_nurseMark"), chr(10)) FILTER (WHERE ("A_Med_Error_Log"."reply_nurseMark" <> 'ถูกต้อง'::text)) AS error_summary
           FROM public."A_Med_Error_Log"
          WHERE ("A_Med_Error_Log"."CalendarDate" = CURRENT_DATE)
          GROUP BY "A_Med_Error_Log".resident_id) med_error_summary ON ((r.id = med_error_summary.resident_id)))
     LEFT JOIN ( SELECT ml.resident_id,
            string_agg(concat(COALESCE(med_db.generic_name, ''::text), ' (', COALESCE(med_db.brand_name, ''::text), ') : ', COALESCE(tag_summary_1.tags, ''::text)), chr(10)) AS tag_summary
           FROM ((public."medicine_List" ml
             LEFT JOIN public."med_DB" med_db ON ((ml."med_DB_id" = med_db.id)))
             LEFT JOIN ( SELECT mt.med_list_id,
                    string_agg(mt.tag, ', '::text) AS tags
                   FROM public.medicine_tag mt
                  GROUP BY mt.med_list_id) tag_summary_1 ON ((tag_summary_1.med_list_id = ml.id)))
          WHERE (tag_summary_1.tags IS NOT NULL)
          GROUP BY ml.resident_id) tag_summary ON ((r.id = tag_summary.resident_id)))
     LEFT JOIN ( SELECT "A_Med_logs".resident_id,
            string_agg(((to_char("A_Med_logs".created_at, 'DD/MM HH24:MI'::text) || ' - '::text) || user_info.nickname), '; '::text) AS arrangement_details
           FROM (public."A_Med_logs"
             LEFT JOIN public.user_info ON (("A_Med_logs"."ArrangeMed_by" = user_info.id)))
          WHERE ("A_Med_logs"."Created_Date" = CURRENT_DATE)
          GROUP BY "A_Med_logs".resident_id) arrange_med_today ON ((r.id = arrange_med_today.resident_id)))
     LEFT JOIN LATERAL ( SELECT rel.id AS relative_id,
            rel.r_name_surname,
            rel.r_phone,
            rel.key_person,
            rel.r_nickname
           FROM (public.resident_relatives rr
             JOIN public.relatives rel ON ((rr.relatives_id = rel.id)))
          WHERE (rr.resident_id = r.id)
          ORDER BY rel.id
         LIMIT 1) first_rel ON (true))
     LEFT JOIN public.nursinghomes nh ON ((r.nursinghome_id = nh.id)))
     LEFT JOIN public.resident_diseases_view rdv ON ((r.id = rdv.resident_id)))
     LEFT JOIN public.resident_programs_view rpv ON ((r.id = rpv.resident_id)))
     LEFT JOIN public.nursinghome_zone nz ON ((r.s_zone = nz.id)))
     LEFT JOIN subject_sets ss ON ((ss.resident_id = r.id)))
     LEFT JOIN LATERAL ( SELECT vs.shift,
            vs.created_at,
            vs."Sent"
           FROM public."vitalSign" vs
          WHERE (vs.resident_id = r.id)
          ORDER BY vs.created_at DESC
         LIMIT 1) last_vs ON (true))
     LEFT JOIN LATERAL ( SELECT vs.vital_signs_status,
            vs.id AS latest_vital_sign_id,
            vs.created_at AS latest_vital_sign_date,
            vs.user_nickname
           FROM public.combined_vitalsign_details_view vs
          WHERE (vs.resident_id = r.id)
          ORDER BY vs.created_at DESC
         LIMIT 1) cvs ON (true))
     LEFT JOIN LATERAL ( SELECT mh.created_at AS latest_med_history_created_at
           FROM (public.med_history mh
             JOIN public."medicine_List" ml ON ((mh.med_list_id = ml.id)))
          WHERE (ml.resident_id = r.id)
          ORDER BY mh.created_at DESC
         LIMIT 1) lmh ON (true))
     LEFT JOIN LATERAL ( SELECT mlwn.user_nickname_arrangemed
           FROM public.med_logs_with_nickname mlwn
          WHERE ((mlwn.resident_id = r.id) AND (NULLIF(mlwn.user_nickname_arrangemed, ''::text) IS NOT NULL))
          ORDER BY mlwn.created_at DESC
         LIMIT 1) latest_arrangemed ON (true))
     LEFT JOIN LATERAL ( SELECT string_agg(concat(to_char(("A_Med_Error_Log"."CalendarDate")::timestamp with time zone, 'DD/MM/YYYY'::text), ' ', "A_Med_Error_Log".meal, ': ', "A_Med_Error_Log"."reply_nurseMark"), chr(10)) AS correct_summary
           FROM public."A_Med_Error_Log"
          WHERE ((("A_Med_Error_Log"."CalendarDate" >= (CURRENT_DATE - '1 day'::interval)) AND ("A_Med_Error_Log"."CalendarDate" <= (CURRENT_DATE + '1 day'::interval))) AND ("A_Med_Error_Log"."reply_nurseMark" = ANY (ARRAY['รูปไม่ตรง'::text, 'ไม่มีรูป'::text, 'ตำแหน่งสลับ'::text])) AND ("A_Med_Error_Log".resident_id = r.id))) current_day_med_correct_summary ON (true))
     LEFT JOIN ( SELECT ms.resident_id,
            count(*) FILTER (WHERE (ms.status = 'on'::text)) AS on_count,
            count(*) AS total_count,
            bool_or(ms.run_out_within_15_days) AS run_out_within_15_days,
            bool_or(ms.run_out_within_7_days) AS run_out_within_7_days
           FROM public.medicine_summary ms
          GROUP BY ms.resident_id) med_summary ON ((r.id = med_summary.resident_id)))
     LEFT JOIN LATERAL ( SELECT rlg.line_group_id
           FROM public.resident_line_group_id rlg
          WHERE ((rlg.resident_id = r.id) AND (rlg.line_group_id IS NOT NULL) AND (btrim(rlg.line_group_id) <> ''::text))
          ORDER BY rlg.created_at DESC, rlg.id DESC
         LIMIT 1) rlgi ON (true))
  GROUP BY r.id, r.nursinghome_id, r."i_Name_Surname", r."i_National_ID_num", r."i_DOB", r.i_gender, r.i_picture_url, r.m_past_history, r.m_dietary, r.m_fooddrug_allergy, r.s_status, r.s_bed, r.s_reason_being_here, r.s_contract_date, r.s_special_status, nh.name, rdv.diseases, rpv.programs, nz.zone, nz.id, cvs.vital_signs_status, r."DTX/insulin", r."Report_Amount", cvs.latest_vital_sign_date, cvs.latest_vital_sign_id, last_vs."Sent", cvs.user_nickname, lmh.latest_med_history_created_at, first_rel.r_name_surname, first_rel.r_phone, first_rel.r_nickname, latest_arrangemed.user_nickname_arrangemed, med_error_summary.error_summary, tag_summary.tag_summary, arrange_med_today.arrangement_details, current_day_med_correct_summary.correct_summary, med_summary.run_out_within_15_days, med_summary.run_out_within_7_days, ss.subject_ids_morning_shift, ss.subject_ids_night_shift, ss.morning_shift_relation_ids, ss.night_shift_relation_ids, rlgi.line_group_id;


create or replace view "public"."postwithuserinfo" as  WITH likes_dedup AS (
         SELECT DISTINCT ON (pl."Post_id", pl.user_id) pl."Post_id",
            pl.user_id,
            uinfo.nickname,
            uinfo.photo_url,
            pl.created_at,
            pl.id AS like_row_id
           FROM (public."Post_likes" pl
             LEFT JOIN public.user_info uinfo ON ((uinfo.id = pl.user_id)))
          ORDER BY pl."Post_id", pl.user_id, pl.created_at DESC, pl.id DESC
        ), likes_agg AS (
         SELECT d."Post_id",
            array_agg(d.user_id ORDER BY d.created_at DESC, d.like_row_id DESC) AS like_user_ids,
            array_agg(d.nickname ORDER BY d.created_at DESC, d.like_row_id DESC) AS like_user_nicknames,
            array_agg(d.photo_url ORDER BY d.created_at DESC, d.like_row_id DESC) AS like_user_photo_urls,
            count(*) AS like_count,
            (array_agg(d.nickname ORDER BY d.created_at DESC, d.like_row_id DESC))[1] AS last_like_nickname,
            (array_agg(d.photo_url ORDER BY d.created_at DESC, d.like_row_id DESC))[1] AS last_like_photo_url
           FROM likes_dedup d
          GROUP BY d."Post_id"
        ), tags_agg AS (
         SELECT pt."Post_id" AS post_id,
            array_agg(DISTINCT tl."tagName") AS post_tags,
            array_to_string(array_agg(DISTINCT tl."tagName"), ','::text) AS post_tags_string,
            COALESCE(bool_or(tl."Importent"), false) AS "Importent",
            array_agg(DISTINCT tl.tab) FILTER (WHERE ((tl.tab IS NOT NULL) AND (lower(tl.tab) <> 'request'::text))) AS post_tabs_raw,
            (array_agg(tl.tab ORDER BY
                CASE
                    WHEN (lower(tl.tab) = 'announcements-critical'::text) THEN 1
                    WHEN (lower(tl.tab) = 'announcements-policy'::text) THEN 2
                    WHEN (lower(tl.tab) = 'announcements-info'::text) THEN 3
                    WHEN (lower(tl.tab) = 'calendar'::text) THEN 4
                    WHEN (lower(tl.tab) = 'fyi'::text) THEN 5
                    ELSE 999
                END, tl.tab) FILTER (WHERE ((tl.tab IS NOT NULL) AND (lower(tl.tab) <> 'request'::text))))[1] AS prioritized_tab
           FROM (public."Post_Tags" pt
             JOIN public."TagsLabel" tl ON ((tl.id = pt."Tag_id")))
          GROUP BY pt."Post_id"
        ), calendar_agg AS (
         SELECT "C_Calendar_with_Post"."PostId" AS post_id,
            array_agg(DISTINCT "C_Calendar_with_Post"."CalendarId") AS calendar_ids
           FROM public."C_Calendar_with_Post"
          GROUP BY "C_Calendar_with_Post"."PostId"
        ), tagged_agg AS (
         SELECT p_1.id AS post_id,
            COALESCE(array_length(p_1.tagged_user, 1), 0) AS number_of_tagged_users,
            array_agg(DISTINCT ui_tagged.nickname) FILTER (WHERE (ui_tagged.nickname IS NOT NULL)) AS tagged_user_nicknames
           FROM ((public."Post" p_1
             LEFT JOIN LATERAL unnest(p_1.tagged_user) tu(tagged_user_id) ON (true))
             LEFT JOIN public.user_info ui_tagged ON ((ui_tagged.id = tu.tagged_user_id)))
          GROUP BY p_1.id, p_1.tagged_user
        ), last_log AS (
         SELECT DISTINCT ON ("A_Task_logs_ver2".post_id) "A_Task_logs_ver2".post_id,
            "A_Task_logs_ver2".id,
            "A_Task_logs_ver2".created_at
           FROM public."A_Task_logs_ver2"
          WHERE ("A_Task_logs_ver2".post_id IS NOT NULL)
          ORDER BY "A_Task_logs_ver2".post_id, "A_Task_logs_ver2".created_at DESC, "A_Task_logs_ver2".id DESC
        ), task_done_by_one AS (
         SELECT DISTINCT ON (pdb.post_id) pdb.post_id,
            ui_1.nickname AS task_done_by_nickname,
            ui_1.id AS task_done_by_id
           FROM (public."postDoneBy" pdb
             JOIN public.user_info ui_1 ON ((ui_1.id = pdb.user_id)))
          ORDER BY pdb.post_id, pdb.id DESC
        ), quest_accept_one AS (
         SELECT DISTINCT ON (pqa.post_id) pqa.post_id,
            ui_1.nickname AS quest_accept_user_nickname,
            ui_1.id AS quest_accept_user_id
           FROM (public."Post_Quest_Accept" pqa
             JOIN public.user_info ui_1 ON ((ui_1.id = pqa.user_id)))
          ORDER BY pqa.post_id, pqa.id DESC
        ), prn_queue_one AS (
         SELECT DISTINCT ON (pq_1.post_id) pq_1.post_id,
            pq_1.status AS prn_status,
            pq_1.created_at AS prn_status_created_at,
            pq_1.id AS prn_queue_id
           FROM public.prn_post_queue pq_1
          ORDER BY pq_1.post_id, pq_1.created_at DESC, pq_1.id DESC
        ), log_line_queue_one AS (
         SELECT DISTINCT ON (tq.log_id) tq.log_id,
            tq.status AS log_line_status,
            tq.created_at AS log_line_status_created_at,
            tq.id AS log_line_queue_id
           FROM public.task_log_line_queue tq
          ORDER BY tq.log_id, tq.created_at DESC, tq.id DESC
        ), qa_users_agg AS (
         SELECT uq."QA_id" AS qa_id,
            array_agg(DISTINCT ui_1.id) AS qa_user_ids,
            array_agg(DISTINCT ui_1.full_name) FILTER (WHERE (ui_1.full_name IS NOT NULL)) AS qa_user_full_names,
            array_agg(DISTINCT ui_1.nickname) FILTER (WHERE (ui_1.nickname IS NOT NULL)) AS qa_user_nicknames,
            array_agg(DISTINCT ui_1.photo_url) FILTER (WHERE (ui_1.photo_url IS NOT NULL)) AS qa_user_photo_urls,
            array_agg(DISTINCT ui_1."group") AS qa_user_group_ids,
            array_agg(DISTINCT ug2."group") FILTER (WHERE (ug2."group" IS NOT NULL)) AS qa_user_group_names
           FROM ((public."user-QA" uq
             LEFT JOIN public.user_info ui_1 ON ((ui_1.id = uq.user_id)))
             LEFT JOIN public.user_group ug2 ON ((ug2.id = ui_1."group")))
          GROUP BY uq."QA_id"
        )
 SELECT p.id,
    p.created_at AS post_created_at,
    date(p.created_at) AS post_created_at_date,
    p.user_id,
    p."vitalSign_id",
    p."Text",
        CASE
            WHEN (NULLIF(btrim(p.title), ''::text) IS NOT NULL) THEN p.title
            ELSE (SUBSTRING(btrim(regexp_replace(regexp_replace(COALESCE(p."Text", ''::text), '[\n\r\t]+'::text, ' '::text, 'g'::text), '\\s+'::text, ' '::text, 'g'::text)) FROM 1 FOR 30) || '..'::text)
        END AS title,
    p."youtubeUrl",
    p."imgUrl",
    p.nursinghome_id,
    p.tagged_user,
    p.user_group_edit,
    p.user_group_id_edit,
    p.visible_to_relative,
    p.reply_to,
    ui_reply.photo_url AS reply_to_user_photo_url,
    ui_reply.nickname AS reply_to_user_nickname,
    p_reply."Text" AS reply_to_post_text,
    pr.id AS post_resident_id,
    res.id AS resident_id,
    nz.id AS zone_id,
    nz.zone AS resident_zone,
    res."i_Name_Surname" AS resident_name,
    res.i_picture_url AS resident_i_picture_url,
    res.s_special_status AS resident_s_special_status,
    res.underlying_disease_list AS resident_underlying_disease_list,
    COALESCE(tg.post_tags_string, ''::text) AS post_tags_string,
    tg.post_tags,
    COALESCE(tg.post_tabs_raw, ARRAY['FYI'::text]) AS post_tabs,
    array_to_string(COALESCE(tg.post_tabs_raw, ARRAY['FYI'::text]), ','::text) AS post_tabs_string,
    COALESCE(tg.prioritized_tab, 'FYI'::text) AS tab,
    p.multi_img_url,
        CASE
            WHEN (p.multi_img_url IS NULL) THEN NULL::text[]
            ELSE ( SELECT array_agg(
                    CASE
                        WHEN (strpos(t.u, '?'::text) > 0) THEN (t.u || '&width=52&height=60&quality=65&resize=cover&format=webp'::text)
                        ELSE (t.u || '?width=52&height=60&quality=65&resize=cover&format=webp'::text)
                    END ORDER BY t.ord) AS array_agg
               FROM unnest(p.multi_img_url) WITH ORDINALITY t(u, ord))
        END AS multi_img_url_thumb,
    COALESCE(ta.number_of_tagged_users, 0) AS number_of_tagged_users,
    ta.tagged_user_nicknames,
    ui.nickname AS post_user_nickname,
    ui.photo_url,
    ug."group" AS user_group,
    la.like_user_ids,
    la.like_user_nicknames,
    la.like_user_photo_urls,
    GREATEST((COALESCE(la.like_count, (0)::bigint) - 1), (0)::bigint) AS like_count_minus_one,
    la.last_like_nickname,
    la.last_like_photo_url,
    res."i_Name_Surname" AS resident_name_dup_for_compat,
    ca.calendar_ids,
    tdb.task_done_by_nickname,
    tdb.task_done_by_id,
    qa.quest_accept_user_id,
    qa.quest_accept_user_nickname,
    ( SELECT array_to_string(ARRAY( SELECT unnest(COALESCE(ta.tagged_user_nicknames, ARRAY[]::text[])) AS unnest
                EXCEPT
                 SELECT unnest(COALESCE(la.like_user_nicknames, ARRAY[]::text[])) AS unnest), ','::text) AS array_to_string) AS non_liked_tagged_nicknames,
    GREATEST(p.created_at, COALESCE(p.last_modified_at, '1970-01-01 00:00:00+07'::timestamp with time zone)) AS latest_update_time,
    COALESCE(tg."Importent", false) AS "Importent",
    res.s_status,
    res.s_special_status,
    ll.id AS log_id,
    pq.prn_status,
    pq.prn_status_created_at,
    pq.prn_queue_id,
    lq.log_line_status,
    lq.log_line_status_created_at,
    lq.log_line_queue_id,
    p.qa_id,
    qt.question AS qa_question,
    qt."choiceA" AS qa_choice_a,
    qt."choiceB" AS qa_choice_b,
    qt."choiceC" AS qa_choice_c,
    qt.answer AS qa_answer,
    qa_u.qa_user_ids,
    qa_u.qa_user_full_names,
    qa_u.qa_user_nicknames,
    qa_u.qa_user_photo_urls,
    qa_u.qa_user_group_ids,
    qa_u.qa_user_group_names
   FROM ((((((((((((((((((public."Post" p
     LEFT JOIN public.user_info ui ON ((ui.id = p.user_id)))
     LEFT JOIN public.user_group ug ON ((ug.id = ui."group")))
     LEFT JOIN public."Post_Resident_id" pr ON ((pr."Post_id" = p.id)))
     LEFT JOIN public.residents res ON ((res.id = pr.resident_id)))
     LEFT JOIN public.nursinghome_zone nz ON ((nz.id = res.s_zone)))
     LEFT JOIN likes_agg la ON ((la."Post_id" = p.id)))
     LEFT JOIN tags_agg tg ON ((tg.post_id = p.id)))
     LEFT JOIN calendar_agg ca ON ((ca.post_id = p.id)))
     LEFT JOIN tagged_agg ta ON ((ta.post_id = p.id)))
     LEFT JOIN task_done_by_one tdb ON ((tdb.post_id = p.id)))
     LEFT JOIN quest_accept_one qa ON ((qa.post_id = p.id)))
     LEFT JOIN public."Post" p_reply ON ((p_reply.id = p.reply_to)))
     LEFT JOIN public.user_info ui_reply ON ((ui_reply.id = p_reply.user_id)))
     LEFT JOIN last_log ll ON ((ll.post_id = p.id)))
     LEFT JOIN prn_queue_one pq ON ((pq.post_id = p.id)))
     LEFT JOIN log_line_queue_one lq ON ((lq.log_id = ll.id)))
     LEFT JOIN public."QATable" qt ON ((qt.id = p.qa_id)))
     LEFT JOIN qa_users_agg qa_u ON ((qa_u.qa_id = p.qa_id)));



