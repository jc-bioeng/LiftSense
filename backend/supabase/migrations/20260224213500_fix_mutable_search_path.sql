-- Migration: Fix Function Search Path (Security Best Practice)
-- Date: 2026-02-24

ALTER FUNCTION public.get_user_role() SET search_path = public;
ALTER FUNCTION public.enforce_single_active_anthropometry() SET search_path = public;
ALTER FUNCTION public.check_guest_session_limit() SET search_path = public;

-- Explicitly qualify table names in functions
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;
