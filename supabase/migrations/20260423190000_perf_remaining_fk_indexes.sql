-- =====================================================
-- Performance: Add remaining 44 FK indexes
-- =====================================================
-- ที่มา: Supabase advisor `unindexed_foreign_keys` (44 ตัวเหลือจาก Migration 1)
-- ปัญหา: FK ไม่มี covering index → slow lookups + slow ON DELETE/UPDATE cascades
-- แก้: เพิ่ม btree index บน FK column
--
-- ตารางที่ครอบคลุม:
--   - billing/payroll: ai_pharmacist_*, billing_service_rates, payroll_*, staff_salary_history
--   - training/leaderboard: leaderboard_periods, period_reward_*, training_*, season_carryovers
--   - audit/utility: med_DB, med_atc_level2, med_photo_resize_queue, medMadeChange
--   - residents: resident_care_equipment, resident_measurements, resident_programs
--   - facility: B_Nursinghome_Location/WiFi, clock_break_time_nursinghome, nursinghomes
--   - misc: C_Calendar, C_Tasks, Post (DD_id), Point_Transaction (season_id), invitations, job_descriptions
--
-- Safety:
--   - IF NOT EXISTS — idempotent
--   - regular CREATE INDEX (transaction-safe ใน Supabase migration)
--   - ไม่แตะ view/column/RLS — ไม่กระทบ Flutter app

-- B_Nursinghome_Location
CREATE INDEX IF NOT EXISTS "idx_B_Nursinghome_Location_created_by"
  ON public."B_Nursinghome_Location" (created_by);
CREATE INDEX IF NOT EXISTS "idx_B_Nursinghome_Location_updated_by"
  ON public."B_Nursinghome_Location" (updated_by);

-- B_Nursinghome_WiFi
CREATE INDEX IF NOT EXISTS "idx_B_Nursinghome_WiFi_created_by"
  ON public."B_Nursinghome_WiFi" (created_by);
CREATE INDEX IF NOT EXISTS "idx_B_Nursinghome_WiFi_updated_by"
  ON public."B_Nursinghome_WiFi" (updated_by);

-- B_OneOnOne_Session
CREATE INDEX IF NOT EXISTS "idx_B_OneOnOne_Session_nursinghome_id"
  ON public."B_OneOnOne_Session" (nursinghome_id);

-- C_Calendar
CREATE INDEX IF NOT EXISTS "idx_C_Calendar_doctor_visit_summary_id"
  ON public."C_Calendar" (doctor_visit_summary_id);

-- C_Tasks
CREATE INDEX IF NOT EXISTS "idx_C_Tasks_assigned_role_id"
  ON public."C_Tasks" (assigned_role_id);
CREATE INDEX IF NOT EXISTS "idx_C_Tasks_assigned_user_id"
  ON public."C_Tasks" (assigned_user_id);

-- Medication Error Rate
CREATE INDEX IF NOT EXISTS "idx_Medication Error Rate_nursinghome_id"
  ON public."Medication Error Rate" (nursinghome_id);

-- Point_Transaction
CREATE INDEX IF NOT EXISTS "idx_Point_Transaction_season_id"
  ON public."Point_Transaction" (season_id);

-- Post
CREATE INDEX IF NOT EXISTS "idx_Post_DD_id"
  ON public."Post" ("DD_id");

-- ai_pharmacist_recommendations
CREATE INDEX IF NOT EXISTS idx_ai_pharmacist_recommendations_action_by
  ON public.ai_pharmacist_recommendations (action_by);

-- ai_pharmacist_reviews
CREATE INDEX IF NOT EXISTS idx_ai_pharmacist_reviews_requested_by
  ON public.ai_pharmacist_reviews (requested_by);
CREATE INDEX IF NOT EXISTS idx_ai_pharmacist_reviews_trigger_med_db_id
  ON public.ai_pharmacist_reviews (trigger_med_db_id);

-- billing_service_rates
CREATE INDEX IF NOT EXISTS idx_billing_service_rates_program_id
  ON public.billing_service_rates (program_id);

-- blended_food_recipes — 2 FKs ทั้งคู่บน created_by → 1 index พอ
CREATE INDEX IF NOT EXISTS idx_blended_food_recipes_created_by
  ON public.blended_food_recipes (created_by);

