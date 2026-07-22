package handler

import (
    "encoding/json"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type StyleHandler struct {
    svc *service.StyleService
}

func NewStyleHandler(svc *service.StyleService) *StyleHandler {
    return &StyleHandler{svc: svc}
}

// GetStyle returns the layer's current style (or default if none).
func (h *StyleHandler) GetStyle(w http.ResponseWriter, r *http.Request) {
    layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
        return
    }

    style, err := h.svc.GetStyle(r.Context(), layerID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }

    RespondJSON(w, http.StatusOK, style)
}

// UpdateStyle replaces the layer style.
func (h *StyleHandler) UpdateStyle(w http.ResponseWriter, r *http.Request) {
    layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
        return
    }

    var raw json.RawMessage
    if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }

    userID := middleware.GetUserID(r.Context())

    layer, err := h.svc.UpdateStyle(r.Context(), layerID, userID, raw)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }

    RespondJSON(w, http.StatusOK, layer)
}