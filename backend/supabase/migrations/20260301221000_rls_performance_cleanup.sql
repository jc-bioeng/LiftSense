-- Migration: Final RLS Consolidation for Profiles
-- Date: 2026-03-01
-- Purpose: Eliminate "Multiple Permissive Policies" by consolidating admin and owner 
--          logic into a single "FOR ALL" policy with optimized subqueries.

/************************************************************
 * 1. DROP ALL POTENTIAL CONFLICTING POLICIES
 ************************************************************/

-- Borramos CUALQUIER política previa con estos nombres para limpiar el linter
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
DROP POLICY IF EXISTS "profiles_owner_insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_owner_manage" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_unified_policy" ON public.profiles;
DROP POLICY IF EXISTS "Users can manage own profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;


/************************************************************
 * 2. CONSOLIDATED POLICY (The "One Policy to Rule Them All")
 ************************************************************/

-- Creamos UNA SOLA política para todos los roles y acciones.
-- Al ser la única política FOR ALL, Postgres no tiene nada más que evaluar.
CREATE POLICY "profiles_main_policy" ON public.profiles
FOR ALL 
TO authenticated
USING (
  id = (SELECT auth.uid()) 
  OR public.get_user_role() = 'admin'
)
WITH CHECK (
  id = (SELECT auth.uid()) 
  OR public.get_user_role() = 'admin'
);

-- Nota: Solo los administradores pueden ver perfiles de otros
-- (get_user_role() maneja esa lógica internamente)
