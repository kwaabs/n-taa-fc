package geostyle

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

// GeoStyle is the geometry-keyed style stored on app.layers.style.
type GeoStyle struct {
	Point   *GeoPointStyle   `json:"point,omitempty"`
	Line    *GeoLineStyle    `json:"line,omitempty"`
	Polygon *GeoPolygonStyle `json:"polygon,omitempty"`
}

type GeoPointStyle struct {
	Icon     string   `json:"icon,omitempty"`
	Size     *float64 `json:"size,omitempty"`
	Color    string   `json:"color,omitempty"`
	RenderAs string   `json:"render_as,omitempty"`
}

type GeoLineStyle struct {
	Color string    `json:"color,omitempty"`
	Width *float64  `json:"width,omitempty"`
	Dash  []float64 `json:"dash,omitempty"`
}

type GeoPolygonStyle struct {
	FillColor    string          `json:"fill_color,omitempty"`
	OutlineColor string          `json:"outline_color,omitempty"`
	Centroid     *GeoPointStyle  `json:"centroid,omitempty"`
}

type appLayerRow struct {
	Style json.RawMessage `bun:"style"`
}

// FetchAppLayerStyle loads app.layers.style for a dbo table (schema+table).
func FetchAppLayerStyle(ctx context.Context, db *bun.DB, schema, table string) (json.RawMessage, error) {
	if db == nil || schema == "" || table == "" {
		return nil, fmt.Errorf("missing db/schema/table")
	}
	var row appLayerRow
	err := db.NewSelect().
		TableExpr("app.layers").
		Column("style").
		Where("schema_name = ? AND table_name = ?", schema, table).
		Scan(ctx, &row)
	if err != nil {
		return nil, err
	}
	return row.Style, nil
}

// MapToFC converts geo style JSON into an FC LayerStyle for the given geometry type.
// Unknown / empty geo style returns nil (caller should keep DefaultStyle).
func MapToFC(raw json.RawMessage, geometryType string) (*model.LayerStyle, error) {
	if len(raw) == 0 || string(raw) == "null" || string(raw) == "{}" {
		return nil, nil
	}
	var geo GeoStyle
	if err := json.Unmarshal(raw, &geo); err != nil {
		return nil, fmt.Errorf("parse geo style: %w", err)
	}

	out := model.DefaultStyle(geometryType)
	if out == nil {
		out = &model.LayerStyle{}
	}

	switch strings.ToLower(geometryType) {
	case "point":
		if geo.Point == nil {
			return out, nil
		}
		applyPoint(out, geo.Point)
	case "line":
		if geo.Line == nil {
			return out, nil
		}
		applyLine(out, geo.Line)
	case "polygon":
		if geo.Polygon == nil {
			return out, nil
		}
		applyPolygon(out, geo.Polygon)
	default:
		// Prefer point, then line, then polygon if present.
		if geo.Point != nil {
			applyPoint(out, geo.Point)
		} else if geo.Line != nil {
			applyLine(out, geo.Line)
		} else if geo.Polygon != nil {
			applyPolygon(out, geo.Polygon)
		}
	}
	return out, nil
}

func applyPoint(out *model.LayerStyle, p *GeoPointStyle) {
	if p.Color != "" {
		out.Default.Color = p.Color
	}
	if p.Size != nil {
		// Geo size is a multiplier (~1); FC uses pixels.
		px := *p.Size * 16
		if px < 10 {
			px = 14
		}
		out.Default.Size = &px
	}
	if p.Icon != "" {
		if svg, ok := SymbolSVG(p.Icon); ok {
			out.Default.IconSvg = tintSVG(svg, p.Color)
			out.Default.Icon = "geo:" + p.Icon
		}
	}
}

// tintSVG rewrites black fills/strokes to the layer color so FC rasters match geo tinting.
func tintSVG(svg, color string) string {
	if color == "" {
		color = "#3b82f6"
	}
	out := svg
	for _, old := range []string{
		`fill="black"`, `fill="#000"`, `fill="#000000"`, `fill="Black"`,
		`stroke="black"`, `stroke="#000"`, `stroke="#000000"`,
	} {
		repl := "fill"
		if strings.HasPrefix(old, "stroke") {
			repl = "stroke"
		}
		out = strings.ReplaceAll(out, old, fmt.Sprintf(`%s="%s"`, repl, color))
	}
	// case-insensitive black via currentColor-style already handled by geo assets
	out = strings.ReplaceAll(out, `fill="currentColor"`, fmt.Sprintf(`fill="%s"`, color))
	out = strings.ReplaceAll(out, `stroke="currentColor"`, fmt.Sprintf(`stroke="%s"`, color))
	return out
}

func applyLine(out *model.LayerStyle, l *GeoLineStyle) {
	if l.Color != "" {
		out.Default.Color = l.Color
	}
	if l.Width != nil {
		w := *l.Width
		out.Default.Size = &w
	}
	if len(l.Dash) > 0 {
		out.Default.LineStyle = "dashed"
	} else {
		out.Default.LineStyle = "solid"
	}
}

func applyPolygon(out *model.LayerStyle, p *GeoPolygonStyle) {
	if p.FillColor != "" {
		out.Default.Color = p.FillColor
	}
	if p.OutlineColor != "" {
		out.Default.StrokeColor = p.OutlineColor
	}
	if p.Centroid != nil && p.Centroid.Icon != "" {
		if svg, ok := SymbolSVG(p.Centroid.Icon); ok {
			c := p.Centroid.Color
			if c == "" {
				c = p.FillColor
			}
			out.Default.IconSvg = tintSVG(svg, c)
		}
	}
}

// LinkedSourceConfig is the subset of FC source_config used for geo lookup.
type LinkedSourceConfig struct {
	Schema string `json:"schema"`
	Table  string `json:"table"`
}

// ResolveLayerStyle returns FC style for a layer, live-resolving from app.layers
// when source_type is linked_table.
func ResolveLayerStyle(ctx context.Context, db *bun.DB, layer *model.Layer) (*model.LayerStyle, error) {
	if layer == nil {
		return model.DefaultStyle("point"), nil
	}
	fallback := func() *model.LayerStyle {
		style, err := model.UnmarshalStyle(layer.Style)
		if err != nil || style == nil {
			return model.DefaultStyle(layer.GeometryType)
		}
		return style
	}

	if layer.SourceType != "linked_table" || db == nil {
		return fallback(), nil
	}

	var cfg LinkedSourceConfig
	if len(layer.SourceConfig) > 0 {
		_ = json.Unmarshal(layer.SourceConfig, &cfg)
	}
	if cfg.Schema == "" || cfg.Table == "" {
		return fallback(), nil
	}

	raw, err := FetchAppLayerStyle(ctx, db, cfg.Schema, cfg.Table)
	if err != nil {
		// No matching geo layer — keep FC stored style / default.
		return fallback(), nil
	}
	mapped, err := MapToFC(raw, layer.GeometryType)
	if err != nil || mapped == nil {
		return fallback(), nil
	}
	return mapped, nil
}

// ApplyResolvedStyleJSON sets layer.Style to the live-resolved geo style (in memory).
func ApplyResolvedStyleJSON(ctx context.Context, db *bun.DB, layer *model.Layer) error {
	style, err := ResolveLayerStyle(ctx, db, layer)
	if err != nil {
		return err
	}
	raw, err := style.MarshalToRaw()
	if err != nil {
		return err
	}
	layer.Style = raw
	return nil
}
