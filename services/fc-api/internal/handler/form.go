package handler

import (
    "encoding/json"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type FormHandler struct {
    svc *service.FormService
}

func NewFormHandler(svc *service.FormService) *FormHandler {
    return &FormHandler{svc: svc}
}

type CreateFormRequest struct {
    Name        string          `json:"name"`
    Description string          `json:"description"`
    Schema      json.RawMessage `json:"schema"`
}

type UpdateFormRequest struct {
    Name        *string          `json:"name,omitempty"`
    Description *string          `json:"description,omitempty"`
    Schema      *json.RawMessage `json:"schema,omitempty"`
}

type PublishRequest struct {
    Version int `json:"version"`
}

func (h *FormHandler) Create(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    var req CreateFormRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    if req.Name == "" {
        RespondError(w, http.StatusBadRequest, "VALIDATION", "name is required")
        return
    }
    if req.Schema == nil {
        RespondError(w, http.StatusBadRequest, "VALIDATION", "schema is required")
        return
    }
    userID := middleware.GetUserID(r.Context())
    form, err := h.svc.Create(r.Context(), userID, projectID, req.Name, req.Description, req.Schema)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, form)
}

func (h *FormHandler) List(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    forms, err := h.svc.List(r.Context(), projectID, userID)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, forms)
}

func (h *FormHandler) Get(w http.ResponseWriter, r *http.Request) {
    formID, err := uuid.Parse(chi.URLParam(r, "formID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid form ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    form, err := h.svc.Get(r.Context(), formID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, form)
}

func (h *FormHandler) Update(w http.ResponseWriter, r *http.Request) {
    formID, err := uuid.Parse(chi.URLParam(r, "formID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid form ID")
        return
    }
    var req UpdateFormRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    form, err := h.svc.Update(r.Context(), formID, userID, req.Name, req.Description, req.Schema)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, form)
}

func (h *FormHandler) Publish(w http.ResponseWriter, r *http.Request) {
    formID, err := uuid.Parse(chi.URLParam(r, "formID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid form ID")
        return
    }
    var req PublishRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    if req.Version <= 0 {
        RespondError(w, http.StatusBadRequest, "VALIDATION", "version is required and must be > 0")
        return
    }
    userID := middleware.GetUserID(r.Context())
    fv, err := h.svc.Publish(r.Context(), formID, userID, req.Version)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "PUBLISH_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, fv)
}

func (h *FormHandler) GetVersions(w http.ResponseWriter, r *http.Request) {
    formID, err := uuid.Parse(chi.URLParam(r, "formID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid form ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    versions, err := h.svc.GetVersions(r.Context(), formID, userID)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, versions)
}

// GET /api/v1/form-templates?exclude_project_id=
func (h *FormHandler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	exclude := uuid.Nil
	if v := r.URL.Query().Get("exclude_project_id"); v != "" {
		if id, err := uuid.Parse(v); err == nil {
			exclude = id
		}
	}
	rows, err := h.svc.ListTemplates(r.Context(), userID, exclude)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, rows)
}

type CloneFormRequest struct {
	SourceFormID uuid.UUID `json:"source_form_id"`
	Name         string    `json:"name,omitempty"`
}

// POST /api/v1/projects/{projectID}/forms/clone
func (h *FormHandler) Clone(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	var req CloneFormRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	if req.SourceFormID == uuid.Nil {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "source_form_id is required")
		return
	}
	userID := middleware.GetUserID(r.Context())
	form, err := h.svc.CloneIntoProject(r.Context(), userID, projectID, req.SourceFormID, req.Name)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "CLONE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusCreated, form)
}