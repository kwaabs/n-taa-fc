package handler

import (
    "encoding/json"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type TeamHandler struct {
    svc *service.TeamService
}

func NewTeamHandler(svc *service.TeamService) *TeamHandler {
    return &TeamHandler{svc: svc}
}

type CreateTeamRequest struct {
    Name        string `json:"name"`
    Description string `json:"description"`
}

type UpdateTeamRequest struct {
    Name        *string `json:"name,omitempty"`
    Description *string `json:"description,omitempty"`
}

type AddTeamMemberRequest struct {
    Email string `json:"email"`
    Role  string `json:"role"`
}

type AssignTeamRequest struct {
    TeamID uuid.UUID `json:"team_id"`
    Role   string    `json:"role"`
}

// ── Team CRUD ─────────────────────────────────────

func (h *TeamHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req CreateTeamRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    userID := middleware.GetUserID(r.Context())
    team, err := h.svc.Create(r.Context(), userID, req.Name, req.Description)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, team)
}

func (h *TeamHandler) List(w http.ResponseWriter, r *http.Request) {
    teams, err := h.svc.List(r.Context())
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, teams)
}

func (h *TeamHandler) Get(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    team, err := h.svc.Get(r.Context(), teamID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, team)
}

func (h *TeamHandler) Update(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    var req UpdateTeamRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    team, err := h.svc.Update(r.Context(), teamID, req.Name, req.Description)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, team)
}

func (h *TeamHandler) Delete(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    if err := h.svc.Delete(r.Context(), teamID); err != nil {
        RespondError(w, http.StatusBadRequest, "DELETE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// ── Team Members ──────────────────────────────────

func (h *TeamHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    members, err := h.svc.ListMembers(r.Context(), teamID)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, members)
}

func (h *TeamHandler) AddMember(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    var req AddTeamMemberRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    member, err := h.svc.AddMember(r.Context(), teamID, req.Email, req.Role)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "ADD_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, member)
}

func (h *TeamHandler) UpdateMemberRole(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    userID, err := uuid.Parse(chi.URLParam(r, "userID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
        return
    }
    var req struct {
        Role string `json:"role"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    if err := h.svc.UpdateMemberRole(r.Context(), teamID, userID, req.Role); err != nil {
        RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "role updated"})
}

func (h *TeamHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    userID, err := uuid.Parse(chi.URLParam(r, "userID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid user ID")
        return
    }
    if err := h.svc.RemoveMember(r.Context(), teamID, userID); err != nil {
        RespondError(w, http.StatusBadRequest, "REMOVE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "removed"})
}

// ── Project Team Assignment ───────────────────────

func (h *TeamHandler) AssignToProject(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    var req AssignTeamRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }
    pt, err := h.svc.AssignToProject(r.Context(), projectID, req.TeamID, req.Role)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "ASSIGN_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, pt)
}

func (h *TeamHandler) RemoveFromProject(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    teamID, err := uuid.Parse(chi.URLParam(r, "teamID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid team ID")
        return
    }
    if err := h.svc.RemoveFromProject(r.Context(), projectID, teamID); err != nil {
        RespondError(w, http.StatusBadRequest, "REMOVE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "removed"})
}

func (h *TeamHandler) ListProjectTeams(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    teams, err := h.svc.ListProjectTeams(r.Context(), projectID)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, teams)
}