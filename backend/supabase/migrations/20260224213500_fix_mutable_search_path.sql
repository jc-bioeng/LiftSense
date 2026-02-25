-- Migration: Secure Function Search Path (Final Fix)
-- Date: 2026-02-24
-- Purpose: Set explicit search_path on public functions to prevent search path hijacking.

-- 1. Helper: Get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE
SET search_path = public;

-- 2. Trigger: Ensure single active anthropometry
CREATE OR REPLACE FUNCTION public.enforce_single_active_anthropometry()
RETURNS trigger AS $$
BEGIN
  IF NEW.is_active THEN
    UPDATE anthropometry_profiles
    SET is_active = false,
        valid_to = now()
    WHERE user_id = NEW.user_id
      AND id <> NEW.id
      AND is_active = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public;

-- 3. Trigger: Guest session limits
CREATE OR REPLACE FUNCTION public.check_guest_session_limit()
RETURNS trigger AS $$
BEGIN
  IF get_user_role() = 'guest' THEN
    IF (SELECT count(*) FROM sessions WHERE user_id = auth.uid()) >= 3 THEN
      RAISE EXCEPTION 'Guest session limit reached (Max: 3)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public;
