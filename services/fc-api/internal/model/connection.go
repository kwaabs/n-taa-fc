package model

import (
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

// ProjectConnection is a reusable database connection profile per project.
type ProjectConnection struct {
    bun.BaseModel `bun:"table:project_connections,alias:pc"`

    ID                uuid.UUID `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    ProjectID         uuid.UUID `bun:"project_id,type:uuid,notnull"              json:"project_id"`
    Name              string    `bun:"name,notnull"                               json:"name"`
    Driver            string    `bun:"driver,default:'postgres'"                  json:"driver"`
    Host              string    `bun:"host,notnull"                               json:"host"`
    Port              int       `bun:"port,default:5432"                          json:"port"`
    Database          string    `bun:"database,notnull"                           json:"database"`
    Username          string    `bun:"username,notnull"                           json:"username"`
    EncryptedPassword string    `bun:"encrypted_password"                         json:"-"`
    SSLMode           string    `bun:"ssl_mode,default:'disable'"                 json:"ssl_mode"`
    CreatedBy         uuid.UUID `bun:"created_by,type:uuid"                       json:"created_by"`
    CreatedAt         time.Time `bun:"created_at,nullzero,default:now()"          json:"created_at"`
    UpdatedAt         time.Time `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`
}

// DiscoveredTable is the metadata of one spatial or plain table the wizard found.
type DiscoveredTable struct {
    Schema          string             `json:"schema"`
    Name            string             `json:"name"`
    QualifiedName   string             `json:"qualified_name"`
    GeometryColumn  string             `json:"geometry_column,omitempty"`
    GeometryType    string             `json:"geometry_type,omitempty"`  // POINT, LINESTRING, POLYGON, etc.
    SRID            int                `json:"srid,omitempty"`
    IsSpatial       bool               `json:"is_spatial"`
    RowCount        int64              `json:"row_count"`
    Columns         []DiscoveredColumn `json:"columns"`
}

type DiscoveredColumn struct {
    Name         string   `json:"name"`
    DataType     string   `json:"data_type"`        // text, integer, numeric, etc.
    UDTName      string   `json:"udt_name,omitempty"` // for ENUMs
    IsPrimaryKey bool     `json:"is_primary_key"`
    IsNullable   bool     `json:"is_nullable"`
    IsEnum       bool     `json:"is_enum"`
    EnumValues   []string `json:"enum_values,omitempty"`
    IsGeometry   bool     `json:"is_geometry"`
}