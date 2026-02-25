-- Migration: Advanced Security Features (Multi-User & Guest Limits)
-- Date: 2026-02-24

/************************************************************
 * 1. MULTI-USER RELATIONSHIPS
 ************************************************************/

CREATE TABLE profile_relations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  athlete_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active', -- active, pending, revoked
  permissions text NOT NULL DEFAULT 'view_only', -- view_only, manage_sessions
  created_at timestamptz DEFAULT now(),
  
  -- Constraint: Cannot be your own coach
  CONSTRAINT no_self_relation CHECK (coach_id <> athlete_id),
  -- Constraint: Unique pair
  UNIQUE(coach_id, athlete_id)
);

-- Index for searching relations
CREATE INDEX idx_profile_relations_coach ON profile_relations(coach_id, status);
CREATE INDEX idx_profile_relations_athlete ON profile_relations(athlete_id, status);

ALTER TABLE profile_relations ENABLE ROW LEVEL SECURITY;

-- Policy: Admin can see everything
CREATE POLICY "Admin can see all relations" ON profile_relations FOR ALL USING (get_user_role() = 'admin');

-- Policy: Coach/Athlete can see their own relations
CREATE POLICY "Users can see their own relations" ON profile_relations FOR SELECT 
USING (coach_id = auth.uid() OR athlete_id = auth.uid());

/************************************************************
 * 2. REFINED RLS POLICIES (MULTI-USER ACCESS)
 ************************************************************/

-- Update SESSIONS Policy to include Coach access
DROP POLICY IF EXISTS "Users manage own sessions" ON sessions;
CREATE POLICY "Users and their Coaches can access sessions"
ON sessions
FOR ALL
USING (
  user_id = auth.uid()
  OR get_user_role() = 'admin'
  OR EXISTS (
    SELECT 1 FROM profile_relations 
    WHERE coach_id = auth.uid() 
    AND athlete_id = sessions.user_id 
    AND status = 'active'
  )
);

-- Landmarks and Metrics automatically inherit from Sessions via their EXISTS policies

/************************************************************
 * 3. GUEST SESSION LIMITS
 ************************************************************/

CREATE OR REPLACE FUNCTION check_guest_session_limit()
RETURNS trigger AS $$
BEGIN
  IF get_user_role() = 'guest' THEN
    IF (SELECT count(*) FROM sessions WHERE user_id = auth.uid()) >= 3 THEN
      RAISE EXCEPTION 'Guest session limit reached (Max: 3)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guest_session_limit
BEFORE INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION check_guest_session_limit();

/************************************************************
 * 4. COMMENTS & DOCUMENTATION
 ************************************************************/
COMMENT ON TABLE profile_relations IS 'Connects Coaches and Athletes for shared biomechanical analysis';
COMMENT ON COLUMN profile_relations.permissions IS 'view_only or manage_sessions';
