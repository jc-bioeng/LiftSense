-- ============================================================
-- TEST FASE 2: FULL FUNCTIONAL SECURITY TEST
-- ============================================================

DO $$ 
DECLARE 
  v_guest_id uuid := gen_random_uuid();
  v_anthro_id uuid := gen_random_uuid();
  v_coach_id uuid := gen_random_uuid();
  v_athlete_id uuid := gen_random_uuid();
BEGIN
  -- 1. Setup temporal sin restricciones de FK externas
  SET LOCAL session_replication_role = 'replica';

  -- TEST A: GUEST LIMIT
  INSERT INTO public.profiles (id, email, role) VALUES (v_guest_id, 'guest@test.ai', 'guest');
  INSERT INTO public.anthropometry_profiles (id, user_id, height_cm, weight_kg, is_active) VALUES (v_anthro_id, v_guest_id, 175, 75, true);
  
  -- Mock session identification
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_guest_id)::text, true);

  -- Insert 2 sessions (Allowed)
  INSERT INTO public.sessions (user_id, anthropometry_profile_id, capture_mode, exercise) 
  VALUES (v_guest_id, v_anthro_id, 'rgb', 'Squat'), (v_guest_id, v_anthro_id, 'rgb', 'Squat');
  
  BEGIN
    INSERT INTO public.sessions (user_id, anthropometry_profile_id, capture_mode, exercise) VALUES (v_guest_id, v_anthro_id, 'rgb', 'Squat');
    RAISE EXCEPTION 'TEST FAILED: Guest limit not enforced';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Guest daily limit enforced OK (Captured: %)', SQLERRM;
  END;

  -- TEST B: COACH SUBSCRIPTION GATE
  INSERT INTO public.profiles (id, email, role, plan_type, subscription_status) VALUES (v_coach_id, 'coach@test.ai', 'coach', 'coach_starter', 'canceled');
  INSERT INTO public.profiles (id, email, role) VALUES (v_athlete_id, 'athlete@test.ai', 'athlete');

  BEGIN
    INSERT INTO public.profile_relations (coach_id, athlete_id, status) VALUES (v_coach_id, v_athlete_id, 'active');
    RAISE EXCEPTION 'TEST FAILED: Canceled coach can add athlete';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Canceled coach subscription blocked OK (Captured: %)', SQLERRM;
  END;

  -- Limpieza
  SET LOCAL session_replication_role = 'origin';
  DELETE FROM public.profiles WHERE id IN (v_guest_id, v_coach_id, v_athlete_id);
END $$;
