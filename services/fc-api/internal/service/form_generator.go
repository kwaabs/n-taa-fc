package service

import (
	"bytes"
	"encoding/json"
	"strings"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

// LinkedFormPhotoFieldID is appended to auto-generated linked-table forms so
// field users can attach photos. It is not a source-table column; write-back
// already skips attachment attribute values.
const LinkedFormPhotoFieldID = "fc_photos"

// GenerateForm builds a FormSchema from the columns of a discovered table.
func GenerateForm(table model.DiscoveredTable, includedColumns []string) (*model.FormSchema, error) {
	included := make(map[string]bool)
	for _, c := range includedColumns {
		included[c] = true
	}

	var fields []model.FormField

	for _, col := range table.Columns {
		// Skip geometry, PK, system identity/audit columns, and excluded columns
		if col.IsGeometry || col.IsPrimaryKey || IsSystemColumn(col.Name) {
			continue
		}
		if len(includedColumns) > 0 && !included[col.Name] {
			continue
		}

		field := model.FormField{
			ID:          strings.ToLower(col.Name),
			Label:       model.LocalizedString{"en": humanize(col.Name)},
			Description: model.LocalizedString{"en": "Imported from " + table.QualifiedName + "." + col.Name},
			Required:    !col.IsNullable,
		}

		// Type mapping
		if col.IsEnum {
			field.Type = model.FieldTypeSelectOne
			for _, v := range col.EnumValues {
				field.Choices = append(field.Choices, model.Choice{
					Value: v,
					Label: model.LocalizedString{"en": humanize(v)},
				})
			}
		} else {
			field.Type = postgresTypeToFieldType(col.DataType, col.UDTName)

			// Boolean columns: synthesize Yes/No choices so workers can actually answer.
			dt := strings.ToLower(col.DataType)
			if dt == "boolean" || dt == "bool" {
				field.Choices = []model.Choice{
					{Value: "true", Label: model.LocalizedString{"en": "Yes"}},
					{Value: "false", Label: model.LocalizedString{"en": "No"}},
				}
			}
		}

		fields = append(fields, field)
	}

	schema := &model.FormSchema{
		Fields: fields,
		Settings: &model.FormSettings{
			DefaultLanguage: "en",
			Languages:       []string{"en"},
		},
	}
	EnsureLinkedFormPhotoField(schema)
	return schema, nil
}

// EnsureLinkedFormPhotoField appends an optional multi-photo field when the
// schema has no photo field yet. Returns true if the schema was modified.
func EnsureLinkedFormPhotoField(schema *model.FormSchema) bool {
	if schema == nil {
		return false
	}
	for _, f := range schema.Fields {
		if f.Type == model.FieldTypePhoto || f.ID == LinkedFormPhotoFieldID {
			return false
		}
	}
	maxPhotos := 10
	schema.Fields = append(schema.Fields, model.FormField{
		ID:   LinkedFormPhotoFieldID,
		Type: model.FieldTypePhoto,
		Label: model.LocalizedString{"en": "Photos"},
		Description: model.LocalizedString{
			"en": "Optional field photos (stored in Field Collector; not written back to the source table).",
		},
		Appearance: "multi",
		Required:   false,
		Constraints: &model.FieldConstraints{
			MaxLength: &maxPhotos,
		},
	})
	return true
}

// SanitizeLinkedFormSchema removes system identity/audit fields and ensures the
// optional Photos field exists. Returns true if anything changed.
func SanitizeLinkedFormSchema(schema *model.FormSchema) bool {
	if schema == nil {
		return false
	}
	changed := false
	kept := make([]model.FormField, 0, len(schema.Fields))
	for _, f := range schema.Fields {
		if f.ID == LinkedFormPhotoFieldID || f.Type == model.FieldTypePhoto {
			kept = append(kept, f)
			continue
		}
		if IsSystemColumn(f.ID) {
			changed = true
			continue
		}
		kept = append(kept, f)
	}
	schema.Fields = kept
	if EnsureLinkedFormPhotoField(schema) {
		changed = true
	}
	return changed
}

func postgresTypeToFieldType(dataType, udtName string) model.FieldType {
    dt := strings.ToLower(dataType)
    switch dt {
    case "text", "varchar", "character varying", "character", "char", "citext":
        return model.FieldTypeText
    case "integer", "bigint", "smallint", "int", "int2", "int4", "int8":
        return model.FieldTypeInteger
    case "numeric", "decimal", "real", "double precision", "float", "float4", "float8":
        return model.FieldTypeDecimal
    case "boolean", "bool":
        return model.FieldTypeSelectOne
    case "date":
        return model.FieldTypeDate
    case "timestamp", "timestamp without time zone", "timestamp with time zone", "timestamptz":
        return model.FieldTypeDatetime
    case "time", "time without time zone", "time with time zone":
        return model.FieldTypeTime
    case "json", "jsonb":
        return model.FieldTypeText
    case "uuid":
        return model.FieldTypeText
    }
    return model.FieldTypeText
}

func humanize(s string) string {
    parts := strings.Split(s, "_")
    for i, p := range parts {
        if p == "" {
            continue
        }
        parts[i] = strings.ToUpper(p[:1]) + p[1:]
    }
    return strings.Join(parts, " ")
}

// SchemaToRaw is a helper to marshal a generated FormSchema for storage.
func SchemaToRaw(schema *model.FormSchema) (json.RawMessage, error) {
	return json.Marshal(schema)
}

// FormSchemaJSONEqual reports whether two form schema JSON blobs are equivalent.
func FormSchemaJSONEqual(a, b json.RawMessage) bool {
	var sa, sb model.FormSchema
	if err := json.Unmarshal(a, &sa); err != nil {
		return false
	}
	if err := json.Unmarshal(b, &sb); err != nil {
		return false
	}
	ba, err1 := json.Marshal(sa)
	bb, err2 := json.Marshal(sb)
	return err1 == nil && err2 == nil && bytes.Equal(ba, bb)
}