package handler

import (
	"net/http"

	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
)

type MeHandler struct {
	db *bun.DB
}

func NewMeHandler(db *bun.DB) *MeHandler {
	return &MeHandler{db: db}
}

// GET /api/v1/me
// Returns the authenticated user's profile including their fixed role,
// so the frontend/mobile can show/hide features accordingly.
func (h *MeHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var profile struct {
		ID            string `bun:"id" json:"id"`
		Email         string `bun:"email" json:"email"`
		FullName      string `bun:"full_name" json:"full_name"`
		Role          string `bun:"role" json:"role"`
		IsSystemAdmin bool   `bun:"is_system_admin" json:"is_system_admin"`
	}

	err := h.db.NewSelect().
		TableExpr("user_profiles").
		ColumnExpr("id, email, full_name, role, is_system_admin").
		Where("id = ?", userID).
		Scan(r.Context(), &profile)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "user profile not found")
		return
	}

	// System admins always report as admin role for the UI
	if profile.IsSystemAdmin {
		profile.Role = "admin"
	}

	RespondJSON(w, http.StatusOK, profile)
}