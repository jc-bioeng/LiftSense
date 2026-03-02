-- Migration: Subscriptions and Enhanced Limits
-- Date: 2026-03-01
-- Purpose: Add subscription fields, plan types, and enforce daily guest limits and coach athlete limits.

/************************************************************
 * 1. NEW ENUM TYPES
 ************************************************************/

CREATE TYPE subscription_status AS ENUM (
  'active',
  'trial',
  'canceled',
  'past_due'
);

CREATE TYPE plan_type AS ENUM (
  'free',
  'pro',
  'coach_starter',
  'coach_pro',
  'coach_elite'
);

/************************************************************
 * 2. UPDATE PROFILES TABLE
 ************************************************************/

ALTER TABLE public.profiles 
ADD COLUMN subscription_status subscription_status NOT NULL DEFAULT 'trial',
ADD COLUMN plan_type plan_type NOT NULL DEFAULT 'free';

/************************************************************
 * 3. UPDATE GUEST SESSION LIMIT TRIGGER (DAILY LIMIT)
 ************************************************************/

CREATE OR REPLACE FUNCTION public.check_guest_session_limit()
RETURNS trigger AS $$
BEGIN
  IF public.get_user_role() = 'guest' THEN
    -- Limit 2 sessions per day (last 24 hours)
    IF (SELECT count(*) FROM public.sessions 
        WHERE user_id = auth.uid() 
        AND created_at > now() - interval '24 hours') >= 2 THEN
      RAISE EXCEPTION 'Guest daily session limit reached (Max: 2 per 24h)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_catalog;

/************************************************************
 * 4. COACH ATHLETE LIMIT TRIGGER
 ************************************************************/

CREATE OR REPLACE FUNCTION public.check_coach_athlete_limit()
RETURNS trigger AS $$
DECLARE
  v_plan plan_type;
  v_current_count int;
  v_limit int;
BEGIN
  -- Get coach's plan
  SELECT plan_type INTO v_plan FROM public.profiles WHERE id = NEW.coach_id;

  -- Only enforce for coaches
  IF v_plan NOT IN ('coach_starter', 'coach_pro', 'coach_elite') THEN
    RETURN NEW; -- Or raise an error if non-coach tries to link, but RLS should handle that
  END IF;

  -- Elite is unlimited
  IF v_plan = 'coach_elite' THEN
    RETURN NEW;
  END IF;

  -- Map limits
  v_limit := CASE 
    WHEN v_plan = 'coach_starter' THEN 5
    WHEN v_plan = 'coach_pro' THEN 20
    ELSE 0
  END;

  -- Count active relations
  SELECT count(*) INTO v_current_count 
  FROM public.profile_relations 
  WHERE coach_id = NEW.coach_id AND status = 'active';

  IF v_current_count >= v_limit THEN
    RAISE EXCEPTION 'Coach athlete limit reached for plan % (Max: %)', v_plan, v_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_catalog;

CREATE TRIGGER trg_coach_athlete_limit
BEFORE INSERT ON public.profile_relations
FOR EACH ROW
EXECUTE FUNCTION public.check_coach_athlete_limit();
