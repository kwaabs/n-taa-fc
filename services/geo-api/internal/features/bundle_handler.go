package features

import (
    "encoding/json"
    "net/http"
    "strconv"
    "strings"
    "time"

    "github.com/go-chi/chi/v5"

    "github.com/kwaabs/n-taa-fc/services/geo-api/internal/auth"
    "github.com/kwaabs/n-taa-fc/services/geo-api/internal/httpx"
)

type bundleExportRequest struct {
    LayerIDs []string        `json:"layer_ids"`
    Within   json.RawMessage `json:"within"`
}

// BundleExport — POST /api/v1/export/bundle.{fmt}
// fmt ∈ { csv, geojson, xlsx, kmz }
//
// Exports several layers in one request. XLSX gets one workbook with one
// sheet per layer; KMZ gets one KML doc with one <Folder> per layer; CSV
// and GeoJSON (no native multi-table-per-file convention) get a zip with
// one file per layer. Layers the caller can't export, or that fail to
// resolve/stream, are skipped rather than failing the whole request — the
// count is reported via the X-Export-Skipped-Count response header.
func (h *Handler) BundleExport(w http.ResponseWriter, r *http.Request) {
    fmtParam := strings.ToLower(chi.URLParam(r, "fmt"))

    var req bundleExportRequest
    if err := httpx.DecodeJSON(r, &req); err != nil {
        httpx.BadRequest(w, "invalid JSON body")
        return
    }
    if len(req.LayerIDs) == 0 {
        httpx.BadRequest(w, "layer_ids is required")
        return
    }
    if len(req.Within) == 0 {
        httpx.BadRequest(w, "within geometry is required")
        return
    }

    role, _ := auth.RoleFromContext(r.Context())

    var (
        bundleLayers []BundleLayer
        denied       []string
    )
    for _, idStr := range req.LayerIDs {
        id, err := parseUUID(idStr)
        if err != nil {
            denied = append(denied, idStr)
            continue
        }
        layer, err := h.layersService.Get(r.Context(), id)
        if err != nil {
            denied = append(denied, idStr)
            continue
        }
        if !layer.CanExport(string(role)) {
            denied = append(denied, layer.DisplayName)
            continue
        }
        bundleLayers = append(bundleLayers, BundleLayer{ID: idStr, Name: layer.Name})
    }

    if len(bundleLayers) == 0 {
        httpx.Forbidden(w, "no requested layers are exportable")
        return
    }

    if fmtParam != "csv" && fmtParam != "geojson" && fmtParam != "json" &&
        fmtParam != "xlsx" && fmtParam != "excel" && fmtParam != "kmz" {
        httpx.BadRequest(w, "unsupported format: "+fmtParam)
        return
    }

    stamp := time.Now().UTC().Format("20060102_150405")

    // X-Export-Skipped-Count only ever reflects permission-denied layers
    // (known up front). Layers that fail mid-stream are logged server-side
    // instead — by the time that's known, headers are already flushed to
    // the client and can no longer be changed.
    if len(denied) > 0 {
        w.Header().Set("X-Export-Skipped-Count", strconv.Itoa(len(denied)))
    }

    var skipped []string
    var streamErr error

    switch fmtParam {
    case "csv":
        filename := "export_bundle_" + stamp + ".zip"
        w.Header().Set("Content-Type", "application/zip")
        w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
        skipped, streamErr = h.svc.StreamCSVBundle(r.Context(), bundleLayers, req.Within, w)

    case "geojson", "json":
        filename := "export_bundle_" + stamp + ".zip"
        w.Header().Set("Content-Type", "application/zip")
        w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
        skipped, streamErr = h.svc.StreamGeoJSONBundle(r.Context(), bundleLayers, req.Within, w)

    case "xlsx", "excel":
        filename := "export_bundle_" + stamp + ".xlsx"
        w.Header().Set("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
        skipped, streamErr = h.svc.StreamXLSXBundle(r.Context(), bundleLayers, req.Within, w)

    case "kmz":
        filename := "export_bundle_" + stamp + ".kmz"
        w.Header().Set("Content-Type", "application/vnd.google-earth.kmz")
        w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
        skipped, streamErr = h.svc.StreamKMZBundle(r.Context(), bundleLayers, req.Within, "Export", w)
    }

    if streamErr != nil {
        h.logger.Error("bundle export failed", "fmt", fmtParam, "err", streamErr.Error())
    }
    if len(skipped) > 0 {
        h.logger.Warn("bundle export: some layers failed mid-stream",
            "fmt", fmtParam, "layers", strings.Join(skipped, ","))
    }
}
