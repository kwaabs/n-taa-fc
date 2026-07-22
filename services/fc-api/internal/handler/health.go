package handler

import (
	"net/http"
	"time"

	"github.com/uptrace/bun"
)

const appVersion = "0.1.0"

type HealthHandler struct {
	db *bun.DB
}

func NewHealthHandler(db *bun.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

func (h *HealthHandler) Check(w http.ResponseWriter, r *http.Request) {
	err := h.db.PingContext(r.Context())
	if err != nil {
		RespondError(w, http.StatusServiceUnavailable, "DB_ERROR", "database unreachable")
		return
	}

	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"status":    "ok",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"version":   appVersion,
	})
}
