-- Migration to update schema to Profiles and Anthropometry Profiles
-- Date: 2026-02-24

-- 1. Rename 'users' to 'profiles'
ALTER TABLE users RENAME TO profiles;

-- 2. Create anthropometry_profiles table
CREATE TABLE anthropometry_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    height_cm NUMERIC,
    weight_kg NUMERIC,
    segment_lengths JSONB DEFAULT '{}'::jsonb,
    model model_type_enum NOT NULL DEFAULT 'generic',
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    valid_to TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- 3. Update sessions table
-- First, add the new foreign key column
ALTER TABLE sessions ADD COLUMN anthropometry_profile_id UUID REFERENCES anthropometry_profiles(id);

-- Note: We keep user_id in sessions as well for direct ownership queries
-- 4. Drop the legacy anthropometry table
DROP TABLE IF EXISTS anthropometry;

-- Update comments for clarity
COMMENT ON TABLE profiles IS 'User profiles linked to Supabase Auth';
COMMENT ON TABLE anthropometry_profiles IS 'Historical and active biometric data for users';
