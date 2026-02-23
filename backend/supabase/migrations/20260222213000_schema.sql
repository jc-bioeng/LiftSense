-- Initial Schema Prototype for LiftSense
-- PostgreSQL + Supabase Authentication
-- This is a mutable prototype and will likely change.

-- Users table
-- Note: In Supabase, you typically link this to auth.users.
-- E.g., id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
CREATE TYPE user_role AS ENUM ('user', 'trainer', 'researcher');

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    role user_role NOT NULL DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Sessions table
CREATE TYPE capture_mode_enum AS ENUM ('camera', 'upload', 'lab');

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise TEXT NOT NULL, -- e.g., 'back_squat'
    capture_mode capture_mode_enum NOT NULL,
    has_depth BOOLEAN NOT NULL DEFAULT FALSE,
    fps INTEGER,
    model_version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- Anthropometry table
CREATE TYPE model_type_enum AS ENUM ('generic', 'estimated', 'personalized');

CREATE TABLE anthropometry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    height_cm NUMERIC,
    weight_kg NUMERIC,
    segment_lengths JSONB DEFAULT '{}'::jsonb,
    model model_type_enum NOT NULL DEFAULT 'generic'
);

-- Landmarks table
CREATE TYPE coordinate_system_enum AS ENUM ('image', 'world');

CREATE TABLE landmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    coordinate_system coordinate_system_enum NOT NULL,
    data JSONB NOT NULL -- MediaPipe landmarks per frame
);

-- Metrics table
CREATE TYPE phase_enum AS ENUM ('eccentric', 'bottom', 'concentric');

CREATE TABLE metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    metric_type TEXT NOT NULL, -- e.g., knee_angle, hip_angle, trunk_inclination
    phase phase_enum,
    value NUMERIC NOT NULL,
    unit TEXT,
    timestamp NUMERIC -- Time or frame index
);

-- Experiments table (lab validation)
CREATE TABLE experiments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    variable TEXT NOT NULL, -- e.g., GRF_vertical, knee_moment
    reference_data JSONB NOT NULL, -- array of reference values
    estimated_data JSONB NOT NULL, -- array of estimated values
    validation_metrics JSONB -- e.g., RMSE, r, %error
);
