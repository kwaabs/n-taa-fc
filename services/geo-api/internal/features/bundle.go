package features

import (
    "archive/zip"
    "context"
    "encoding/json"
    "io"
    "strings"
)

// BundleLayer is the minimal per-layer info a multi-layer export needs —
// the caller (handler) has already resolved + permission-checked the full
// layers.Layer and just hands over what the exporters need.
type BundleLayer struct {
    ID   string
    Name string // used as sheet name / KML folder name / zip entry name
}

// StreamCSVBundle zips one CSV per layer. CSV has no native concept of
// multiple named tables in one file, so (unlike XLSX/KMZ) this is a zip of
// independent files rather than one combined file.
func (s *Service) StreamCSVBundle(
    ctx context.Context,
    layers []BundleLayer,
    within json.RawMessage,
    w io.Writer,
) (skipped []string, err error) {
    zw := zip.NewWriter(w)

    wroteAny := false
    for _, l := range layers {
        entry, cerr := zw.Create(sanitizeFilename(l.Name) + ".csv")
        if cerr != nil {
            return skipped, cerr
        }
        params := ExportCSVParams{Geometry: within}
        if serr := s.StreamCSV(ctx, mustParseUUID(l.ID), params, entry); serr != nil {
            skipped = append(skipped, l.Name)
            continue
        }
        wroteAny = true
    }

    if !wroteAny {
        return skipped, ErrInvalidInput
    }
    return skipped, zw.Close()
}

// StreamGeoJSONBundle zips one GeoJSON FeatureCollection per layer — same
// reasoning as StreamCSVBundle (no standard single-file multi-layer
// GeoJSON convention).
func (s *Service) StreamGeoJSONBundle(
    ctx context.Context,
    layers []BundleLayer,
    within json.RawMessage,
    w io.Writer,
) (skipped []string, err error) {
    zw := zip.NewWriter(w)

    wroteAny := false
    for _, l := range layers {
        entry, cerr := zw.Create(sanitizeFilename(l.Name) + ".geojson")
        if cerr != nil {
            return skipped, cerr
        }
        params := ExportCSVParams{Geometry: within}
        if serr := s.StreamGeoJSON(ctx, l.ID, params, entry); serr != nil {
            skipped = append(skipped, l.Name)
            continue
        }
        wroteAny = true
    }

    if !wroteAny {
        return skipped, ErrInvalidInput
    }
    return skipped, zw.Close()
}

func mustParseUUID(s string) uuidLike {
    id, _ := uuidFromString(s)
    return id
}

// sanitizeFilename keeps zip entry names predictable and traversal-safe.
func sanitizeFilename(name string) string {
    name = strings.TrimSpace(name)
    var b strings.Builder
    for _, r := range name {
        switch {
        case r == '/' || r == '\\' || r == ':' || r == '*' || r == '?' ||
            r == '"' || r == '<' || r == '>' || r == '|':
            b.WriteRune('_')
        default:
            b.WriteRune(r)
        }
    }
    s := b.String()
    if s == "" {
        return "layer"
    }
    return s
}
