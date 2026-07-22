package model

import (
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type Team struct {
    bun.BaseModel `bun:"table:teams,alias:t"`

    ID          uuid.UUID `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    Name        string    `bun:"name,notnull"                               json:"name"`
    Description string    `bun:"description"                                json:"description,omitempty"`
    CreatedBy   uuid.UUID `bun:"created_by,type:uuid"                      json:"created_by"`
    CreatedAt   time.Time `bun:"created_at,nullzero,default:now()"          json:"created_at"`
    UpdatedAt   time.Time `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`

    // Relations
    Members []TeamMember `bun:"rel:has-many,join:id=team_id" json:"members,omitempty"`
}

type TeamMember struct {
    bun.BaseModel `bun:"table:team_members,alias:tm"`

    TeamID   uuid.UUID `bun:"team_id,pk,type:uuid"               json:"team_id"`
    UserID   uuid.UUID `bun:"user_id,pk,type:uuid"               json:"user_id"`
    Role     string    `bun:"role,default:'member'"               json:"role"`
    JoinedAt time.Time `bun:"joined_at,nullzero,default:now()"    json:"joined_at"`

    // Relations
    User *UserProfile `bun:"rel:belongs-to,join:user_id=id" json:"user,omitempty"`
    Team *Team        `bun:"rel:belongs-to,join:team_id=id" json:"team,omitempty"`
}

type ProjectTeam struct {
    bun.BaseModel `bun:"table:project_teams,alias:pt"`

    ProjectID  uuid.UUID `bun:"project_id,pk,type:uuid"             json:"project_id"`
    TeamID     uuid.UUID `bun:"team_id,pk,type:uuid"                json:"team_id"`
    Role       string    `bun:"role,notnull,default:'field_worker'"  json:"role"`
    AssignedAt time.Time `bun:"assigned_at,nullzero,default:now()"   json:"assigned_at"`

    // Relations
    Team    *Team    `bun:"rel:belongs-to,join:team_id=id"    json:"team,omitempty"`
    Project *Project `bun:"rel:belongs-to,join:project_id=id" json:"project,omitempty"`
}