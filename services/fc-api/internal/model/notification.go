package model

import (
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

const (
	NotificationKindAssignmentCreated    = "assignment_created"
	NotificationKindAssignmentReassigned = "assignment_reassigned"
	NotificationKindMessage              = "message"
)

type Notification struct {
	bun.BaseModel `bun:"table:notifications,alias:n"`

	ID           uuid.UUID  `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	UserID       uuid.UUID  `bun:"user_id,type:uuid,notnull"                 json:"user_id"`
	ProjectID    uuid.UUID  `bun:"project_id,type:uuid,notnull"              json:"project_id"`
	AssignmentID *uuid.UUID `bun:"assignment_id,type:uuid"                   json:"assignment_id,omitempty"`
	Kind         string     `bun:"kind,notnull"                              json:"kind"`
	Title        string     `bun:"title,notnull"                             json:"title"`
	Body         string     `bun:"body"                                      json:"body,omitempty"`
	ReadAt       *time.Time `bun:"read_at"                                   json:"read_at,omitempty"`
	CreatedAt    time.Time  `bun:"created_at,nullzero,default:now()"         json:"created_at"`
}
