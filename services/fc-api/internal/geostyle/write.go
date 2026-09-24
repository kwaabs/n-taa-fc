package geostyle

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

// MapFromFC converts an FC LayerStyle into geo app.layers.style for one geometry type.
// existingRaw is merged so other geometry keys on the geo row are preserved.
func MapFromFC(fc *model.LayerStyle, geometryType string, existingRaw json.RawMessage) (json.RawMessage, error) {
	if fc == nil {
		return nil, fmt.Errorf("nil FC style")
	}
	var geo GeoStyle
	if len(existingRaw) > 0 && string(existingRaw) != "null" && string(existingRaw) != "{}" {
		_ = json.Unmarshal(existingRaw, &geo)
	}

	def := fc.Default
	switch strings.ToLower(geometryType) {
	case "point":
		pt := &GeoPointStyle{RenderAs: "symbol"}
		if geo.Point != nil {
			*pt = *geo.Point
		}
		if def.Color != "" {
			pt.Color = def.Color
		}
		if def.Size != nil && *def.Size > 0 {
			mult := *def.Size / 16
			if mult < 0.25 {
				mult = 0.25
			}
			pt.Size = &mult
		}
		if name := geoIconName(def.Icon); name != "" {
			pt.Icon = name
			pt.RenderAs = "symbol"
		}
		// Persist custom SVG only when not a shared pack icon (geo:…).
		// Resolved pack styles also carry tinted icon_svg — do not write those back.
		if strings.TrimSpace(def.IconSvg) != "" && !strings.HasPrefix(def.Icon, "geo:") {
			pt.IconSvg = def.IconSvg
			pt.RenderAs = "symbol"
			pt.Icon = ""
		} else {
			pt.IconSvg = ""
		}
		geo.Point = pt

	case "line":
		ln := &GeoLineStyle{}
		if geo.Line != nil {
			*ln = *geo.Line
		}
		if def.Color != "" {
			ln.Color = def.Color
		}
		if def.Size != nil {
			ln.Width = def.Size
		}
		switch def.LineStyle {
		case "dashed", "dotted", "dash_dot":
			ln.Dash = []float64{3, 2}
		case "solid", "":
			ln.Dash = nil
		}
		geo.Line = ln

	case "polygon":
		poly := &GeoPolygonStyle{}
		if geo.Polygon != nil {
			*poly = *geo.Polygon
		}
		if def.Color != "" {
			poly.FillColor = def.Color
		}
		if def.StrokeColor != "" {
			poly.OutlineColor = def.StrokeColor
		}
		if name := geoIconName(def.Icon); name != "" {
			c := def.Color
			poly.Centroid = &GeoPointStyle{Icon: name, Color: c, RenderAs: "symbol"}
		}
		geo.Polygon = poly

	default:
		return nil, fmt.Errorf("unsupported geometry_type %q", geometryType)
	}

	if fc.Visibility != nil {
		geo.FCVisibility = fc.Visibility
	}

	return json.Marshal(geo)
}

func geoIconName(icon string) string {
	icon = strings.TrimSpace(icon)
	if strings.HasPrefix(icon, "geo:") {
		return strings.TrimPrefix(icon, "geo:")
	}
	if _, ok := SymbolSVG(icon); ok {
		return icon
	}
	return ""
}

// UpdateAppLayerStyle writes style JSON to app.layers for schema+table.
func UpdateAppLayerStyle(ctx context.Context, db *bun.DB, schema, table string, styleJSON json.RawMessage) error {
	if db == nil || schema == "" || table == "" {
		return fmt.Errorf("missing db/schema/table")
	}
	res, err := db.NewUpdate().
		TableExpr("app.layers").
		Set("style = ?", styleJSON).
		Set("updated_at = now()").
		Where("schema_name = ? AND table_name = ?", schema, table).
		Exec(ctx)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return fmt.Errorf("no app.layers row for %s.%s", schema, table)
	}
	return nil
}

// SaveLinkedStyle maps FC style → app.layers and returns the resolved FC view.
func SaveLinkedStyle(ctx context.Context, db *bun.DB, layer *model.Layer, fc *model.LayerStyle) (*model.LayerStyle, error) {
	if layer == nil || layer.SourceType != "linked_table" {
		return nil, fmt.Errorf("not a linked_table layer")
	}
	var cfg LinkedSourceConfig
	if len(layer.SourceConfig) > 0 {
		_ = json.Unmarshal(layer.SourceConfig, &cfg)
	}
	if cfg.Schema == "" || cfg.Table == "" {
		return nil, fmt.Errorf("linked layer missing schema/table")
	}

	existing, _ := FetchAppLayerStyle(ctx, db, cfg.Schema, cfg.Table)
	geoJSON, err := MapFromFC(fc, layer.GeometryType, existing)
	if err != nil {
		return nil, err
	}
	if err := UpdateAppLayerStyle(ctx, db, cfg.Schema, cfg.Table, geoJSON); err != nil {
		return nil, err
	}
	return MapToFC(geoJSON, layer.GeometryType)
}
