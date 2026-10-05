package features

import (
    "archive/zip"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "strconv"
    "strings"
)

// ─────────────────────────────────────────────────────────────
// KMZ exporter (KML doc.kml zipped, the format Google Earth expects)
// ─────────────────────────────────────────────────────────────

// StreamKMZ writes the query results as a KMZ (zipped KML) to w.
// Geometry comes in as GeoJSON (same source as StreamGeoJSON) and is
// translated to KML Point/LineString/Polygon/Multi* geometry.
func (s *Service) StreamKMZ(
    ctx context.Context,
    layerID string,
    params ExportCSVParams,
    layerName string,
    w io.Writer,
) error {
    if len(params.Geometry) == 0 {
        return ErrInvalidInput
    }

    layerUUID, err := parseUUID(layerID)
    if err != nil {
        return err
    }
    _, t, err := s.resolve(ctx, layerUUID)
    if err != nil {
        return err
    }

    zw := zip.NewWriter(w)
    kw, err := zw.Create("doc.kml")
    if err != nil {
        return err
    }

    if _, err := io.WriteString(kw, kmlHeader(layerName)); err != nil {
        return err
    }

    err = s.repo.StreamByGeometryWithGeom(ctx, t, params.Geometry, params.Filters, params.Sort,
        func(id int64, propsRaw json.RawMessage, geomRaw json.RawMessage) error {
            var props map[string]any
            if len(propsRaw) > 0 {
                if err := json.Unmarshal(propsRaw, &props); err != nil {
                    return err
                }
            }

            geomXML, err := geoJSONToKMLGeometry(geomRaw)
            if err != nil || geomXML == "" {
                // Skip features we can't place on the map rather than
                // failing the whole export.
                return nil
            }

            placemark := buildKMLPlacemark(id, layerName, props, geomXML)
            _, err = io.WriteString(kw, placemark)
            return err
        })
    if err != nil {
        return err
    }

    if _, err := io.WriteString(kw, kmlFooter()); err != nil {
        return err
    }

    return zw.Close()
}

func kmlHeader(layerName string) string {
    return `<?xml version="1.0" encoding="UTF-8"?>` +
        `<kml xmlns="http://www.opengis.net/kml/2.2">` +
        `<Document><name>` + xmlEscape(layerName) + `</name>`
}

func kmlFooter() string {
    return `</Document></kml>`
}

// placemarkName picks a human-readable label for the placemark balloon.
// Falls back to "<layer> #<id>" when no obvious name-like field exists.
func placemarkName(id int64, layerName string, props map[string]any) string {
    for _, key := range []string{"name", "label", "asset_tag", "description"} {
        if v, ok := props[key]; ok {
            if s, ok := v.(string); ok && strings.TrimSpace(s) != "" {
                return s
            }
        }
    }
    return layerName + " #" + strconv.FormatInt(id, 10)
}

func buildKMLPlacemark(id int64, layerName string, props map[string]any, geomXML string) string {
    var b strings.Builder
    b.WriteString("<Placemark>")
    b.WriteString("<name>" + xmlEscape(placemarkName(id, layerName, props)) + "</name>")

    if len(props) > 0 {
        b.WriteString("<ExtendedData>")
        for _, k := range deterministicColumns(props)[1:] { // skip the synthetic "ogc_fid" entry
            b.WriteString(`<Data name="` + xmlEscape(k) + `"><value>` +
                xmlEscape(formatCSVValue(props[k])) + `</value></Data>`)
        }
        b.WriteString(`<Data name="ogc_fid"><value>` + strconv.FormatInt(id, 10) + `</value></Data>`)
        b.WriteString("</ExtendedData>")
    }

    b.WriteString(geomXML)
    b.WriteString("</Placemark>")
    return b.String()
}

// ─────────────────────────────────────────────────────────────
// GeoJSON → KML geometry translation
// ─────────────────────────────────────────────────────────────

type geoJSONGeometry struct {
    Type        string          `json:"type"`
    Coordinates json.RawMessage `json:"coordinates"`
}

