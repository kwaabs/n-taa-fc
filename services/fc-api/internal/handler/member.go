package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type MemberHandler struct {
	svc *service.MemberService
}

func NewMemberHandler(svc *service.MemberService) *MemberHandler {
	return &MemberHandler{svc: svc}
}

// ── Request DTOs ─────────────────────────────────────────

type AddMemberRequest struct {
	Email string `json:"email"`
	Role  string `json:"role"`
}

type UpdateRoleRequest struct {
	Role string `json:"role"`
}

// ── Handlers ─────────────────────────────────────────────

func (h *MemberHandler) List(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	userID := middleware.GetUserID(r.Context())

	members, err := h.svc.List(r.Context(), projectID, userID)
	if err != nil {
		RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, members)
}

func (h *MemberHandler) Add(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	var req AddMemberRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	if req.Email == "" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "email is required")
		return
	}
	if req.Role != "admin" && req.Role != "supervisor" && req.Role != "field_worker" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "role must be 'admin', 'supervisor', or 'field_worker'")
		return
	}

	userID := middleware.GetUserID(r.Context())

	member, err := h.svc.Add(r.Context(), projectID, userID, req.Email, req.Role)
	if err != nil {
		RespondError(w, http.StatusForbidden, "ADD_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusCreated, member)
}

func (h *MemberHandler) UpdateRole(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	targetUserID, err := uuid.Parse(chi.URLParam(r, "userID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
		return
	}

	var req UpdateRoleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	if req.Role != "admin" && req.Role != "supervisor" && req.Role != "field_worker" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "role must be 'admin', 'supervisor', or 'field_worker'")
		return
	}

	userID := middleware.GetUserID(r.Context())

	if err := h.svc.UpdateRole(r.Context(), projectID, userID, targetUserID, req.Role); err != nil {
		RespondError(w, http.StatusForbidden, "UPDATE_ROLE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]string{"status": "role updated"})
}

func (h *MemberHandler) Remove(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	targetUserID, err := uuid.Parse(chi.URLParam(r, "userID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
		return
	}

	userID := middleware.GetUserID(r.Context())

	if err := h.svc.Remove(r.Context(), projectID, userID, targetUserID); err != nil {
		RespondError(w, http.StatusForbidden, "REMOVE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]string{"status": "member removed"})
}