-- clock_break_time_nursinghome
CREATE INDEX IF NOT EXISTS idx_clock_break_time_nursinghome_nursinghome_id
  ON public.clock_break_time_nursinghome (nursinghome_id);

-- clock_in_out_ver2
CREATE INDEX IF NOT EXISTS idx_clock_in_out_ver2_duty_buyer
  ON public.clock_in_out_ver2 (duty_buyer);

-- invitations
CREATE INDEX IF NOT EXISTS idx_invitations_role_id
  ON public.invitations (role_id);

-- job_descriptions
CREATE INDEX IF NOT EXISTS idx_job_descriptions_role_id
  ON public.job_descriptions (role_id);

-- leader_evaluations
CREATE INDEX IF NOT EXISTS idx_leader_evaluations_evaluator_id
  ON public.leader_evaluations (evaluator_id);

-- leaderboard_periods
CREATE INDEX IF NOT EXISTS idx_leaderboard_periods_season_id
  ON public.leaderboard_periods (season_id);

-- medMadeChange
CREATE INDEX IF NOT EXISTS "idx_medMadeChange_appointment_id"
  ON public."medMadeChange" (appointment_id);
CREATE INDEX IF NOT EXISTS "idx_medMadeChange_post_id"
  ON public."medMadeChange" (post_id);

-- med_DB (quoted — mixed case)
CREATE INDEX IF NOT EXISTS "idx_med_DB_created_by"
  ON public."med_DB" (created_by);
CREATE INDEX IF NOT EXISTS "idx_med_DB_updated_by"
  ON public."med_DB" (updated_by);

-- med_atc_level2
CREATE INDEX IF NOT EXISTS idx_med_atc_level2_level1_code
  ON public.med_atc_level2 (level1_code);

-- med_photo_resize_queue
CREATE INDEX IF NOT EXISTS idx_med_photo_resize_queue_med_log_id
  ON public.med_photo_resize_queue (med_log_id);

-- nursinghomes
CREATE INDEX IF NOT EXISTS idx_nursinghomes_app_version_updated_by
  ON public.nursinghomes (app_version_updated_by);

-- payroll_monthly_adjustments
CREATE INDEX IF NOT EXISTS idx_payroll_monthly_adjustments_created_by
  ON public.payroll_monthly_adjustments (created_by);

-- payroll_transfer_settings
CREATE INDEX IF NOT EXISTS idx_payroll_transfer_settings_updated_by
  ON public.payroll_transfer_settings (updated_by);

-- period_reward_distributions
CREATE INDEX IF NOT EXISTS idx_period_reward_distributions_badge_id
  ON public.period_reward_distributions (badge_id);
CREATE INDEX IF NOT EXISTS idx_period_reward_distributions_template_id
  ON public.period_reward_distributions (template_id);

-- period_reward_templates
CREATE INDEX IF NOT EXISTS idx_period_reward_templates_badge_id
  ON public.period_reward_templates (badge_id);

-- resident_care_equipment
CREATE INDEX IF NOT EXISTS idx_resident_care_equipment_equipment_option_id
  ON public.resident_care_equipment (equipment_option_id);
CREATE INDEX IF NOT EXISTS idx_resident_care_equipment_updated_by
  ON public.resident_care_equipment (updated_by);

-- resident_measurements
CREATE INDEX IF NOT EXISTS idx_resident_measurements_recorded_by
  ON public.resident_measurements (recorded_by);

-- resident_programs
CREATE INDEX IF NOT EXISTS idx_resident_programs_billing_account_id
  ON public.resident_programs (billing_account_id);

-- season_carryovers
CREATE INDEX IF NOT EXISTS idx_season_carryovers_from_season_period_id
  ON public.season_carryovers (from_season_period_id);

-- staff_salary_history
CREATE INDEX IF NOT EXISTS idx_staff_salary_history_approved_by
  ON public.staff_salary_history (approved_by);

-- training_streaks
CREATE INDEX IF NOT EXISTS idx_training_streaks_season_id
  ON public.training_streaks (season_id);

-- training_user_badges
CREATE INDEX IF NOT EXISTS idx_training_user_badges_badge_id
  ON public.training_user_badges (badge_id);

-- user_rewards
CREATE INDEX IF NOT EXISTS idx_user_rewards_reward_id
  ON public.user_rewards (reward_id);
