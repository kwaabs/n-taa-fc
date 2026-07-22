package model

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

// ImportJob tracks a long-running import operation.
type ImportJob struct {
    bun.BaseModel `bun:"table:import_jobs,alias:ij"`

    ID            uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    ProjectID     uuid.UUID       `bun:"project_id,type:uuid,notnull"              json:"project_id"`
    ConnectionID  *uuid.UUID      `bun:"connection_id,type:uuid"                    json:"connection_id,omitempty"`
    JobType       string          `bun:"job_type,notnull"                           json:"job_type"`
    Status        string          `bun:"status,default:'pending'"                   json:"status"`
    Config        json.RawMessage `bun:"config,type:jsonb,default:'{}'::jsonb"      json:"config"`
    Progress      json.RawMessage `bun:"progress,type:jsonb,default:'{}'::jsonb"    json:"progress"`
    Result        json.RawMessage `bun:"result,type:jsonb"                          json:"result,omitempty"`
    ErrorMessage  string          `bun:"error_message"                              json:"error_message,omitempty"`
    CreatedBy     uuid.UUID       `bun:"created_by,type:uuid"                       json:"created_by"`
    StartedAt     *time.Time      `bun:"started_at"                                 json:"started_at,omitempty"`
    FinishedAt    *time.Time      `bun:"finished_at"                                json:"finished_at,omitempty"`
    CreatedAt     time.Time       `bun:"created_at,nullzero,default:now()"          json:"created_at"`
    UpdatedAt     time.Time       `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`
}

// ImportJobProgress is the structured payload we store in `progress`.
type ImportJobProgress struct {
    Current       int                       `json:"current"`
    Total         int                       `json:"total"`
    Message       string                    `json:"message,omitempty"`
    PerTable      map[string]TableProgress  `json:"per_table,omitempty"`
}

type TableProgress struct {
    Status         string `json:"status"`         // pending, running, success, failed, skipped
    Inserted       int    `json:"inserted"`
    Total          int    `json:"total"`
    LayerID        string `json:"layer_id,omitempty"`
    FormID         string `json:"form_id,omitempty"`
    DataSourceID   string `json:"data_source_id,omitempty"`
    ErrorMessage   string `json:"error,omitempty"`
}

// ImportJobResult is what we store in `result` on completion.
type ImportJobResult struct {
    LayersCreated    int                       `json:"layers_created"`
    FormsCreated     int                       `json:"forms_created"`
    FeaturesImported int                       `json:"features_imported"`
    TableResults     map[string]TableProgress  `json:"table_results"`
    Errors           []string                  `json:"errors,omitempty"`
}

// BulkImportConfig describes what to import. Stored in the job's config field.
type BulkImportConfig struct {
	ConnectionRef BulkImportConnectionRef `json:"connection"`
	// ImportMode: "copy" (default) materializes rows into public.features;
	// "link" registers the table only (source_type=linked_table, no row copy).
	ImportMode string                 `json:"import_mode,omitempty"`
	Tables     []BulkImportTableConfig `json:"tables"`
}

type BulkImportConnectionRef struct {
    // One of:
    ConnectionID *uuid.UUID                 `json:"connection_id,omitempty"`
    Inline       *BulkImportInlineConnection `json:"inline,omitempty"`
}

type BulkImportInlineConnection struct {
    Host     string `json:"host"`
    Port     int    `json:"port"`
    Database string `json:"database"`
    Username string `json:"username"`
    Password string `json:"password"`
    SSLMode  string `json:"ssl_mode"`
}

type BulkImportTableConfig struct {
    Schema           string   `json:"schema"`
    Name             string   `json:"name"`
    LayerName        string   `json:"layer_name"`
    GeometryType     string   `json:"geometry_type"`    // point, line, polygon (lowercase, our convention)
    GeometryColumn   string   `json:"geometry_column,omitempty"`
    LatColumn        string   `json:"lat_column,omitempty"` // if no geometry column
    LngColumn        string   `json:"lng_column,omitempty"`
    IDColumn         string   `json:"id_column"`
    Editable         bool     `json:"editable"`
    IncludedColumns  []string `json:"included_columns"`  // attributes to ingest
    ExcludedColumns  []string `json:"excluded_columns"`  // PII (informational)
    FilterClause     string   `json:"filter_clause,omitempty"` // optional WHERE
    GenerateForm     bool     `json:"generate_form"`
    ScheduleMinutes  int      `json:"schedule_minutes"`  // 0 = manual only
}