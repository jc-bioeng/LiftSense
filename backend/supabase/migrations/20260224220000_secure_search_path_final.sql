-- Migration: Secure Function Search Path (Best Practice Version)
-- Date: 2026-02-24
-- Purpose: Fix "Function Search Path Mutable" warnings by anchoring search_path to public and pg_catalog.

-- 1. Helper: Get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS public.user_role AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE
SET search_path = public, pg_catalog;

-- 2. Trigger: Ensure single active anthropometry
CREATE OR REPLACE FUNCTION public.enforce_single_active_anthropometry()
RETURNS trigger AS $$
BEGIN
  IF NEW.is_active THEN
    UPDATE public.anthropometry_profiles
    SET is_active = false,
        valid_to = now()
    WHERE user_id = NEW.user_id
      AND id <> NEW.id
      AND is_active = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_catalog;

-- 3. Trigger: Guest session limits
CREATE OR REPLACE FUNCTION public.check_guest_session_limit()
RETURNS trigger AS $$
BEGIN
  IF public.get_user_role() = 'guest' THEN
    IF (SELECT count(*) FROM public.sessions WHERE user_id = auth.uid()) >= 3 THEN
      RAISE EXCEPTION 'Guest session limit reached (Max: 3)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_catalog;
