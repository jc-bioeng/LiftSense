-- Migration: Solid RLS Base for LiftSense
-- Date: 2026-02-24

/************************************************************
 * 1. HELPER FUNCTION: GET USER ROLE
 ************************************************************/
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

/************************************************************
 * 2. PROFILES RLS
 ************************************************************/
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing if any to avoid errors during re-run
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON profiles;

-- Usuario puede ver su propio perfil
CREATE POLICY "Users can view own profile"
ON profiles
FOR SELECT
USING (id = auth.uid());

-- Usuario puede actualizar su propio perfil
CREATE POLICY "Users can update own profile"
ON profiles
FOR UPDATE
USING (id = auth.uid());

-- Admin puede ver todos
CREATE POLICY "Admin can view all profiles"
ON profiles
FOR SELECT
USING (get_user_role() = 'admin');

/************************************************************
 * 3. ANTHROPOMETRY_PROFILES RLS
 ************************************************************/
ALTER TABLE anthropometry_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own anthropometry" ON anthropometry_profiles;

CREATE POLICY "Users manage own anthropometry"
ON anthropometry_profiles
FOR ALL
USING (
  user_id = auth.uid()
  OR get_user_role() = 'admin'
);

/************************************************************
 * 4. SESSIONS RLS
 ************************************************************/
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own sessions" ON sessions;

CREATE POLICY "Users manage own sessions"
ON sessions
FOR ALL
USING (
  user_id = auth.uid()
  OR get_user_role() = 'admin'
);

/************************************************************
 * 5. LANDMARKS RLS
 ************************************************************/
ALTER TABLE landmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users access own landmarks" ON landmarks;

CREATE POLICY "Users access own landmarks"
ON landmarks
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM sessions
    WHERE sessions.id = landmarks.session_id
    AND (
      sessions.user_id = auth.uid()
      OR get_user_role() = 'admin'
    )
  )
);

/************************************************************
 * 6. METRICS RLS
 ************************************************************/
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users access own metrics" ON metrics;

CREATE POLICY "Users access own metrics"
ON metrics
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM sessions
    WHERE sessions.id = metrics.session_id
    AND (
      sessions.user_id = auth.uid()
      OR get_user_role() = 'admin'
    )
  )
);
