create table public.training_badges (
  id uuid not null default gen_random_uuid (),
  name text not null,
  description text null,
  icon text null,
  image_url text null,
  requirement_type text not null,
  requirement_value jsonb null default '{}'::jsonb,
  category text null default 'general'::text,
  points integer null default 10,
  rarity text null default 'common'::text,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint training_badges_pkey primary key (id),
  constraint training_badges_rarity_check check (
    (
      rarity = any (
        array[
          'common'::text,
          'rare'::text,
          'epic'::text,
          'legendary'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_badges_type on public.training_badges using btree (requirement_type) TABLESPACE pg_default;

create table public.training_content (
  id uuid not null default gen_random_uuid (),
  topic_id text not null,
  season_id uuid null,
  title text not null,
  content_markdown text not null,
  content_summary text null,
  reading_time_minutes integer null,
  notion_page_id text null,
  notion_last_edited timestamp with time zone null,
  version integer null default 1,
  is_active boolean null default true,
  synced_at timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  constraint training_content_pkey primary key (id),
  constraint training_content_topic_id_season_id_key unique (topic_id, season_id),
  constraint training_content_season_id_fkey foreign KEY (season_id) references training_seasons (id),
  constraint training_content_topic_id_fkey foreign KEY (topic_id) references training_topics (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_content_topic on public.training_content using btree (topic_id) TABLESPACE pg_default;

create index IF not exists idx_content_season on public.training_content using btree (season_id) TABLESPACE pg_default;

create table public.training_questions (
  id uuid not null default gen_random_uuid (),
  topic_id text not null,
  season_id uuid null,
  question_text text not null,
  question_image_url text null,
  choices jsonb not null,
  explanation text null,
  explanation_image_url text null,
  difficulty integer null default 2,
  thinking_type text null,
  tags text[] null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint training_questions_pkey primary key (id),
  constraint training_questions_season_id_fkey foreign KEY (season_id) references training_seasons (id),
  constraint training_questions_topic_id_fkey foreign KEY (topic_id) references training_topics (id) on delete CASCADE,
  constraint training_questions_difficulty_check check (
    (
      (difficulty >= 1)
      and (difficulty <= 3)
    )
  ),
  constraint training_questions_thinking_type_check check (
    (
      thinking_type = any (
        array[
          'analysis'::text,
          'prioritization'::text,
          'risk_assessment'::text,
          'reasoning'::text,
          'uncertainty'::text
        ]
      )
    )
  ),
  constraint valid_choices check (
    (
      (jsonb_typeof(choices) = 'array'::text)
      and (jsonb_array_length(choices) >= 2)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_questions_topic on public.training_questions using btree (topic_id) TABLESPACE pg_default
where
  (is_active = true);

create index IF not exists idx_questions_season on public.training_questions using btree (season_id) TABLESPACE pg_default;

create index IF not exists idx_questions_thinking on public.training_questions using btree (thinking_type) TABLESPACE pg_default;

create index IF not exists idx_questions_difficulty on public.training_questions using btree (difficulty) TABLESPACE pg_default;

create trigger trg_question_set_season BEFORE INSERT on training_questions for EACH row
execute FUNCTION set_active_season_for_question ();

create table public.training_quiz_answers (
  id uuid not null default gen_random_uuid (),
  session_id uuid not null,
  question_id uuid not null,
  selected_choice text null,
  is_correct boolean null,
  answer_time_seconds integer null,
  answered_at timestamp with time zone null default now(),
  constraint training_quiz_answers_pkey primary key (id),
  constraint training_quiz_answers_session_id_question_id_key unique (session_id, question_id),
  constraint training_quiz_answers_question_id_fkey foreign KEY (question_id) references training_questions (id) on delete CASCADE,
  constraint training_quiz_answers_session_id_fkey foreign KEY (session_id) references training_quiz_sessions (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_answers_session on public.training_quiz_answers using btree (session_id) TABLESPACE pg_default;

create index IF not exists idx_answers_question on public.training_quiz_answers using btree (question_id) TABLESPACE pg_default;

create table public.training_quiz_sessions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  topic_id text not null,
  season_id uuid not null,
  progress_id uuid not null,
  quiz_type text not null,
  attempt_number integer null default 1,
  score integer null default 0,
  total_questions integer null default 20,
  passing_score integer null default 16,
  time_limit_seconds integer null default 600,
  started_at timestamp with time zone null default now(),
  completed_at timestamp with time zone null,
  is_passed boolean GENERATED ALWAYS as (
    case
      when (completed_at is not null) then (score >= passing_score)
      else null::boolean
    end
  ) STORED null,
  duration_seconds integer GENERATED ALWAYS as (
    case
      when (completed_at is not null) then (
        EXTRACT(
          epoch
          from
            (completed_at - started_at)
        )
      )::integer
      else null::integer
    end
  ) STORED null,
  question_ids uuid[] null default '{}'::uuid[],
  constraint training_quiz_sessions_pkey primary key (id),
  constraint training_quiz_sessions_progress_id_fkey foreign KEY (progress_id) references training_user_progress (id) on delete CASCADE,
  constraint training_quiz_sessions_season_id_fkey foreign KEY (season_id) references training_seasons (id) on delete CASCADE,
  constraint training_quiz_sessions_topic_id_fkey foreign KEY (topic_id) references training_topics (id) on delete CASCADE,
  constraint training_quiz_sessions_user_id_fkey foreign KEY (user_id) references user_info (id) on delete CASCADE,
  constraint training_quiz_sessions_quiz_type_check check (
    (
      quiz_type = any (array['posttest'::text, 'review'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_sessions_user on public.training_quiz_sessions using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_sessions_progress on public.training_quiz_sessions using btree (progress_id) TABLESPACE pg_default;

create index IF not exists idx_sessions_completed on public.training_quiz_sessions using btree (completed_at desc) TABLESPACE pg_default
where
  (completed_at is not null);

create index IF not exists idx_sessions_type on public.training_quiz_sessions using btree (quiz_type) TABLESPACE pg_default;

create trigger trg_update_progress
after
update OF completed_at on training_quiz_sessions for EACH row
execute FUNCTION update_progress_on_completion ();

create table public.training_seasons (
  id uuid not null default gen_random_uuid (),
  name text not null,
  start_date date not null,
  end_date date not null,
  is_active boolean null default false,
  created_at timestamp with time zone null default now(),
  constraint training_seasons_pkey primary key (id),
  constraint valid_date_range check ((end_date > start_date))
) TABLESPACE pg_default;

create trigger trg_single_active_season BEFORE INSERT
or
update OF is_active on training_seasons for EACH row
execute FUNCTION ensure_single_active_season ();

create table public.training_streaks (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  season_id uuid not null,
  current_streak integer null default 0,
  longest_streak integer null default 0,
  last_activity_date date null,
  weeks_with_weekend_activity integer null default 0,
  updated_at timestamp with time zone null default now(),
  constraint training_streaks_pkey primary key (id),
  constraint training_streaks_user_id_season_id_key unique (user_id, season_id),
  constraint training_streaks_season_id_fkey foreign KEY (season_id) references training_seasons (id) on delete CASCADE,
  constraint training_streaks_user_id_fkey foreign KEY (user_id) references user_info (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_streaks_user_season on public.training_streaks using btree (user_id, season_id) TABLESPACE pg_default;

create trigger trg_streaks_timestamp BEFORE
update on training_streaks for EACH row
execute FUNCTION update_timestamp ();

create table public.training_topics (
  id text not null,
  name text not null,
  "Type" text null,
  notion_url text null,
  cover_image_url text null,
  display_order integer null default 0,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  description text null,
  constraint training_topics_pkey primary key (id)
) TABLESPACE pg_default;

create trigger trg_topics_timestamp BEFORE
update on training_topics for EACH row
execute FUNCTION update_timestamp ();

create table public.training_user_badges (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  badge_id uuid not null,
  season_id uuid null,
  earned_at timestamp with time zone null default now(),
  constraint training_user_badges_pkey primary key (id),
  constraint training_user_badges_user_id_badge_id_season_id_key unique (user_id, badge_id, season_id),
  constraint training_user_badges_badge_id_fkey foreign KEY (badge_id) references training_badges (id) on delete CASCADE,
  constraint training_user_badges_season_id_fkey foreign KEY (season_id) references training_seasons (id),
  constraint training_user_badges_user_id_fkey foreign KEY (user_id) references user_info (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_badges_user on public.training_user_badges using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_badges_season on public.training_user_badges using btree (season_id) TABLESPACE pg_default;

create table public.training_user_progress (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  topic_id text not null,
  season_id uuid not null,
  posttest_score integer null,
  posttest_completed_at timestamp with time zone null,
  posttest_attempts integer null default 0,
  posttest_last_attempt_at timestamp with time zone null,
  last_review_score integer null,
  last_review_at timestamp with time zone null,
  next_review_at timestamp with time zone null,
  review_count integer null default 0,
  content_read_at timestamp with time zone null,
  content_read_count integer null default 0,
  mastery_level text null default 'beginner'::text,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint training_user_progress_pkey primary key (id),
  constraint training_user_progress_user_id_topic_id_season_id_key unique (user_id, topic_id, season_id),
  constraint training_user_progress_season_id_fkey foreign KEY (season_id) references training_seasons (id) on delete CASCADE,
  constraint training_user_progress_topic_id_fkey foreign KEY (topic_id) references training_topics (id) on delete CASCADE,
  constraint training_user_progress_user_id_fkey foreign KEY (user_id) references user_info (id) on delete CASCADE,
  constraint training_user_progress_mastery_level_check check (
    (
      mastery_level = any (
        array[
          'beginner'::text,
          'learning'::text,
          'competent'::text,
          'expert'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_progress_user_season on public.training_user_progress using btree (user_id, season_id) TABLESPACE pg_default;

create index IF not exists idx_progress_topic on public.training_user_progress using btree (topic_id) TABLESPACE pg_default;

create index IF not exists idx_progress_review on public.training_user_progress using btree (next_review_at) TABLESPACE pg_default
where
  (next_review_at is not null);

create index IF not exists idx_progress_mastery on public.training_user_progress using btree (mastery_level) TABLESPACE pg_default;

create trigger trg_progress_timestamp BEFORE
update on training_user_progress for EACH row
execute FUNCTION update_timestamp ();

create trigger trg_auto_fill_season BEFORE INSERT on training_user_progress for EACH row
execute FUNCTION auto_fill_active_season ();


create view public.training_v_badges as
select
  b.id as badge_id,
  b.name as badge_name,
  b.description,
  b.icon,
  b.image_url,
  b.category,
  b.points,
  b.rarity,
  b.requirement_type,
  b.requirement_value,
  ub.user_id,
  ub.season_id,
  case
    when ub.id is not null then true
    else false
  end as is_earned,
  ub.earned_at
from
  training_badges b
  left join training_user_badges ub on ub.badge_id = b.id
where
  b.is_active = true
order by
  (
    case b.rarity
      when 'legendary'::text then 1
      when 'epic'::text then 2
      when 'rare'::text then 3
      else 4
    end
  ),
  b.category,
  b.name;

  create view public.training_v_leaderboard as
with
  user_scores as (
    select
      ui.id as user_id,
      ui.nickname,
      ui.photo_url,
      s.id as season_id,
      s.name as season_name,
      count(
        distinct case
          when up.posttest_completed_at is not null then up.topic_id
          else null::text
        end
      ) as topics_passed,
      COALESCE(
        round(
          avg(up.posttest_score) filter (
            where
              up.posttest_completed_at is not null
          ),
          1
        ),
        0::numeric
      ) as avg_score,
      COALESCE(sum(up.review_count), 0::bigint)::integer as total_reviews,
      COALESCE(st.current_streak, 0) as current_streak,
      COALESCE(st.longest_streak, 0) as longest_streak,
      (
        select
          count(*) as count
        from
          training_user_badges ub
        where
          ub.user_id = ui.id
          and (
            ub.season_id = s.id
            or ub.season_id is null
          )
      ) as badge_count,
      (
        count(
          distinct case
            when up.posttest_completed_at is not null then up.topic_id
            else null::text
          end
        ) * 100
      )::numeric + COALESCE(
        round(
          avg(up.posttest_score) filter (
            where
              up.posttest_completed_at is not null
          ),
          0
        ),
        0::numeric
      ) + (COALESCE(sum(up.review_count), 0::bigint) * 5)::numeric + (
        (
          (
            select
              count(*) as count
            from
              training_user_badges ub
            where
              ub.user_id = ui.id
              and (
                ub.season_id = s.id
                or ub.season_id is null
              )
          )
        ) * 10
      )::numeric as total_score
    from
      user_info ui
      cross join training_seasons s
      left join training_user_progress up on up.user_id = ui.id
      and up.season_id = s.id
      left join training_streaks st on st.user_id = ui.id
      and st.season_id = s.id
    where
      s.is_active = true
    group by
      ui.id,
      ui.nickname,
      ui.photo_url,
      s.id,
      s.name,
      st.current_streak,
      st.longest_streak
    having
      count(
        distinct case
          when up.posttest_completed_at is not null then up.topic_id
          else null::text
        end
      ) > 0
  )
select
  user_scores.user_id,
  user_scores.nickname,
  user_scores.photo_url,
  user_scores.season_id,
  user_scores.season_name,
  user_scores.topics_passed,
  user_scores.avg_score,
  user_scores.total_reviews,
  user_scores.current_streak,
  user_scores.longest_streak,
  user_scores.badge_count,
  user_scores.total_score,
  rank() over (
    partition by
      user_scores.season_id
    order by
      user_scores.total_score desc
  ) as rank,
  (
    select
      count(*) as count
    from
      user_scores user_scores_1
  ) as total_users
from
  user_scores
order by
  user_scores.total_score desc;

  create view public.training_v_needs_review as
select
  up.user_id,
  ui.nickname,
  ui.fcm_token,
  t.id as topic_id,
  t.name as topic_name,
  t.cover_image_url,
  s.id as season_id,
  s.name as season_name,
  up.next_review_at,
  up.mastery_level,
  up.last_review_score,
  up.review_count,
  GREATEST(
    0,
    EXTRACT(
      day
      from
        now() - up.next_review_at
    )::integer
  ) as days_overdue
from
  training_user_progress up
  join training_topics t on up.topic_id = t.id
  join user_info ui on up.user_id = ui.id
  join training_seasons s on up.season_id = s.id
where
  s.is_active = true
  and t.is_active = true
  and up.posttest_completed_at is not null
  and up.next_review_at is not null
  and up.next_review_at <= now()
order by
  up.next_review_at;

  create view public.training_v_needs_review as
select
  up.user_id,
  ui.nickname,
  ui.fcm_token,
  t.id as topic_id,
  t.name as topic_name,
  t.cover_image_url,
  s.id as season_id,
  s.name as season_name,
  up.next_review_at,
  up.mastery_level,
  up.last_review_score,
  up.review_count,
  GREATEST(
    0,
    EXTRACT(
      day
      from
        now() - up.next_review_at
    )::integer
  ) as days_overdue
from
  training_user_progress up
  join training_topics t on up.topic_id = t.id
  join user_info ui on up.user_id = ui.id
  join training_seasons s on up.season_id = s.id
where
  s.is_active = true
  and t.is_active = true
  and up.posttest_completed_at is not null
  and up.next_review_at is not null
  and up.next_review_at <= now()
order by
  up.next_review_at;

  create view public.training_v_thinking_analysis as
select
  qs.user_id,
  qs.season_id,
  q.thinking_type,
  count(*) as total_questions,
  sum(
    case
      when qa.is_correct then 1
      else 0
    end
  ) as correct_count,
  round(
    100.0 * sum(
      case
        when qa.is_correct then 1
        else 0
      end
    )::numeric / NULLIF(count(*), 0)::numeric,
    1
  ) as percent_correct
from
  training_quiz_answers qa
  join training_questions q on qa.question_id = q.id
  join training_quiz_sessions qs on qa.session_id = qs.id
where
  q.thinking_type is not null
  and qs.completed_at is not null
group by
  qs.user_id,
  qs.season_id,
  q.thinking_type
order by
  qs.user_id,
  q.thinking_type;

  create view public.training_v_quiz_history as
select
  qs.id as session_id,
  qs.user_id,
  qs.topic_id,
  t.name as topic_name,
  t.cover_image_url,
  qs.season_id,
  s.name as season_name,
  qs.progress_id,
  qs.quiz_type,
  qs.attempt_number,
  qs.score,
  qs.total_questions,
  qs.passing_score,
  qs.is_passed,
  qs.time_limit_seconds,
  qs.duration_seconds,
  qs.started_at,
  qs.completed_at,
  round(
    100.0 * qs.score::numeric / NULLIF(qs.total_questions, 0)::numeric,
    1
  ) as score_percent,
  (
    select
      jsonb_object_agg(
        sub.thinking_type,
        jsonb_build_object(
          'total',
          sub.total,
          'correct',
          sub.correct,
          'percent',
          round(
            100.0 * sub.correct::numeric / NULLIF(sub.total, 0)::numeric,
            1
          )
        )
      ) as jsonb_object_agg
    from
      (
        select
          q.thinking_type,
          count(*) as total,
          sum(
            case
              when qa.is_correct then 1
              else 0
            end
          ) as correct
        from
          training_quiz_answers qa
          join training_questions q on qa.question_id = q.id
        where
          qa.session_id = qs.id
          and q.thinking_type is not null
        group by
          q.thinking_type
      ) sub
  ) as thinking_breakdown
from
  training_quiz_sessions qs
  join training_topics t on qs.topic_id = t.id
  join training_seasons s on qs.season_id = s.id
where
  qs.completed_at is not null
order by
  qs.completed_at desc;

  create view public.training_v_topic_detail as
select
  t.id as topic_id,
  t.name as topic_name,
  t.notion_url,
  t.cover_image_url,
  t.display_order,
  c.id as content_id,
  c.title as content_title,
  c.content_markdown,
  c.content_summary,
  c.reading_time_minutes,
  c.synced_at as content_synced_at,
  up.user_id,
  up.season_id,
  up.id as progress_id,
  COALESCE(up.content_read_at is not null, false) as is_read,
  COALESCE(up.content_read_count, 0) as read_count,
  COALESCE(up.posttest_completed_at is not null, false) as is_passed,
  case
    when up.posttest_completed_at is not null
    and up.next_review_at is not null
    and up.next_review_at <= now() then 'review_due'::text
    when up.posttest_completed_at is not null then 'passed'::text
    when up.posttest_score is not null then 'in_progress'::text
    else 'not_started'::text
  end as quiz_status,
  up.posttest_score,
  up.last_review_score,
  COALESCE(up.posttest_attempts, 0) as posttest_attempts,
  COALESCE(up.review_count, 0) as review_count,
  COALESCE(up.mastery_level, 'beginner'::text) as mastery_level,
  up.content_read_at,
  up.posttest_completed_at,
  up.posttest_last_attempt_at,
  up.last_review_at,
  up.next_review_at,
  (
    select
      count(*) as count
    from
      training_questions q
    where
      q.topic_id = t.id
      and q.is_active = true
      and (
        q.season_id is null
        or q.season_id = up.season_id
      )
  ) as question_count
from
  training_topics t
  left join training_seasons s on s.is_active = true
  left join training_content c on c.topic_id = t.id
  and c.is_active = true
  and (
    c.season_id is null
    or c.season_id = s.id
  )
  left join training_user_progress up on up.topic_id = t.id
  and up.season_id = s.id
where
  t.is_active = true;

  create view public.training_v_topics_with_progress as
select
  t.id as topic_id,
  t.name as topic_name,
  t."Type" as topic_type,
  t.notion_url,
  t.cover_image_url,
  t.display_order,
  up.id as progress_id,
  up.user_id,
  up.season_id,
  COALESCE(up.content_read_at is not null, false) as is_read,
  COALESCE(up.content_read_count, 0) as read_count,
  up.content_read_at,
  COALESCE(up.posttest_completed_at is not null, false) as is_passed,
  case
    when up.posttest_completed_at is not null
    and up.next_review_at is not null
    and up.next_review_at <= now() then 'review_due'::text
    when up.posttest_completed_at is not null then 'passed'::text
    when up.posttest_score is not null then 'in_progress'::text
    else 'not_started'::text
  end as quiz_status,
  up.posttest_score,
  up.last_review_score,
  COALESCE(up.posttest_attempts, 0) as posttest_attempts,
  COALESCE(up.review_count, 0) as review_count,
  COALESCE(up.mastery_level, 'beginner'::text) as mastery_level,
  up.posttest_completed_at,
  up.posttest_last_attempt_at,
  up.last_review_at,
  up.next_review_at,
  up.updated_at as progress_updated_at,
  case
    when up.posttest_completed_at is not null
    and up.review_count > 0 then 100
    when up.posttest_completed_at is not null then 75
    when up.posttest_score is not null then 50
    when up.content_read_at is not null then 10
    else 0
  end as progress_percent
from
  training_topics t
  left join training_user_progress up on t.id = up.topic_id
  left join training_seasons s on up.season_id = s.id
  and s.is_active = true
where
  t.is_active = true
order by
  t.display_order,
  t.name;

  create view public.training_v_user_stats as
select
  ui.id as user_id,
  ui.nickname,
  ui.photo_url,
  s.id as season_id,
  s.name as season_name,
  (
    select
      count(*) as count
    from
      training_topics
    where
      training_topics.is_active = true
  ) as total_topics,
  count(
    distinct case
      when up.content_read_at is not null then up.topic_id
      else null::text
    end
  ) as topics_read,
  count(
    distinct case
      when up.posttest_completed_at is not null then up.topic_id
      else null::text
    end
  ) as topics_passed,
  count(
    distinct case
      when up.next_review_at <= now() then up.topic_id
      else null::text
    end
  ) as topics_need_review,
  count(
    distinct case
      when up.mastery_level = 'expert'::text then up.topic_id
      else null::text
    end
  ) as topics_expert,
  round(
    avg(up.posttest_score) filter (
      where
        up.posttest_score is not null
    ),
    1
  ) as avg_posttest_score,
  max(up.posttest_score) as best_posttest_score,
  COALESCE(sum(up.posttest_attempts), 0::bigint)::integer as total_posttest_attempts,
  COALESCE(sum(up.review_count), 0::bigint)::integer as total_reviews,
  COALESCE(sum(up.content_read_count), 0::bigint)::integer as total_content_reads,
  COALESCE(st.current_streak, 0) as current_streak,
  COALESCE(st.longest_streak, 0) as longest_streak,
  st.last_activity_date,
  (
    select
      count(*) as count
    from
      training_user_badges ub
    where
      ub.user_id = ui.id
      and (
        ub.season_id = s.id
        or ub.season_id is null
      )
  ) as badge_count,
  round(
    100.0 * count(
      distinct case
        when up.posttest_completed_at is not null then up.topic_id
        else null::text
      end
    )::numeric / NULLIF(
      (
        select
          count(*) as count
        from
          training_topics
        where
          training_topics.is_active = true
      ),
      0
    )::numeric,
    1
  ) as completion_percent
from
  user_info ui
  cross join training_seasons s
  left join training_user_progress up on up.user_id = ui.id
  and up.season_id = s.id
  left join training_streaks st on st.user_id = ui.id
  and st.season_id = s.id
where
  s.is_active = true
group by
  ui.id,
  ui.nickname,
  ui.photo_url,
  s.id,
  s.name,
  st.current_streak,
  st.longest_streak,
  st.last_activity_date;