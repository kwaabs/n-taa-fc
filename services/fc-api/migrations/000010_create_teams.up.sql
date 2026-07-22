-- Teams
CREATE TABLE teams (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    description TEXT,
    created_by  UUID REFERENCES user_profiles(id),
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_teams_created_by ON teams(created_by);

-- Team members
CREATE TABLE team_members (
    team_id   UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    role      VARCHAR(20) DEFAULT 'member' CHECK (role IN ('leader', 'member')),
    joined_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (team_id, user_id)
);

CREATE INDEX idx_team_members_user_id ON team_members(user_id);

-- Project-team assignments
CREATE TABLE project_teams (
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    team_id     UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    role        VARCHAR(20) NOT NULL DEFAULT 'field_worker' CHECK (role IN ('supervisor', 'field_worker')),
    assigned_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (project_id, team_id)
);

CREATE INDEX idx_project_teams_team_id    ON project_teams(team_id);
CREATE INDEX idx_project_teams_project_id ON project_teams(project_id);