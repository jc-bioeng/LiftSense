-- ============================================================
-- LIFTSENSE: FORMAL SECURITY TEST SUITE
-- Date: 2026-03-01
-- ============================================================
-- Run this script in the Supabase SQL Editor (service_role).
-- Results are returned as labeled rows for easy auditing.
-- ============================================================


-- ============================================================
-- PHASE 4: SCHEMA INTEGRITY REVIEW
-- ============================================================

-- TEST 4.1: All target tables have RLS enabled
SELECT 
  '4.1 RLS Enabled' AS test,
  tablename,
  CASE WHEN rowsecurity THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('profiles','anthropometry_profiles','sessions','landmarks','metrics','profile_relations')
ORDER BY tablename;

-- TEST 4.2: Exactly 1 policy per table (no duplicates)
SELECT 
  '4.2 Policy Count' AS test,
  tablename,
  count(*) AS policy_count,
  CASE WHEN count(*) = 1 THEN 'PASS' ELSE 'FAIL: ' || count(*) || ' policies' END AS result
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- TEST 4.3: List all active policies (for manual audit)
SELECT 
  '4.3 Active Policies' AS test,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename;

-- TEST 4.4: Check ENUMs exist with correct values
SELECT 
  '4.4 ENUM Check' AS test,
  t.typname AS enum_name,
  string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname IN ('user_role','capture_mode','coordinate_system','biomech_phase','anthropometry_model','subscription_status','plan_type')
GROUP BY t.typname
ORDER BY t.typname;

-- TEST 4.5: Foreign key constraints
SELECT 
  '4.5 FK Constraints' AS test,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table,
  ccu.column_name AS foreign_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- TEST 4.6: Indexes on policy-critical columns
SELECT 
  '4.6 Index Check' AS test,
  indexname,
  tablename
FROM pg_indexes 
WHERE schemaname = 'public'
AND (
  indexname LIKE '%user_id%' 
  OR indexname LIKE '%session_id%' 
  OR indexname LIKE '%coach%' 
  OR indexname LIKE '%athlete%'
  OR indexname LIKE '%metrics%'
)
ORDER BY tablename;


-- ============================================================
-- PHASE 3: FUNCTION SECURITY AUDIT
-- ============================================================

-- TEST 3.1: Verify search_path is set on all public functions
SELECT 
  '3.1 Search Path' AS test,
  p.proname AS function_name,
  CASE 
    WHEN p.proconfig IS NOT NULL AND array_to_string(p.proconfig, ',') LIKE '%search_path%' 
    THEN 'PASS: ' || array_to_string(p.proconfig, ', ')
    ELSE 'FAIL: No explicit search_path'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN ('get_user_role', 'enforce_single_active_anthropometry', 'check_guest_session_limit', 'check_coach_athlete_limit')
ORDER BY p.proname;

-- TEST 3.2: No SECURITY DEFINER functions in public schema (except system)
SELECT 
  '3.2 SECURITY DEFINER' AS test,
  p.proname AS function_name,
  CASE WHEN p.prosecdef THEN 'FAIL: Is SECURITY DEFINER' ELSE 'PASS' END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN ('get_user_role', 'enforce_single_active_anthropometry', 'check_guest_session_limit', 'check_coach_athlete_limit')
ORDER BY p.proname;

-- TEST 3.3: Trigger existence check
SELECT 
  '3.3 Triggers' AS test,
  trigger_name,
  event_manipulation,
  event_object_table,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table;
