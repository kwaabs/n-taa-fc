package service

import "testing"

func TestFeaturesForTilesIncludesSourceRef(t *testing.T) {
	in := []map[string]interface{}{
		{
			"type": "Feature",
			"id":   "abc",
			"geometry": map[string]interface{}{
				"type":        "Point",
				"coordinates": []interface{}{1.0, 2.0},
			},
			"properties": map[string]interface{}{
				"name":         "pole",
				"_source_ref":  "SR-1",
				"_data_source_id": "ds-9",
			},
		},
	}
	out := featuresForTiles(in)
	if len(out) != 1 {
		t.Fatalf("expected 1 feature, got %d", len(out))
	}
	props, ok := out[0]["properties"].(map[string]interface{})
	if !ok {
		t.Fatalf("expected properties map, got %T", out[0]["properties"])
	}
	if props["fc_ref"] != "SR-1" {
		t.Fatalf("expected fc_ref SR-1, got %v", props["fc_ref"])
	}
	if props["_source_ref"] != "SR-1" {
		t.Fatalf("expected _source_ref SR-1, got %v", props["_source_ref"])
	}
	if props["name"] != nil {
		t.Fatalf("expected name stripped from tile props, got %v", props["name"])
	}
}

func TestFeaturesForTilesUsesFeatureIDAsSourceRef(t *testing.T) {
	in := []map[string]interface{}{
		{
			"type": "Feature",
			"id":   "42",
			"geometry": map[string]interface{}{
				"type":        "Point",
				"coordinates": []interface{}{1.0, 2.0},
			},
			"properties": map[string]interface{}{},
		},
	}
	out := featuresForTiles(in)
	props := out[0]["properties"].(map[string]interface{})
	if props["fc_ref"] != "42" {
		t.Fatalf("expected fc_ref 42, got %v", props["fc_ref"])
	}
	if props["_source_ref"] != "42" {
		t.Fatalf("expected _source_ref 42, got %v", props["_source_ref"])
	}
}
