package handler

import (
    "encoding/json"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type AttachmentHandler struct {
    svc *service.AttachmentService
}

func NewAttachmentHandler(svc *service.AttachmentService) *AttachmentHandler {
    return &AttachmentHandler{svc: svc}
}

// ── Request bodies ──────────────────────────────────────

type CreateAttachmentBody struct {
    ClientID  uuid.UUID  `json:"client_id"`
    FeatureID *uuid.UUID `json:"feature_id,omitempty"`
    FieldID   string     `json:"field_id"`
    Kind      string     `json:"kind"`
    MimeType  string     `json:"mime_type"`
    SizeBytes int64      `json:"size_bytes"`
}

// ── Endpoints ───────────────────────────────────────────

// POST /api/v1/projects/{projectID}/attachments
func (h *AttachmentHandler) Create(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    var body CreateAttachmentBody
    if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }

    if body.ClientID == uuid.Nil {
        RespondError(w, http.StatusBadRequest, "VALIDATION", "client_id is required")
        return
    }

    userID := middleware.GetUserID(r.Context())
    result, err := h.svc.Create(r.Context(), userID, service.CreateAttachmentInput{
        ProjectID: projectID,
        FeatureID: body.FeatureID,
        ClientID:  body.ClientID,
        FieldID:   body.FieldID,
        Kind:      body.Kind,
        MimeType:  body.MimeType,
        SizeBytes: body.SizeBytes,
    })
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
        return
    }

    RespondJSON(w, http.StatusCreated, result)
}

// POST /api/v1/attachments/{attachmentID}/confirm
func (h *AttachmentHandler) Confirm(w http.ResponseWriter, r *http.Request) {
    attID, err := uuid.Parse(chi.URLParam(r, "attachmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid attachment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    att, err := h.svc.Confirm(r.Context(), attID, userID)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CONFIRM_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, att)
}

// GET /api/v1/attachments/{attachmentID}
func (h *AttachmentHandler) Get(w http.ResponseWriter, r *http.Request) {
    attID, err := uuid.Parse(chi.URLParam(r, "attachmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid attachment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    view, err := h.svc.Get(r.Context(), attID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, view)
}

// DELETE /api/v1/attachments/{attachmentID}
func (h *AttachmentHandler) Delete(w http.ResponseWriter, r *http.Request) {
    attID, err := uuid.Parse(chi.URLParam(r, "attachmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid attachment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.Delete(r.Context(), attID, userID); err != nil {
        RespondError(w, http.StatusBadRequest, "DELETE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// GET /api/v1/projects/{projectID}/features/{featureID}/attachments
func (h *AttachmentHandler) ListByFeature(w http.ResponseWriter, r *http.Request) {
    featureID, err := uuid.Parse(chi.URLParam(r, "featureID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid feature ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    views, err := h.svc.ListByFeature(r.Context(), featureID, userID)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, views)
}