package handler

import (
    "encoding/json"
    "net/http"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type AssignmentHandler struct {
    svc *service.AssignmentService
}

func NewAssignmentHandler(svc *service.AssignmentService) *AssignmentHandler {
    return &AssignmentHandler{svc: svc}
}

type CreateAssignmentRequest struct {
    AssignedTo   *uuid.UUID `json:"assigned_to,omitempty"`
    TeamID       *uuid.UUID `json:"team_id,omitempty"`
    FormID       *uuid.UUID `json:"form_id,omitempty"`
    LayerID      *uuid.UUID `json:"layer_id,omitempty"`
    Area         *string    `json:"area,omitempty"` // GeoJSON polygon string
    Title        string     `json:"title,omitempty"`
    TargetCount  int        `json:"target_count,omitempty"`
    Instructions string     `json:"instructions,omitempty"`
    Priority     string     `json:"priority,omitempty"`
    DueDate      *time.Time `json:"due_date,omitempty"`
}

type UpdateAssignmentStatusRequest struct {
    Status string `json:"status"`
}

type ExtendDueDateRequest struct {
    DueDate *time.Time `json:"due_date"`
}

type ReassignRequest struct {
    AssignedTo *uuid.UUID `json:"assigned_to,omitempty"`
    TeamID     *uuid.UUID `json:"team_id,omitempty"`
}

func (h *AssignmentHandler) Create(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    var req CreateAssignmentRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }

    input := service.CreateAssignmentInput{
        ProjectID:    projectID,
        AssignedTo:   req.AssignedTo,
        TeamID:       req.TeamID,
        FormID:       req.FormID,
        LayerID:      req.LayerID,
        Area:         req.Area,
        Title:        req.Title,
        TargetCount:  req.TargetCount,
        Instructions: req.Instructions,
        Priority:     req.Priority,
        DueDate:      req.DueDate,
    }

    userID := middleware.GetUserID(r.Context())
    result, err := h.svc.Create(r.Context(), userID, input)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, result)
}

func (h *AssignmentHandler) List(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    assignments, err := h.svc.List(r.Context(), projectID, userID)
    if err != nil {
        RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, assignments)
}

func (h *AssignmentHandler) Get(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    a, err := h.svc.Get(r.Context(), aID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, a)
}

func (h *AssignmentHandler) Update(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    var req CreateAssignmentRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    input := service.CreateAssignmentInput{
        FormID:       req.FormID,
        LayerID:      req.LayerID,
        Title:        req.Title,
        TargetCount:  req.TargetCount,
        Instructions: req.Instructions,
        Priority:     req.Priority,
        DueDate:      req.DueDate,
    }
    userID := middleware.GetUserID(r.Context())
    result, err := h.svc.Update(r.Context(), aID, userID, input)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, result)
}

func (h *AssignmentHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    var req UpdateAssignmentStatusRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.UpdateStatus(r.Context(), aID, userID, req.Status); err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": req.Status})
}

func (h *AssignmentHandler) ExtendDueDate(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    var req ExtendDueDateRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.ExtendDueDate(r.Context(), aID, userID, req.DueDate); err != nil {
        RespondError(w, http.StatusBadRequest, "EXTEND_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "due date updated"})
}

func (h *AssignmentHandler) Reassign(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    var req ReassignRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.Reassign(r.Context(), aID, userID, req.AssignedTo, req.TeamID); err != nil {
        RespondError(w, http.StatusBadRequest, "REASSIGN_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "reassigned"})
}

func (h *AssignmentHandler) Delete(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if err := h.svc.Delete(r.Context(), aID, userID); err != nil {
        RespondError(w, http.StatusBadRequest, "DELETE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *AssignmentHandler) GetProgress(w http.ResponseWriter, r *http.Request) {
    aID, err := uuid.Parse(chi.URLParam(r, "assignmentID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid assignment ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    progress, err := h.svc.GetProgress(r.Context(), aID, userID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "PROGRESS_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, progress)
}