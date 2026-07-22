package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type ProjectHandler struct {
	svc *service.ProjectService
}

func NewProjectHandler(svc *service.ProjectService) *ProjectHandler {
	return &ProjectHandler{svc: svc}
}

// ── Request DTOs ─────────────────────────────────────────

type CreateProjectRequest struct {
	Name           string          `json:"name"`
	Description    string          `json:"description"`
	Mode           string          `json:"mode"`
	Config         json.RawMessage `json:"config"`
	AreaOfInterest json.RawMessage `json:"area_of_interest,omitempty"`
}

type UpdateProjectRequest struct {
	Name        *string          `json:"name"`
	Description *string          `json:"description"`
	Config      *json.RawMessage `json:"config"`

	AreaOfInterest json.RawMessage `json:"area_of_interest,omitempty"`
}

// ── Handlers ─────────────────────────────────────────────

func (h *ProjectHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req CreateProjectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	if req.Name == "" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "name is required")
		return
	}
	if req.Mode != "map_based" && req.Mode != "form_collection" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "mode must be 'map_based' or 'form_collection'")
		return
	}

	userID := middleware.GetUserID(r.Context())

	project, err := h.svc.Create(r.Context(), userID, req.Name, req.Description, req.Mode, req.Config, req.AreaOfInterest)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "CREATE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusCreated, project)
}

func (h *ProjectHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	projects, err := h.svc.List(r.Context(), userID)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, projects)
}

func (h *ProjectHandler) Get(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	userID := middleware.GetUserID(r.Context())

	project, err := h.svc.Get(r.Context(), projectID, userID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, project)
}

func (h *ProjectHandler) Update(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	var req UpdateProjectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	userID := middleware.GetUserID(r.Context())

	project, err := h.svc.Update(r.Context(), projectID, userID, req.Name, req.Description, req.Config, req.AreaOfInterest)
	if err != nil {
		RespondError(w, http.StatusForbidden, "UPDATE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, project)
}

func (h *ProjectHandler) Archive(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	userID := middleware.GetUserID(r.Context())

	if err := h.svc.Archive(r.Context(), projectID, userID); err != nil {
		RespondError(w, http.StatusForbidden, "ARCHIVE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]string{"status": "archived"})
}

func (h *ProjectHandler) Dispatch(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	project, err := h.svc.Dispatch(r.Context(), projectID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "DISPATCH_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, project)
}
