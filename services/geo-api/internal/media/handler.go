package media

import (
	"log/slog"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/httpx"
)

type Handler struct {
	svc    *Service
	logger *slog.Logger
}

func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, logger: logger}
}

// GET /api/v1/layers/{layerId}/features/{ogcFid}/attachments
func (h *Handler) ListAttachments(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerId"))
	if err != nil {
		httpx.BadRequest(w, "invalid layerId")
		return
	}
	ogcFid, err := strconv.ParseInt(chi.URLParam(r, "ogcFid"), 10, 64)
	if err != nil {
		httpx.BadRequest(w, "invalid ogcFid")
		return
	}
	items, err := h.svc.ListForFeature(r.Context(), layerID, ogcFid)
	if err != nil {
		h.logger.Error("list attachments", slog.String("err", err.Error()))
		httpx.Error(w, http.StatusInternalServerError, "attachments_failed", err.Error())
		return
	}
	if items == nil {
		items = []AttachmentView{}
	}
	httpx.JSON(w, http.StatusOK, items)
}