func geoJSONToKMLGeometry(raw json.RawMessage) (string, error) {
    if len(raw) == 0 || string(raw) == "null" {
        return "", nil
    }

    var g geoJSONGeometry
    if err := json.Unmarshal(raw, &g); err != nil {
        return "", err
    }

    switch g.Type {
    case "Point":
        var c []float64
        if err := json.Unmarshal(g.Coordinates, &c); err != nil {
            return "", err
        }
        return "<Point><coordinates>" + kmlCoord(c) + "</coordinates></Point>", nil

    case "LineString":
        var c [][]float64
        if err := json.Unmarshal(g.Coordinates, &c); err != nil {
            return "", err
        }
        return "<LineString><coordinates>" + kmlCoordList(c) + "</coordinates></LineString>", nil

    case "Polygon":
        var rings [][][]float64
        if err := json.Unmarshal(g.Coordinates, &rings); err != nil {
            return "", err
        }
        return kmlPolygon(rings), nil

    case "MultiPoint":
        var pts [][]float64
        if err := json.Unmarshal(g.Coordinates, &pts); err != nil {
            return "", err
        }
        var b strings.Builder
        b.WriteString("<MultiGeometry>")
        for _, p := range pts {
            b.WriteString("<Point><coordinates>" + kmlCoord(p) + "</coordinates></Point>")
        }
        b.WriteString("</MultiGeometry>")
        return b.String(), nil

    case "MultiLineString":
        var lines [][][]float64
        if err := json.Unmarshal(g.Coordinates, &lines); err != nil {
            return "", err
        }
        var b strings.Builder
        b.WriteString("<MultiGeometry>")
        for _, l := range lines {
            b.WriteString("<LineString><coordinates>" + kmlCoordList(l) + "</coordinates></LineString>")
        }
        b.WriteString("</MultiGeometry>")
        return b.String(), nil

    case "MultiPolygon":
        var polys [][][][]float64
        if err := json.Unmarshal(g.Coordinates, &polys); err != nil {
            return "", err
        }
        var b strings.Builder
        b.WriteString("<MultiGeometry>")
        for _, rings := range polys {
            b.WriteString(kmlPolygon(rings))
        }
        b.WriteString("</MultiGeometry>")
        return b.String(), nil

    default:
        // GeometryCollection and anything unrecognized — skip the feature
        // rather than risk malformed KML.
        return "", nil
    }
}

func kmlPolygon(rings [][][]float64) string {
    if len(rings) == 0 {
        return ""
    }
    var b strings.Builder
    b.WriteString("<Polygon>")
    b.WriteString("<outerBoundaryIs><LinearRing><coordinates>")
    b.WriteString(kmlCoordList(rings[0]))
    b.WriteString("</coordinates></LinearRing></outerBoundaryIs>")
    for _, hole := range rings[1:] {
        b.WriteString("<innerBoundaryIs><LinearRing><coordinates>")
        b.WriteString(kmlCoordList(hole))
        b.WriteString("</coordinates></LinearRing></innerBoundaryIs>")
    }
    b.WriteString("</Polygon>")
    return b.String()
}

func kmlCoord(c []float64) string {
    if len(c) < 2 {
        return ""
    }
    if len(c) >= 3 {
        return fmt.Sprintf("%g,%g,%g", c[0], c[1], c[2])
    }
    return fmt.Sprintf("%g,%g", c[0], c[1])
}

func kmlCoordList(coords [][]float64) string {
    parts := make([]string, 0, len(coords))
    for _, c := range coords {
        parts = append(parts, kmlCoord(c))
    }
    return strings.Join(parts, " ")
}

var xmlEscaper = strings.NewReplacer(
    "&", "&amp;",
    "<", "&lt;",
    ">", "&gt;",
    `"`, "&quot;",
    "'", "&apos;",
)

func xmlEscape(s string) string {
    return xmlEscaper.Replace(s)
}
