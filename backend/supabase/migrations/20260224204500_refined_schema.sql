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

-- Clean up previous versions if they exist (safe for prototyping)
DROP TRIGGER IF EXISTS trg_single_active_anthropometry ON anthropometry_profiles;
DROP FUNCTION IF EXISTS enforce_single_active_anthropometry;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS metrics CASCADE;
DROP TABLE IF EXISTS landmarks CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS anthropometry_profiles CASCADE;
DROP TABLE IF EXISTS anthropometry CASCADE; -- Legacy
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE; -- Legacy

DROP TYPE IF EXISTS anthropometry_model CASCADE;
DROP TYPE IF EXISTS biomech_phase CASCADE;
DROP TYPE IF EXISTS coordinate_system CASCADE;
DROP TYPE IF EXISTS capture_mode CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS capture_mode_enum CASCADE; -- Legacy
DROP TYPE IF EXISTS model_type_enum CASCADE;   -- Legacy
DROP TYPE IF EXISTS coordinate_system_enum CASCADE; -- Legacy
DROP TYPE IF EXISTS phase_enum CASCADE; -- Legacy

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
 * TRIGGER
 * Garantiza un solo perfil antropométrico activo por usuario
 ************************************************************/

CREATE OR REPLACE FUNCTION enforce_single_active_anthropometry()
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_single_active_anthropometry
BEFORE INSERT OR UPDATE ON anthropometry_profiles
FOR EACH ROW
EXECUTE FUNCTION enforce_single_active_anthropometry();


/************************************************************
 * ROW LEVEL SECURITY (BASE)
 * Se afinan luego por rol
 ************************************************************/

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE anthropometry_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE landmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;


/************************************************************
 * POLÍTICA BASE DE EJEMPLO (SESSIONS)
 * Cada usuario solo accede a sus datos
 ************************************************************/

CREATE POLICY "Users can manage own sessions"
ON sessions
FOR ALL
USING (user_id = auth.uid());

CREATE POLICY "Users can manage own profiles"
ON profiles
FOR ALL
USING (id = auth.uid());

CREATE POLICY "Users can manage own anthropometry"
ON anthropometry_profiles
FOR ALL
USING (user_id = auth.uid());

CREATE POLICY "Users can manage landmarks of own sessions"
ON landmarks
FOR ALL
USING (EXISTS (
  SELECT 1 FROM sessions s 
  WHERE s.id = landmarks.session_id AND s.user_id = auth.uid()
));

CREATE POLICY "Users can manage metrics of own sessions"
ON metrics
FOR ALL
USING (EXISTS (
  SELECT 1 FROM sessions s 
  WHERE s.id = metrics.session_id AND s.user_id = auth.uid()
));
