package model

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

// BundleCache represents a generated and cached project bundle.
type BundleCache struct {
    bun.BaseModel `bun:"table:bundle_cache,alias:bc"`

    ID                   uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    ProjectID            uuid.UUID       `bun:"project_id,type:uuid,notnull"               json:"project_id"`
    UserID               uuid.UUID       `bun:"user_id,type:uuid,notnull"                  json:"user_id"`
    IncludeReferenceData bool            `bun:"include_reference_data,notnull"             json:"include_reference_data"`
    ContentHash          string          `bun:"content_hash,notnull"                       json:"content_hash"`
    StorageKey           string          `bun:"storage_key,notnull"                        json:"storage_key"`
    Filename             string          `bun:"filename,notnull"                           json:"filename"`
    SizeBytes            int64           `bun:"size_bytes,notnull,default:0"               json:"size_bytes"`
    Counts               json.RawMessage `bun:"counts,type:jsonb,default:'{}'::jsonb"      json:"counts"`
    Warnings             json.RawMessage `bun:"warnings,type:jsonb"                        json:"warnings,omitempty"`
    GeneratedAt          time.Time       `bun:"generated_at,nullzero,default:now()"        json:"generated_at"`
    AccessedAt           time.Time       `bun:"accessed_at,nullzero,default:now()"         json:"accessed_at"`
}

// BundleManifest is the contents of manifest.json inside the zip.
type BundleManifest struct {
    BundleVersion        string       `json:"bundle_version"`
    ProjectID            uuid.UUID    `json:"project_id"`
    ProjectName          string       `json:"project_name"`
    GeneratedAt          time.Time    `json:"generated_at"`
    GeneratedBy          uuid.UUID    `json:"generated_by"`
    IncludeReferenceData bool         `json:"include_reference_data"`
    HasAOI               bool         `json:"has_aoi"`
    ContentHash          string       `json:"content_hash"`
    BundleHash           string       `json:"bundle_hash"`
    Counts               BundleCounts `json:"counts"`
    Warnings             []string     `json:"warnings,omitempty"`
}

// BundleCounts gives quick summary numbers.
type BundleCounts struct {
    Forms             int `json:"forms"`
    Layers            int `json:"layers"`
    ChoiceLists       int `json:"choice_lists"`
    Assignments       int `json:"assignments"`
    ReferenceFeatures int `json:"reference_features"`
}

// BundleJobResult is the structured payload stored in import_jobs.result for bundle jobs.
type BundleJobResult struct {
    CacheID     uuid.UUID    `json:"cache_id"`
    ContentHash string       `json:"content_hash"`
    StorageKey  string       `json:"storage_key"`
    Filename    string       `json:"filename"`
    SizeBytes   int64        `json:"size_bytes"`
    Counts      BundleCounts `json:"counts"`
    Warnings    []string     `json:"warnings,omitempty"`
}

// BundleJobProgress is what we store in import_jobs.progress for bundle jobs.
type BundleJobProgress struct {
    Step    string `json:"step"`     // gathering, hashing, writing_forms, ...
    Percent int    `json:"percent"`  // 0-100
    Message string `json:"message,omitempty"`
}