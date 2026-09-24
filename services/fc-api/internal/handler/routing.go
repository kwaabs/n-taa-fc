package handler

import (
	"net/http"
	"strconv"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type RoutingHandler struct {
	svc *service.RoutingService
}

func NewRoutingHandler(svc *service.RoutingService) *RoutingHandler {
	return &RoutingHandler{svc: svc}
}

// Guide returns a road-following polyline between two WGS84 points.
// GET /api/v1/routing/guide?from_lat=&from_lng=&to_lat=&to_lng=
func (h *RoutingHandler) Guide(w http.ResponseWriter, r *http.Request) {
	fromLat, err := strconv.ParseFloat(r.URL.Query().Get("from_lat"), 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "from_lat required")
		return
	}
	fromLng, err := strconv.ParseFloat(r.URL.Query().Get("from_lng"), 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "from_lng required")
		return
	}
	toLat, err := strconv.ParseFloat(r.URL.Query().Get("to_lat"), 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "to_lat required")
		return
	}
	toLng, err := strconv.ParseFloat(r.URL.Query().Get("to_lng"), 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "to_lng required")
		return
	}

	route, err := h.svc.GuideRoute(r.Context(), fromLat, fromLng, toLat, toLng)
	if err != nil {
		RespondError(w, http.StatusBadGateway, "ROUTING_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, route)
}
