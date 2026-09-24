package service

import (
	"testing"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

func TestRequiredAckKeysEvwAndHomeDB(t *testing.T) {
	ds := &model.LayerDataSource{
		SourceType:     "database",
		DeleteStrategy: "hard",
		Config:         []byte(`{"schema":"dbo","table":"dbo_ug_cable_11kv_evw","id_column":"ogc_fid","geometry_column":"the_geom"}`),
	}
	// Without DB we only exercise config-derived warnings that don't need relation lookup —
	// call assess with nil db is not allowed. Use helper pieces instead.
	ps := []WritebackPrecaution{
		{Code: "evw_named_target", Severity: "warning", RequiresAck: true, AckKey: ackEvwTarget},
		{Code: "home_db_fallback", Severity: "warning", RequiresAck: true, AckKey: ackHomeDB},
		{Code: "hard_delete", Severity: "warning", RequiresAck: true, AckKey: ackHardDelete},
		{Code: "dual_model", Severity: "info"},
	}
	keys := requiredAckKeys(ps)
	if len(keys) != 3 {
		t.Fatalf("expected 3 ack keys, got %v", keys)
	}
	missing := missingAcknowledgments(keys, []string{ackEvwTarget})
	if len(missing) != 2 {
		t.Fatalf("expected 2 missing, got %v", missing)
	}
	if hasWritebackBlocker(ps) {
		t.Fatal("warnings should not block")
	}
	blockers := append(ps, WritebackPrecaution{Code: "target_is_view", Severity: "blocker", Message: "view"})
	if !hasWritebackBlocker(blockers) {
		t.Fatal("expected blocker")
	}
	_ = ds
}

func TestMissingAcknowledgmentsCaseInsensitive(t *testing.T) {
	missing := missingAcknowledgments(
		[]string{ackHardDelete, ackEvwTarget},
		[]string{"HARD_DELETE", "evw_target"},
	)
	if len(missing) != 0 {
		t.Fatalf("expected none missing, got %v", missing)
	}
}
