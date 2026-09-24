package service

import (
	"encoding/json"
	"testing"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

func TestGeoJSONRawToStringObject(t *testing.T) {
	raw := json.RawMessage(`{"type":"Point","coordinates":[1,2]}`)
	got := geoJSONRawToString(&raw)
	if got == nil || *got != `{"type":"Point","coordinates":[1,2]}` {
		t.Fatalf("got %v", got)
	}
}

func TestGeoJSONRawToStringQuoted(t *testing.T) {
	inner := `{"type":"Point","coordinates":[1,2]}`
	b, _ := json.Marshal(inner)
	raw := json.RawMessage(b)
	got := geoJSONRawToString(&raw)
	if got == nil || *got != inner {
		t.Fatalf("got %v", got)
	}
}

func TestGeomChangedRequiresOriginalSnapshot(t *testing.T) {
	cur := `{"type":"Point","coordinates":[1,2]}`
	f := &model.Feature{Geometry: &cur}
	changed, _ := geomChanged(f)
	if changed {
		t.Fatal("missing original should not report geom change")
	}

	orig := `{"type":"Point","coordinates":[0,0]}`
	f.OriginalGeometry = &orig
	changed, neo := geomChanged(f)
	if !changed || neo != cur {
		t.Fatalf("expected change, got changed=%v neo=%q", changed, neo)
	}

	f.OriginalGeometry = &cur
	changed, _ = geomChanged(f)
	if changed {
		t.Fatal("identical geoms should not change")
	}
}

func TestSyncFeatureUnmarshalsOriginalGeometryObject(t *testing.T) {
	payload := []byte(`{
		"client_id":"00000000-0000-0000-0000-000000000001",
		"form_id":"00000000-0000-0000-0000-000000000002",
		"form_version":1,
		"attributes":{},
		"status":"submitted",
		"collected_at":"2026-07-23T00:00:00Z",
		"source_ref":"42",
		"geometry":{"type":"Point","coordinates":[3,4]},
		"original_geometry":{"type":"Point","coordinates":[1,2]}
	}`)
	var sf model.SyncFeature
	if err := json.Unmarshal(payload, &sf); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if sf.OriginalGeometry == nil {
		t.Fatal("original_geometry nil — type must accept GeoJSON object")
	}
	orig := geoJSONRawToString(sf.OriginalGeometry)
	cur := geoJSONRawToString(sf.Geometry)
	f := &model.Feature{Geometry: cur, OriginalGeometry: orig}
	changed, _ := geomChanged(f)
	if !changed {
		t.Fatal("expected geomChanged after object sync payload")
	}
}
