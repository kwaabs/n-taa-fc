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

type NotificationHandler struct {
	svc *service.NotificationService
}

func NewNotificationHandler(svc *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

type SendMessageRequest struct {
	Title  string     `json:"title,omitempty"`
	Body   string     `json:"body"`
	TeamID *uuid.UUID `json:"team_id,omitempty"`
	UserID *uuid.UUID `json:"user_id,omitempty"`
}

// GET /api/v1/notifications?unread=true&limit=50
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	unreadOnly := r.URL.Query().Get("unread") == "true" || r.URL.Query().Get("unread") == "1"
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	rows, err := h.svc.List(r.Context(), userID, unreadOnly, limit)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, rows)
}

// GET /api/v1/notifications/unread-count
func (h *NotificationHandler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	n, err := h.svc.UnreadCount(r.Context(), userID)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "COUNT_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, map[string]int{"count": n})
}

// PATCH /api/v1/notifications/{notificationID}/read
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	notificationID, err := uuid.Parse(chi.URLParam(r, "notificationID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid notification ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	if err := h.svc.MarkRead(r.Context(), userID, notificationID); err != nil {
		RespondError(w, http.StatusBadRequest, "MARK_READ_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /api/v1/notifications/read-all
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if err := h.svc.MarkAllRead(r.Context(), userID); err != nil {
		RespondError(w, http.StatusInternalServerError, "MARK_ALL_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /api/v1/projects/{projectID}/messages
func (h *NotificationHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	userID := middleware.GetUserID(r.Context())
	result, err := h.svc.SendMessage(r.Context(), userID, service.SendMessageInput{
		ProjectID: projectID,
		Title:     req.Title,
		Body:      req.Body,
		TeamID:    req.TeamID,
		UserID:    req.UserID,
	})
	if err != nil {
		RespondError(w, http.StatusBadRequest, "SEND_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusCreated, result)
}
