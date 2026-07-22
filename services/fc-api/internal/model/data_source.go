package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type LayerDataSource struct {
	bun.BaseModel `bun:"table:layer_data_sources,alias:lds"`

	ID                   uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	LayerID              uuid.UUID       `bun:"layer_id,type:uuid,notnull"                json:"layer_id"`
	Name                 string          `bun:"name,notnull"                               json:"name"`
	SourceType           string          `bun:"source_type,notnull"                        json:"source_type"` // file, url, database
	Config               json.RawMessage `bun:"config,type:jsonb,default:'{}'::jsonb"      json:"config"`
	EncryptedCredentials string          `bun:"encrypted_credentials"                      json:"-"`
	AutoRefreshMinutes   int             `bun:"auto_refresh_minutes,default:0"             json:"auto_refresh_minutes"`
	LastSyncedAt         *time.Time      `bun:"last_synced_at"                             json:"last_synced_at,omitempty"`
	LastSyncStatus       string          `bun:"last_sync_status"                           json:"last_sync_status,omitempty"`
	LastSyncError        string          `bun:"last_sync_error"                            json:"last_sync_error,omitempty"`
	LastSyncStats        json.RawMessage `bun:"last_sync_stats,type:jsonb"                 json:"last_sync_stats,omitempty"`
	DeleteStrategy       string          `bun:"delete_strategy,default:'hard'" json:"delete_strategy"`
	SoftDeleteColumn     string          `bun:"soft_delete_column"             json:"soft_delete_column,omitempty"`
	SoftDeleteValue      string          `bun:"soft_delete_value"              json:"soft_delete_value,omitempty"`
	CreatedBy            uuid.UUID       `bun:"created_by,type:uuid"                       json:"created_by"`
	CreatedAt            time.Time       `bun:"created_at,nullzero,default:now()"          json:"created_at"`
	UpdatedAt            time.Time       `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`
}

// SyncStats holds counts from a sync run.
type SyncStats struct {
	Total     int `json:"total"`
	Inserted  int `json:"inserted"`
	Updated   int `json:"updated"`
	Deleted   int `json:"deleted"`
	Unchanged int `json:"unchanged"`
	Errors    int `json:"errors"`
}

// FileConfig is the config for source_type='file'.
type FileConfig struct {
	Format       string `json:"format"`       // geojson, csv
	StoragePath  string `json:"storage_path"` // RustFS path
	OriginalName string `json:"original_name"`
}

// URLConfig is the config for source_type='url'.
type URLConfig struct {
	URL    string `json:"url"`
	Format string `json:"format"` // geojson
}

// DatabaseConfig is the config for source_type='database'.
type DatabaseConfig struct {
	Driver    string `json:"driver"` // postgres
	Host      string `json:"host"`
	Port      int    `json:"port"`
	Database  string `json:"database"`
	Query     string `json:"query"` // SELECT ... (validated read-only)
	LatColumn string `json:"lat_column"`
	LngColumn string `json:"lng_column"`
	IDColumn  string `json:"id_column"`

	// ── D2.0: structured fields needed for reconciliation ──
	Schema       string     `json:"schema,omitempty"`        // e.g. "dbo", "public"
	Table        string     `json:"table,omitempty"`         // e.g. "dbo_arrester_evw"
	ConnectionID *uuid.UUID `json:"connection_id,omitempty"` // links to project_connections; nil if inline import

    
    // 👇 D2.4 geometry-ready
    GeometryColumn string `json:"geometry_column,omitempty"`
    GeometrySRID   int    `json:"geometry_srid,omitempty"` // typically 4326


}

// LayerChangeSummary represents the change tracking summary for a layer.
type LayerChangeSummary struct {
	LayerID        uuid.UUID `json:"layer_id"`
	TotalFeatures  int       `json:"total_features"`
	ReferenceCount int       `json:"reference_count"`
	CollectedCount int       `json:"collected_count"`
	UpdatedCount   int       `json:"updated_count"`
	DeletedCount   int       `json:"deleted_count"`
	UnchangedCount int       `json:"unchanged_count"`
	NewCount       int       `json:"new_count"`
}

// DatabaseConfigParsed unmarshals the Config JSON into a typed DatabaseConfig.
// Returns nil if the source is not 'database' type or config is invalid.
func (ds *LayerDataSource) DatabaseConfigParsed() *DatabaseConfig {
	if ds.SourceType != "database" {
		return nil
	}
	var cfg DatabaseConfig
	if err := json.Unmarshal(ds.Config, &cfg); err != nil {
		return nil
	}
	return &cfg
}

// SchemaName returns the source DB schema (e.g. "dbo"). Empty if unknown.
func (ds *LayerDataSource) SchemaName() string {
	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return ""
	}
	return cfg.Schema
}

// TableName returns the source DB table name. Empty if unknown.
func (ds *LayerDataSource) TableName() string {
	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return ""
	}
	return cfg.Table
}

// ConnectionID returns the linked project_connections id, or nil if inline import.
func (ds *LayerDataSource) ConnectionID() *uuid.UUID {
	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return nil
	}
	return cfg.ConnectionID
}

// IDColumn returns the primary-key column name in the source. Empty if unknown.
func (ds *LayerDataSource) IDColumn() string {
	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return ""
	}
	return cfg.IDColumn
}


// GeometryColumn returns the source DB's geometry column name (e.g. "the_geom").
// Empty if the data source has no geometry column (rare — only lat/lng pairs).
func (ds *LayerDataSource) GeometryColumn() string {
    cfg := ds.DatabaseConfigParsed()
    if cfg == nil {
        return ""
    }
    return cfg.GeometryColumn
}

// GeometrySRID returns the SRID for the geometry column. Defaults to 4326 if unset.
func (ds *LayerDataSource) GeometrySRID() int {
    cfg := ds.DatabaseConfigParsed()
    if cfg == nil || cfg.GeometrySRID == 0 {
        return 4326
    }
    return cfg.GeometrySRID
}