-- Migration: Enforce Subscription Status on Coach Athlete Linking (Final)
-- Date: 2026-03-01
-- Purpose: Optimized security trigger with SECURITY DEFINER and verified gates.

-- 1. Update the function with SECURITY DEFINER to bypass RLS during plan validation
CREATE OR REPLACE FUNCTION public.check_coach_athlete_limit()
RETURNS trigger AS $$
DECLARE
  v_plan plan_type;
  v_status subscription_status;
  v_current_count int;
  v_limit int;
BEGIN
  -- Get coach's plan and subscription status (Bypassing RLS for validation)
  SELECT plan_type, subscription_status INTO v_plan, v_status 
  FROM public.profiles WHERE id = NEW.coach_id;

  -- Block if subscription is not active or trial (P0002)
  IF v_status NOT IN ('active', 'trial') OR v_status IS NULL THEN
    RAISE EXCEPTION 'Coach subscription is % (must be active or trial)', COALESCE(v_status::text, 'unknown')
    USING ERRCODE = 'P0002';
  END IF;

  -- Only enforce capacity for coach plans
  IF v_plan NOT IN ('coach_starter', 'coach_pro', 'coach_elite') THEN
    RETURN NEW;
  END IF;

  -- Elite cap (Theoretical large number)
  v_limit := CASE 
    WHEN v_plan = 'coach_starter' THEN 5
    WHEN v_plan = 'coach_pro' THEN 20
    WHEN v_plan = 'coach_elite' THEN 999999
    ELSE 0
  END;

  -- Count active relations
  SELECT count(*) INTO v_current_count 
  FROM public.profile_relations 
  WHERE coach_id = NEW.coach_id AND status = 'active';

  -- Validate capacity (P0001)
  IF v_current_count >= v_limit THEN
    RAISE EXCEPTION 'Coach athlete limit reached for plan % (Max: %)', v_plan, v_limit
    USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog;

-- 2. Audit: Ensured trigger is attached
DROP TRIGGER IF EXISTS trg_coach_athlete_limit ON profile_relations;
CREATE TRIGGER trg_coach_athlete_limit
BEFORE INSERT ON profile_relations
FOR EACH ROW
EXECUTE FUNCTION check_coach_athlete_limit();
