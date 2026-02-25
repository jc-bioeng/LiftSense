/************************************************************
 * LIFTSENSE – BACKEND DATABASE SCHEMA
 * Supabase / PostgreSQL
 *
 * Principios:
 * - Autenticación delegada a Supabase Auth
 * - profiles extiende auth.users (NO contraseñas)
 * - Antropometría versionada (no por sesión)
 * - Sesiones como eventos biomecánicos
 * - Preparado para análisis longitudinal e IA
 ************************************************************/

/************************************************************
 * ENUM TYPES
 * Tipos controlados para consistencia de datos
 ************************************************************/

-- Rol funcional del usuario dentro de LiftSense
CREATE TYPE user_role AS ENUM (
  'admin',
  'coach',
  'athlete',
  'guest'
);

-- Tipo de captura utilizada en la sesión
CREATE TYPE capture_mode AS ENUM (
  'rgb',
  'rgbd',
  'depth'
);

-- Sistema de coordenadas de los landmarks
CREATE TYPE coordinate_system AS ENUM (
  'camera',
  'world',
  'normalized'
);

-- Fases biomecánicas de un movimiento
CREATE TYPE biomech_phase AS ENUM (
  'eccentric',
  'concentric',
  'isometric',
  'transition'
);

-- Modelo utilizado para estimar antropometría
CREATE TYPE anthropometry_model AS ENUM (
  'generic',
  'subject_specific',
  'ml_estimated'
);


/************************************************************
 * PROFILES
 * Tabla pública que extiende auth.users
 * NO se almacenan contraseñas aquí
 ************************************************************/

CREATE TABLE profiles (
  -- Debe coincidir con auth.users.id
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Se guarda como referencia rápida (Auth es la fuente real)
  email text NOT NULL,

  -- Rol dentro del sistema
  role user_role NOT NULL DEFAULT 'athlete',

  -- Metadata libre (preferencias, flags, etc.)
  metadata jsonb DEFAULT '{}',

  created_at timestamptz DEFAULT now()
);


/************************************************************
 * ANTHROPOMETRY_PROFILES
 * Perfil antropométrico versionado por usuario
 * Cambia lentamente en el tiempo
 ************************************************************/

CREATE TABLE anthropometry_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Dueño del perfil antropométrico
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Medidas principales
  height_cm float,
  weight_kg float,

  -- Longitudes segmentales (flexible, extensible)
  segment_lengths jsonb,

  -- Modelo usado para estimación
  model anthropometry_model NOT NULL DEFAULT 'generic',

  -- Validez temporal del perfil
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,

  -- Solo un perfil activo por usuario
  is_active boolean NOT NULL DEFAULT true
);

-- Índices para consultas frecuentes
CREATE INDEX idx_anthropometry_user
  ON anthropometry_profiles(user_id);

CREATE INDEX idx_anthropometry_active
  ON anthropometry_profiles(user_id, is_active);


/************************************************************
 * PROFILE_RELATIONS
 * Conector entre usuarios (Coach -> Atleta)
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

CREATE INDEX idx_profile_relations_coach ON profile_relations(coach_id, status);
CREATE INDEX idx_profile_relations_athlete ON profile_relations(athlete_id, status);


/************************************************************
 * SESSIONS
 * Evento de captura biomecánica
 * Referencia al perfil antropométrico vigente
 ************************************************************/

CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Usuario que realiza la sesión
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Perfil antropométrico usado en esta sesión
  anthropometry_profile_id uuid NOT NULL
    REFERENCES anthropometry_profiles(id),

  -- Contexto de la sesión
  exercise text NOT NULL,
  capture_mode capture_mode NOT NULL,
  has_depth boolean NOT NULL DEFAULT false,
  fps int,
  model_version text,

  created_at timestamptz DEFAULT now()
);

-- Índices de uso común
CREATE INDEX idx_sessions_user
  ON sessions(user_id);

CREATE INDEX idx_sessions_created
  ON sessions(created_at);


/************************************************************
 * LANDMARKS
 * Puntos corporales capturados durante la sesión
 ************************************************************/

CREATE TABLE landmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Sesión a la que pertenecen
  session_id uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

  -- Sistema de referencia espacial
  coordinate_system coordinate_system NOT NULL,

  -- Datos crudos (keypoints, frames, confidence, etc.)
  data jsonb NOT NULL
);


/************************************************************
 * METRICS
 * Métricas biomecánicas derivadas de la sesión
 ************************************************************/

CREATE TABLE metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Sesión de origen
  session_id uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

  -- Tipo de métrica (ej: joint_angle, velocity, torque)
  metric_type text NOT NULL,

  -- Fase biomecánica asociada (opcional)
  phase biomech_phase,

  -- Valor numérico
  value float NOT NULL,

  -- Unidad física (deg, rad, m/s, Nm, etc.)
  unit text NOT NULL,

  -- Tiempo relativo dentro de la sesión (segundos)
  timestamp float
);

-- Índices para análisis
CREATE INDEX idx_metrics_session
  ON metrics(session_id);

CREATE INDEX idx_metrics_type
  ON metrics(metric_type);


/************************************************************
 * FUNCTIONS & TRIGGERS
 ************************************************************/

-- Helper: Get current user role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE
SET search_path = public, pg_catalog;

-- Trigger: Ensure single active anthropometry
CREATE OR REPLACE FUNCTION enforce_single_active_anthropometry()
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

CREATE TRIGGER trg_single_active_anthropometry
BEFORE INSERT OR UPDATE ON anthropometry_profiles
FOR EACH ROW
EXECUTE FUNCTION enforce_single_active_anthropometry();

-- Trigger: Guest session limits
CREATE OR REPLACE FUNCTION check_guest_session_limit()
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

CREATE TRIGGER trg_guest_session_limit
BEFORE INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION check_guest_session_limit();


/************************************************************
 * ROW LEVEL SECURITY (POLICIES)
 ************************************************************/

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE anthropometry_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE landmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "Admin can view all profiles" ON profiles FOR SELECT USING (get_user_role() = 'admin');

-- Anthropometry
CREATE POLICY "Users manage own anthropometry" ON anthropometry_profiles FOR ALL USING (
  user_id = auth.uid() OR get_user_role() = 'admin'
);

-- Relations
CREATE POLICY "Users can see their own relations" ON profile_relations FOR SELECT 
USING (coach_id = auth.uid() OR athlete_id = auth.uid() OR get_user_role() = 'admin');

-- Sessions (The Core Policy for shared access)
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

-- Landmarks (Indirect via Sessions)
CREATE POLICY "Users access landmarks via session ownership"
ON landmarks FOR ALL USING (
  EXISTS (
    SELECT 1 FROM sessions s 
    WHERE s.id = landmarks.session_id 
    AND (s.user_id = auth.uid() OR get_user_role() = 'admin' OR EXISTS (
      SELECT 1 FROM profile_relations pr 
      WHERE pr.coach_id = auth.uid() AND pr.athlete_id = s.user_id AND pr.status = 'active'
    ))
  )
);

-- Metrics (Indirect via Sessions)
CREATE POLICY "Users access metrics via session ownership"
ON metrics FOR ALL USING (
  EXISTS (
    SELECT 1 FROM sessions s 
    WHERE s.id = metrics.session_id 
    AND (s.user_id = auth.uid() OR get_user_role() = 'admin' OR EXISTS (
      SELECT 1 FROM profile_relations pr 
      WHERE pr.coach_id = auth.uid() AND pr.athlete_id = s.user_id AND pr.status = 'active'
    ))
  )
);
