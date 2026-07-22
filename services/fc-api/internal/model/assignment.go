package model

import (
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type Assignment struct {
    bun.BaseModel `bun:"table:assignments,alias:asg"`

    ID           uuid.UUID  `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    ProjectID    uuid.UUID  `bun:"project_id,type:uuid,notnull"              json:"project_id"`
    AssignedTo   *uuid.UUID `bun:"assigned_to,type:uuid"                     json:"assigned_to,omitempty"`
    TeamID       *uuid.UUID `bun:"team_id,type:uuid"                         json:"team_id,omitempty"`
    AssignedBy   uuid.UUID  `bun:"assigned_by,type:uuid,notnull"             json:"assigned_by"`
    FormID       *uuid.UUID `bun:"form_id,type:uuid"                         json:"form_id,omitempty"`
    LayerID      *uuid.UUID `bun:"layer_id,type:uuid"                        json:"layer_id,omitempty"`
    Area         *string    `bun:"area,type:geometry(Polygon,4326)"          json:"area,omitempty"`
    Title        string     `bun:"title"                                     json:"title,omitempty"`
    TargetCount  int        `bun:"target_count"                               json:"target_count,omitempty"`
    Instructions string     `bun:"instructions"                               json:"instructions,omitempty"`
    Priority     string     `bun:"priority,default:'medium'"                  json:"priority"`
    DueDate      *time.Time `bun:"due_date"                                   json:"due_date,omitempty"`
    Status       string     `bun:"status,default:'pending'"                   json:"status"`
    CreatedAt    time.Time  `bun:"created_at,nullzero,default:now()"          json:"created_at"`

    // Relations
    Team       *Team        `bun:"rel:belongs-to,join:team_id=id"     json:"team,omitempty"`
    Assignee   *UserProfile `bun:"rel:belongs-to,join:assigned_to=id" json:"assignee,omitempty"`
    Form       *Form        `bun:"rel:belongs-to,join:form_id=id"     json:"form,omitempty"`
    Layer      *Layer       `bun:"rel:belongs-to,join:layer_id=id"    json:"layer,omitempty"`
}

// ComputedStatus returns the effective status, accounting for due date.
func (a *Assignment) ComputedStatus() string {
    if a.Status == "completed" {
        return "completed"
    }
    if a.DueDate != nil && a.DueDate.Before(time.Now()) {
        return "overdue"
    }
    return a.Status
}

// AssignmentProgress represents collection progress for an assignment.
type AssignmentProgress struct {
    AssignmentID    uuid.UUID         `json:"assignment_id"`
    Target          int               `json:"target"`
    Submitted       int               `json:"submitted"`
    Approved        int               `json:"approved"`
    Rejected        int               `json:"rejected"`
    UnderReview     int               `json:"under_review"`
    Flagged         int               `json:"flagged"`
    CompletionPct   float64           `json:"completion_pct"`
    ByWorker        []WorkerProgress  `json:"by_worker"`
    LastActivityAt  *time.Time        `json:"last_activity_at,omitempty"`
    IsOverdue       bool              `json:"is_overdue"`
    ComputedStatus  string            `json:"computed_status"`
}

type WorkerProgress struct {
    UserID    uuid.UUID `json:"user_id"`
    Email     string    `json:"email"`
    FullName  string    `json:"full_name,omitempty"`
    Submitted int       `json:"submitted"`
    Approved  int       `json:"approved"`
    Rejected  int       `json:"rejected"`
}