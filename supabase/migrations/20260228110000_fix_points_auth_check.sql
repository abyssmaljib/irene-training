-- ============================================================
-- Migration: Fix auth check ใน get_leaderboard & get_user_tier
-- ============================================================
-- ปัญหา: auth.uid() IS NULL สำหรับ service_role
-- Fix: อนุญาต service_role ด้วย
-- ============================================================

-- ============================================================
-- 1. Fix get_leaderboard auth check
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
    ui.nursinghome_id,
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

-- ============================================================
-- 2. Fix get_user_tier auth check
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_tier(p_user_id uuid)
RETURNS TABLE(
  tier_id uuid,
  tier_name text,
  tier_name_th text,
  tier_icon text,
  tier_color text,
  min_points integer,
  next_tier_name text,
  next_tier_min_points integer,
  total_points bigint,
  tier_type text,
  percentile numeric,
  rolling_points integer,
  rank_in_cohort integer,
  cohort_size integer,
  points_gap_to_next integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_points BIGINT;
  v_has_cache BOOLEAN;
BEGIN
  -- ตรวจสอบว่า user login แล้ว (ป้องกัน anonymous access)
  -- อนุญาต service_role ด้วย (สำหรับ admin operations)
  IF auth.uid() IS NULL AND current_setting('request.jwt.claims', true)::jsonb->>'role' != 'service_role' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- คำนวณ total points (bypass RLS เพราะเป็น SECURITY DEFINER)
  SELECT COALESCE(SUM(point_change), 0) INTO v_total_points
  FROM "Point_Transaction"
  WHERE "Point_Transaction".user_id = p_user_id;

  -- เช็คว่ามี cache ไหม
  SELECT EXISTS(
    SELECT 1 FROM public.user_tier_cache
    WHERE user_tier_cache.user_id = p_user_id
  ) INTO v_has_cache;

  IF v_has_cache THEN
    RETURN QUERY
    SELECT
      utc.tier_id,
      utc.tier_name,
      utc.tier_name_th,
      utc.tier_icon,
      utc.tier_color,
      0::INT AS min_points,
      utc.next_tier_name,
      (utc.rolling_points + COALESCE(utc.points_gap_to_next, 0))::INT AS next_tier_min_points,
      v_total_points,
      'percentile'::TEXT AS tier_type,
      utc.percentile,
      utc.rolling_points,
      utc.rank_in_cohort,
      utc.cohort_size,
      utc.points_gap_to_next
    FROM public.user_tier_cache utc
    WHERE utc.user_id = p_user_id;
  ELSE
    RETURN QUERY
    WITH current_tier AS (
      SELECT pt.*
      FROM point_tiers pt
      WHERE pt.is_active = true AND pt.min_points <= v_total_points
      ORDER BY pt.min_points DESC
      LIMIT 1
    ),
    next_t AS (
      SELECT pt.name, pt.min_points
      FROM point_tiers pt
      WHERE pt.is_active = true AND pt.min_points > v_total_points
      ORDER BY pt.min_points ASC
      LIMIT 1
    )
    SELECT
      ct.id,
      ct.name,
      ct.name_th,
      ct.icon,
      ct.color,
      ct.min_points,
      nt.name,
      nt.min_points,
      v_total_points,
      'fixed'::TEXT AS tier_type,
      NULL::NUMERIC(5,2) AS percentile,
      NULL::INT AS rolling_points,
      NULL::INT AS rank_in_cohort,
      NULL::INT AS cohort_size,
      NULL::INT AS points_gap_to_next
    FROM current_tier ct
    LEFT JOIN next_t nt ON true;
  END IF;
END;
$$;

-- ============================================================
-- 3. GRANT/REVOKE (ซ้ำเพื่อความชัวร์)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_leaderboard(integer, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(integer, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_tier(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_tier(uuid) TO service_role;
REVOKE EXECUTE ON FUNCTION public.get_leaderboard(integer, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_user_tier(uuid) FROM anon;