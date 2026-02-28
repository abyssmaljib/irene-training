-- ============================================================
-- Migration: Fix type mismatch ใน get_leaderboard
-- ============================================================
-- ปัญหา: user_info.nursinghome_id เป็น bigint แต่ RETURNS TABLE
-- ประกาศ nursinghome_id integer → error "structure of query
-- does not match function result type"
--
-- Fix: cast ui.nursinghome_id::integer ใน SELECT
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_nursinghome_id integer DEFAULT NULL,
  p_period text DEFAULT 'all_time',
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  user_id uuid,
  nickname text,
  full_name text,
  photo_url text,
  nursinghome_id integer,
  total_points bigint,
  tier_name text,
  tier_icon text,
  tier_color text,
  rank bigint,
  tier_name_th text,
  percentile numeric,
  rolling_points integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start_date TIMESTAMPTZ;
BEGIN
  -- ตรวจสอบว่า user login แล้ว (ป้องกัน anonymous access)
  -- อนุญาต service_role ด้วย (สำหรับ admin operations)
  IF auth.uid() IS NULL AND current_setting('request.jwt.claims', true)::jsonb->>'role' != 'service_role' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- กำหนด start date ตาม period
  CASE p_period
    WHEN 'this_week' THEN
      v_start_date := date_trunc('week', now());
    WHEN 'this_month' THEN
      v_start_date := date_trunc('month', now());
    WHEN 'rolling_3m' THEN
      v_start_date := NOW() - INTERVAL '3 months';
    ELSE
      v_start_date := NULL;
  END CASE;

  RETURN QUERY
  WITH user_points AS (
    SELECT
      pt.user_id,
      SUM(pt.point_change) AS points
    FROM "Point_Transaction" pt
    WHERE (v_start_date IS NULL OR pt.created_at >= v_start_date)
      AND (p_nursinghome_id IS NULL OR pt.nursinghome_id = p_nursinghome_id)
    GROUP BY pt.user_id
  ),
  ranked_users AS (
    SELECT
      up.user_id,
      up.points,
      RANK() OVER (ORDER BY up.points DESC) AS user_rank
    FROM user_points up
  )
  SELECT
    ru.user_id,
    ui.nickname,
    ui.full_name,
    ui.photo_url,
    -- Cast bigint → integer เพื่อให้ตรงกับ RETURNS TABLE
    ui.nursinghome_id::integer,
    ru.points AS total_points,
    COALESCE(utc.tier_name, ptier.name) AS tier_name,
    COALESCE(utc.tier_icon, ptier.icon) AS tier_icon,
    COALESCE(utc.tier_color, ptier.color) AS tier_color,
    ru.user_rank AS rank,
    COALESCE(utc.tier_name_th, ptier.name_th) AS tier_name_th,
    utc.percentile,
    utc.rolling_points
  FROM ranked_users ru
  JOIN user_info ui ON ui.id = ru.user_id
  LEFT JOIN public.user_tier_cache utc ON utc.user_id = ru.user_id
  LEFT JOIN LATERAL (
    SELECT t.name, t.name_th, t.icon, t.color
    FROM point_tiers t
    WHERE t.is_active = true AND t.min_points <= ru.points
    ORDER BY t.min_points DESC
    LIMIT 1
  ) ptier ON utc.user_id IS NULL
  WHERE p_nursinghome_id IS NULL OR ui.nursinghome_id = p_nursinghome_id
  ORDER BY ru.user_rank
  LIMIT p_limit;
END;
$$;