package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type UserHandler struct {
	userRepo *repository.UserRepo
}

func NewUserHandler(userRepo *repository.UserRepo) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

// GET /api/v1/users  — list all users (system-admin gated at route)
func (h *UserHandler) List(w http.ResponseWriter, r *http.Request) {
	users, err := h.userRepo.List(r.Context())
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, users)
}

type UpdateUserRoleBody struct {
	Role string `json:"role"`
}

// PATCH /api/v1/users/{userID}/role  — set a user's global role
func (h *UserHandler) UpdateRole(w http.ResponseWriter, r *http.Request) {
	userID, err := uuid.Parse(chi.URLParam(r, "userID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
		return
	}

	var body UpdateUserRoleBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse body")
		return
	}

	switch body.Role {
	case "field_worker", "supervisor", "admin":
		// valid
	default:
		RespondError(w, http.StatusBadRequest, "INVALID_ROLE",
			"role must be field_worker, supervisor, or admin")
		return
	}

	if err := h.userRepo.UpdateRole(r.Context(), userID, body.Role); err != nil {
		RespondError(w, http.StatusInternalServerError, "UPDATE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]string{"status": "updated", "role": body.Role})
}

// GET /api/v1/users/{userID} — full detail: profile + teams + projects
func (h *UserHandler) GetDetail(w http.ResponseWriter, r *http.Request) {
	userID, err := uuid.Parse(chi.URLParam(r, "userID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
		return
	}

	profile, err := h.userRepo.FindByID(r.Context(), userID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "user not found")
		return
	}

	teams, err := h.userRepo.TeamsForUser(r.Context(), userID)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "TEAMS_FAILED", err.Error())
		return
	}

	projects, err := h.userRepo.ProjectsForUser(r.Context(), userID)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "PROJECTS_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"profile":  profile,
		"teams":    teams,
		"projects": projects,
	})
}