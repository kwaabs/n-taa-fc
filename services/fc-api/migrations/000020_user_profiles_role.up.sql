-- Add fixed global role on user_profiles (was only in ad-hoc SQL in parent FC).
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'field_worker';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_profiles_role_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_role_check
      CHECK (role IN ('field_worker', 'supervisor', 'admin'));
  END IF;
END $$;
