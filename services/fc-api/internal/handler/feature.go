package handler

import (
    "encoding/json"
    "net/http"
    "strconv"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type FeatureHandler struct {
    svc *service.FeatureService
}

func NewFeatureHandler(svc *service.FeatureService) *FeatureHandler {
    return &FeatureHandler{svc: svc}
}

type UpdateFeatureStatusRequest struct {
    Status      string `json:"status"`
    ReviewNotes string `json:"review_notes"`
}



func (h *FeatureHandler) Get(w http.ResponseWriter, r *http.Request) {
    featureID, err := uuid.Parse(chi.URLParam(r, "featureID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid feature ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    feature, err := h.svc.Get(r.Context(), featureID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, feature)
}

func (h *FeatureHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
    featureID, err := uuid.Parse(chi.URLParam(r, "featureID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid feature ID")
        return
    }
    var req UpdateFeatureStatusRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.UpdateStatus(r.Context(), featureID, userID, req.Status, req.ReviewNotes); err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": req.Status})
}

func (h *FeatureHandler) List(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }

    limitStr := r.URL.Query().Get("limit")
    offsetStr := r.URL.Query().Get("offset")
    layerIDStr := r.URL.Query().Get("layer_id")

    limit := 50
    if limitStr != "" {
        if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 500 {
            limit = l
        }
    }
    offset := 0
    if offsetStr != "" {
        if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
            offset = o
        }
    }

    var layerID *uuid.UUID
    if layerIDStr != "" {
        lid, err := uuid.Parse(layerIDStr)
        if err != nil {
            RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
            return
        }
        layerID = &lid
    }

    userID := middleware.GetUserID(r.Context())
    features, total, err := h.svc.ListByProjectAndLayer(r.Context(), projectID, layerID, userID, limit, offset)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondListWithMeta(w, http.StatusOK, features, total, offset, limit)
}