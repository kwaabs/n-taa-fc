package service

import (
    "fmt"
    "strings"
)

// FormFieldSpec is the shape of a single auto-generated form field.
// Matches the JSON your form schema expects.
type FormFieldSpec struct {
    ID          string                 `json:"id"`
    Type        string                 `json:"type"`
    Label       map[string]string      `json:"label"`
    Description map[string]string      `json:"description,omitempty"`
    Required    bool                   `json:"required"`
    Meta        map[string]interface{} `json:"meta,omitempty"`
}

// FormFieldInput describes one source column we are turning into a field.
// Importer fills this in per column.
type FormFieldInput struct {
    ColumnName string // raw column name, e.g. "cv_paint_condition"
    DataType   string // PostgreSQL type name, e.g. "integer", "character varying"
    NotNull    bool   // true if source column is declared NOT NULL
    SourceRef  string // e.g. "dbo.dbo_distribution_transformer_dss_evw"
}

// systemColumnNames are column names we treat as system / non-collectable.
// Case-insensitive match.
var systemColumnNames = map[string]struct{}{
    // Universal system / sync columns
    "created_at":       {},
    "created_user":     {},
    "created_date":     {},
    "updated_at":       {},
    "updated_by":       {},
    "last_edited_at":   {},
    "last_edited_user": {},
    "last_edited_date": {},

    // ArcGIS / Esri / OGC identity columns (never collectible in FC forms)
    "device_id":         {},
    "objectid":         {},
    "object_id":        {},
    "globalid":         {},
    "global_id":        {},
    "ogc_fid":          {},
    "fid":              {},
    "shape_length":     {},
    "shape_area":       {},
    "geometry":         {},
    "geom":             {},
    "the_geom":         {},
    "unique_id_hidden": {},
}

// systemColumnPrefixes triggers system detection by prefix match.
// Anything starting with these strings is treated as system.
var systemColumnPrefixes = []string{
    "_",       // private fields
    "shape_",  // ArcGIS shape area / length / etc
    "geom_",   // PostGIS geometry helpers
}

// IsSystemColumn returns true if the column is identity/audit/geometry metadata
// and must not appear as a collectible field on linked-table forms.
func IsSystemColumn(name string) bool {
    lower := strings.ToLower(name)
    if _, ok := systemColumnNames[lower]; ok {
        return true
    }
    for _, prefix := range systemColumnPrefixes {
        if strings.HasPrefix(lower, prefix) {
            return true
        }
    }
    return false
}

// InferFieldType maps a PostgreSQL data type to one of our form field types.
// Choice list is NOT inferred here — that's an admin decision later.
func InferFieldType(pgType string) string {
    t := strings.ToLower(strings.TrimSpace(pgType))

    switch t {
    case "text", "character varying", "varchar", "char", "character":
        return "text"

    case "integer", "int", "int4", "smallint", "int2", "bigint", "int8":
        return "integer"

    case "numeric", "decimal", "real", "float4", "double precision", "float8":
        return "decimal"

    case "boolean", "bool":
        return "boolean"

    case "date":
        return "date"

    case "timestamp", "timestamp without time zone",
        "timestamptz", "timestamp with time zone":
        return "datetime"

    case "time", "time without time zone",
        "timetz", "time with time zone":
        return "time"

    case "uuid":
        return "text"

    case "json", "jsonb":
        return "text"

    default:
        // Safe fallback. Admin can override in the field editor later.
        return "text"
    }
}

// HumanizeLabel converts a column name into a human-friendly label.
// "cv_paint_condition" -> "Cv Paint Condition"
// "ogc_fid"            -> "Ogc Fid"
// "year_manufacture"   -> "Year Manufacture"
func HumanizeLabel(columnName string) string {
    parts := strings.Split(columnName, "_")
    for i, p := range parts {
        if p == "" {
            continue
        }
        runes := []rune(p)
        runes[0] = upperRune(runes[0])
        parts[i] = string(runes)
    }
    return strings.Join(parts, " ")
}

func upperRune(r rune) rune {
    if r >= 'a' && r <= 'z' {
        return r - ('a' - 'A')
    }
    return r
}

// BuildFormField turns a single column into a FormFieldSpec applying MS.1 rules:
//  1. Type inferred from column type.
//  2. Required defaults to NOT NULL, but system columns are never required.
//  3. Label is humanized column name.
//  4. Description includes source provenance.
//  5. System columns are flagged in meta.
func BuildFormField(in FormFieldInput) FormFieldSpec {
    system := IsSystemColumn(in.ColumnName)

    required := false
    if in.NotNull && !system {
        required = true
    }

    field := FormFieldSpec{
        ID:   in.ColumnName,
        Type: InferFieldType(in.DataType),
        Label: map[string]string{
            "en": HumanizeLabel(in.ColumnName),
        },
        Description: map[string]string{
            "en": fmt.Sprintf("Imported from %s.%s", in.SourceRef, in.ColumnName),
        },
        Required: required,
    }

    if system {
        field.Meta = map[string]interface{}{
            "system": true,
            "source": fmt.Sprintf("%s.%s", in.SourceRef, in.ColumnName),
        }
    } else {
        field.Meta = map[string]interface{}{
            "source": fmt.Sprintf("%s.%s", in.SourceRef, in.ColumnName),
        }
    }

    return field
}

// BuildFormFields is a convenience for batch generation from multiple columns.
func BuildFormFields(inputs []FormFieldInput) []FormFieldSpec {
    out := make([]FormFieldSpec, 0, len(inputs))
    for _, in := range inputs {
        out = append(out, BuildFormField(in))
    }
    return out
}