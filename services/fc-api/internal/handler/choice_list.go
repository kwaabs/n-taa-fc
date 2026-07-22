package handler

import (
    "encoding/json"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type ChoiceListHandler struct {
    svc *service.ChoiceListService
}

func NewChoiceListHandler(svc *service.ChoiceListService) *ChoiceListHandler {
    return &ChoiceListHandler{svc: svc}
}

type CreateChoiceListRequest struct {
    Name    string          `json:"name"`
    Choices json.RawMessage `json:"choices"`
}

type UpdateChoiceListRequest struct {
    Name    *string          `json:"name,omitempty"`
    Choices *json.RawMessage `json:"choices,omitempty"`
}

func (h *ChoiceListHandler) Create(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    var req CreateChoiceListRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    cl, err := h.svc.Create(r.Context(), userID, projectID, req.Name, req.Choices)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, cl)
}

func (h *ChoiceListHandler) List(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    lists, err := h.svc.List(r.Context(), projectID, userID)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, lists)
}

func (h *ChoiceListHandler) Get(w http.ResponseWriter, r *http.Request) {
    clID, err := uuid.Parse(chi.URLParam(r, "choiceListID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid choice list ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    cl, err := h.svc.Get(r.Context(), clID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, cl)
}

func (h *ChoiceListHandler) Update(w http.ResponseWriter, r *http.Request) {
    clID, err := uuid.Parse(chi.URLParam(r, "choiceListID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid choice list ID")
        return
    }
    var req UpdateChoiceListRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    cl, err := h.svc.Update(r.Context(), clID, userID, req.Name, req.Choices)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, cl)
}

func (h *ChoiceListHandler) Delete(w http.ResponseWriter, r *http.Request) {
    clID, err := uuid.Parse(chi.URLParam(r, "choiceListID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid choice list ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.Delete(r.Context(), clID, userID); err != nil {
        RespondError(w, http.StatusForbidden, "DELETE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}