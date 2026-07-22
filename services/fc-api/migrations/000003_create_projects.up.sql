CREATE TABLE projects (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT NOT NULL,
    description      TEXT,
    mode             VARCHAR(20) NOT NULL CHECK (mode IN ('map_based', 'form_collection')),
    config           JSONB NOT NULL DEFAULT '{}'::jsonb,
    area_of_interest GEOMETRY(Polygon, 4326),
    status           VARCHAR(20) DEFAULT 'draft',
    created_by       UUID REFERENCES user_profiles(id),
    version          INTEGER DEFAULT 1,
    created_at       TIMESTAMPTZ DEFAULT now(),
    updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_projects_status     ON projects(status);
CREATE INDEX idx_projects_created_by ON projects(created_by);

CREATE TABLE project_members (
    project_id    UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    role          VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'supervisor', 'field_worker')),
    assigned_area GEOMETRY(Polygon, 4326),
    is_active     BOOLEAN DEFAULT true,
    joined_at     TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

CREATE INDEX idx_project_members_user_id ON project_members(user_id);
CREATE INDEX idx_project_members_role    ON project_members(role);



DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_type typ 
        INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace 
        WHERE typ.typname = 'factor_type' 
          AND nsp.nspname = 'auth'
    ) THEN 
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
    END IF; 
END $$;
