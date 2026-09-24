package service

import (
	"testing"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

func TestEnsureLinkedFormPhotoField(t *testing.T) {
	schema := &model.FormSchema{
		Fields: []model.FormField{
			{ID: "name", Type: model.FieldTypeText, Label: model.LocalizedString{"en": "Name"}},
		},
	}
	if !EnsureLinkedFormPhotoField(schema) {
		t.Fatal("expected photo field to be appended")
	}
	if len(schema.Fields) != 2 {
		t.Fatalf("got %d fields, want 2", len(schema.Fields))
	}
	photo := schema.Fields[1]
	if photo.ID != LinkedFormPhotoFieldID || photo.Type != model.FieldTypePhoto {
		t.Fatalf("unexpected photo field: %+v", photo)
	}
	if EnsureLinkedFormPhotoField(schema) {
		t.Fatal("second call should be a no-op")
	}
}

func TestSanitizeLinkedFormSchema(t *testing.T) {
	schema := &model.FormSchema{
		Fields: []model.FormField{
			{ID: "ogc_fid", Type: model.FieldTypeInteger},
			{ID: "object_id", Type: model.FieldTypeInteger},
			{ID: "global_id", Type: model.FieldTypeText},
			{ID: "name", Type: model.FieldTypeText},
		},
	}
	if !SanitizeLinkedFormSchema(schema) {
		t.Fatal("expected sanitize to modify schema")
	}
	ids := map[string]bool{}
	for _, f := range schema.Fields {
		ids[f.ID] = true
	}
	if ids["ogc_fid"] || ids["object_id"] || ids["global_id"] {
		t.Fatalf("system fields still present: %+v", schema.Fields)
	}
	if !ids["name"] || !ids[LinkedFormPhotoFieldID] {
		t.Fatalf("expected name + photos, got %+v", schema.Fields)
	}
	if SanitizeLinkedFormSchema(schema) {
		t.Fatal("second sanitize should be a no-op")
	}
}

func TestGenerateFormIncludesPhoto(t *testing.T) {
	schema, err := GenerateForm(model.DiscoveredTable{
		QualifiedName: "dbo.poles",
		Columns: []model.DiscoveredColumn{
			{Name: "id", IsPrimaryKey: true, DataType: "uuid"},
			{Name: "ogc_fid", DataType: "integer", IsNullable: false},
			{Name: "objectid", DataType: "integer", IsNullable: false},
			{Name: "globalid", DataType: "uuid", IsNullable: true},
			{Name: "name", DataType: "text", IsNullable: true},
			{Name: "geom", IsGeometry: true, DataType: "geometry"},
		},
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	ids := map[string]bool{}
	for _, f := range schema.Fields {
		ids[f.ID] = true
	}
	for _, bad := range []string{"ogc_fid", "objectid", "globalid", "id", "geom"} {
		if ids[bad] {
			t.Fatalf("unexpected field %q in generated form: %+v", bad, schema.Fields)
		}
	}
	if !ids["name"] || !ids[LinkedFormPhotoFieldID] {
		t.Fatalf("expected name + photos, got %+v", schema.Fields)
	}
}
