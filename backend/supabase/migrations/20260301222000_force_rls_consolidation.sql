-- Migration: Forced RLS Consolidation & Conflict Removal
-- Date: 2026-03-01
-- Purpose: Force drop of all legacy/overlapping policies and implement a single, unified, 
--          high-performance policy per table using deterministic subqueries.

/************************************************************
 * 1. AGGRESSIVE CLEANUP
 * Borramos CUALQUIER política previa para evitar el error "Multiple Permissive Policies"
 ************************************************************/

DO $$ 
DECLARE 
  r RECORD;
BEGIN
  -- Borra TODAS las políticas de las tablas del esquema public para empezar de cero
  FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public') 
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
  END LOOP;
END $$;

/************************************************************
 * 2. UNIFIED HIGH-PERFORMANCE POLICIES
 * Usamos una sola política FOR ALL por tabla con (SELECT auth.uid())
 ************************************************************/

-- PROFILES
CREATE POLICY "profiles_main_policy" ON public.profiles
FOR ALL TO authenticated 
USING (id = (SELECT auth.uid()) OR public.get_user_role() = 'admin')
WITH CHECK (id = (SELECT auth.uid()) OR public.get_user_role() = 'admin');

-- ANTHROPOMETRY
CREATE POLICY "anthro_main_policy" ON public.anthropometry_profiles
FOR ALL TO authenticated 
USING (user_id = (SELECT auth.uid()) OR public.get_user_role() = 'admin')
WITH CHECK (user_id = (SELECT auth.uid()) OR public.get_user_role() = 'admin');

-- SESSIONS
CREATE POLICY "sessions_main_policy" ON public.sessions
FOR ALL TO authenticated
USING (
  user_id = (SELECT auth.uid())
  OR public.get_user_role() = 'admin'
  OR EXISTS (
    SELECT 1 FROM public.profile_relations 
    WHERE coach_id = (SELECT auth.uid()) 
    AND athlete_id = sessions.user_id 
    AND status = 'active'
  )
);

-- RELATIONS
CREATE POLICY "relations_main_policy" ON public.profile_relations
FOR ALL TO authenticated
USING (
  coach_id = (SELECT auth.uid()) 
  OR athlete_id = (SELECT auth.uid()) 
  OR public.get_user_role() = 'admin'
);

-- LANDMARKS
CREATE POLICY "landmarks_main_policy" ON public.landmarks
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.sessions s 
    WHERE s.id = landmarks.session_id 
    AND (
      s.user_id = (SELECT auth.uid()) 
      OR public.get_user_role() = 'admin' 
      OR EXISTS (
        SELECT 1 FROM public.profile_relations pr 
        WHERE pr.coach_id = (SELECT auth.uid()) AND pr.athlete_id = s.user_id AND pr.status = 'active'
      )
    )
  )
);

-- METRICS
CREATE POLICY "metrics_main_policy" ON public.metrics
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.sessions s 
    WHERE s.id = metrics.session_id 
    AND (
      s.user_id = (SELECT auth.uid()) 
      OR public.get_user_role() = 'admin' 
      OR EXISTS (
        SELECT 1 FROM public.profile_relations pr 
        WHERE pr.coach_id = (SELECT auth.uid()) AND pr.athlete_id = s.user_id AND pr.status = 'active'
      )
    )
  )
);
