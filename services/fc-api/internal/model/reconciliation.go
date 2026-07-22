package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

// ReconciliationJob represents one "reconcile this layer" run.
// Lifecycle: pending → running → success | partial | failed | cancelled
type ReconciliationJob struct {
	bun.BaseModel `bun:"table:reconciliation_jobs,alias:rj"`

	ID           uuid.UUID `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	ProjectID    uuid.UUID `bun:"project_id,type:uuid"                       json:"project_id"`
	LayerID      uuid.UUID `bun:"layer_id,type:uuid"                         json:"layer_id"`
	DataSourceID uuid.UUID `bun:"data_source_id,type:uuid"                   json:"data_source_id"`

	Mode      string `bun:"mode,default:'preview'"   json:"mode"`   // 'preview' | 'apply'
	Status    string `bun:"status,default:'pending'" json:"status"` // pending|running|success|partial|failed|cancelled
	BatchSize int    `bun:"batch_size,default:500"   json:"batch_size"`

	ChangesTotal      int `bun:"changes_total,default:0"      json:"changes_total"`
	InsertsAttempted  int `bun:"inserts_attempted,default:0"  json:"inserts_attempted"`
	InsertsSucceeded  int `bun:"inserts_succeeded,default:0"  json:"inserts_succeeded"`
	UpdatesAttempted  int `bun:"updates_attempted,default:0"  json:"updates_attempted"`
	UpdatesSucceeded  int `bun:"updates_succeeded,default:0"  json:"updates_succeeded"`
	DeletesAttempted  int `bun:"deletes_attempted,default:0"  json:"deletes_attempted"`
	DeletesSucceeded  int `bun:"deletes_succeeded,default:0"  json:"deletes_succeeded"`
	ConflictsDetected int `bun:"conflicts_detected,default:0" json:"conflicts_detected"`
	Errors            int `bun:"errors,default:0"             json:"errors"`

	Progress     json.RawMessage `bun:"progress,type:jsonb,default:'{}'::jsonb" json:"progress"`
	Result       json.RawMessage `bun:"result,type:jsonb"                       json:"result,omitempty"`
	ErrorMessage string          `bun:"error_message"                           json:"error_message,omitempty"`

	CreatedBy  *uuid.UUID `bun:"created_by,type:uuid"              json:"created_by,omitempty"`
	StartedAt  *time.Time `bun:"started_at"                        json:"started_at,omitempty"`
	FinishedAt *time.Time `bun:"finished_at"                       json:"finished_at,omitempty"`
	CreatedAt  time.Time  `bun:"created_at,nullzero,default:now()" json:"created_at"`
	UpdatedAt  time.Time  `bun:"updated_at,nullzero,default:now()" json:"updated_at"`
}

// ReconciliationConflict is one feature whose source-side row differs from our
// captured `original_attributes` snapshot. Admin resolves these on a dedicated
// page; resolutions feed the next reconciliation run.
type ReconciliationConflict struct {
	bun.BaseModel `bun:"table:reconciliation_conflicts,alias:rc"`

	ID           uuid.UUID `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	JobID        uuid.UUID `bun:"job_id,type:uuid"                          json:"job_id"`
	FeatureID    uuid.UUID `bun:"feature_id,type:uuid"                      json:"feature_id"`
	LayerID      uuid.UUID `bun:"layer_id,type:uuid"                        json:"layer_id"`
	DataSourceID uuid.UUID `bun:"data_source_id,type:uuid"                  json:"data_source_id"`

	SourceRef  string `bun:"source_ref"  json:"source_ref"`
	ChangeType string `bun:"change_type" json:"change_type"`

	OriginalAttrs     json.RawMessage `bun:"original_attrs,type:jsonb"    json:"original_attrs,omitempty"`
	FieldAttrs        json.RawMessage `bun:"field_attrs,type:jsonb"       json:"field_attrs,omitempty"`
	SourceAttrs       json.RawMessage `bun:"source_attrs,type:jsonb"      json:"source_attrs,omitempty"`
	ConflictingFields []string        `bun:"conflicting_fields,array"     json:"conflicting_fields"`

	Status        string          `bun:"status,default:'pending'" json:"status"` // pending | resolved | dismissed
	Resolution    *string         `bun:"resolution,nullzero" json:"resolution,omitempty"`
	ResolvedAttrs json.RawMessage `bun:"resolved_attrs,type:jsonb" json:"resolved_attrs,omitempty"`
	ResolvedBy    *uuid.UUID      `bun:"resolved_by,type:uuid"    json:"resolved_by,omitempty"`
	ResolvedAt    *time.Time      `bun:"resolved_at"              json:"resolved_at,omitempty"`
	Notes         string          `bun:"notes"                    json:"notes,omitempty"`

	CreatedAt time.Time `bun:"created_at,nullzero,default:now()" json:"created_at"`
}

// ReconciliationLogEntry is the long-term audit of every applied reconciliation
// outcome. Survives deletion of features/jobs (feature_id and job_id are not FKs).
type ReconciliationLogEntry struct {
	bun.BaseModel `bun:"table:reconciliation_log,alias:rl"`

	ID           uuid.UUID  `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	JobID        *uuid.UUID `bun:"job_id,type:uuid"                          json:"job_id,omitempty"`
	FeatureID    *uuid.UUID `bun:"feature_id,type:uuid"                      json:"feature_id,omitempty"`
	LayerID      *uuid.UUID `bun:"layer_id,type:uuid"                        json:"layer_id,omitempty"`
	DataSourceID *uuid.UUID `bun:"data_source_id,type:uuid"                  json:"data_source_id,omitempty"`
	SourceRef    string     `bun:"source_ref"                                json:"source_ref,omitempty"`

	ChangeType string `bun:"change_type" json:"change_type"` // inserted | updated | deleted
	Outcome    string `bun:"outcome"     json:"outcome"`     // applied | conflict | failed | skipped

	AttemptedPayload json.RawMessage `bun:"attempted_payload,type:jsonb" json:"attempted_payload,omitempty"`
	FailureReason    string          `bun:"failure_reason"               json:"failure_reason,omitempty"`

	AppliedBy *uuid.UUID `bun:"applied_by,type:uuid"              json:"applied_by,omitempty"`
	AppliedAt time.Time  `bun:"applied_at,nullzero,default:now()" json:"applied_at"`
}
