package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

// TippecanoeClient talks to the tippecanoe HTTP sidecar service.
// It converts GeoJSON feature slices into .mbtiles bytes suitable for
// mobile offline map rendering.
type TippecanoeClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewTippecanoeClient creates a client pointed at the sidecar service.
// baseURL should be something like "http://tippecanoe:8080" (docker network name)
// or "http://localhost:5361" (host network).
func NewTippecanoeClient(baseURL string) *TippecanoeClient {
	return &TippecanoeClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			// Large AOI layers (100k+ features) can take a long time.
			Timeout: 30 * time.Minute,
		},
	}
}

// TileGenParams configures a single tile generation job.
type TileGenParams struct {
	MinZoom      int
	MaxZoom      int
	LayerName    string // sets --layer flag; must match what mobile uses as source-layer
	GeometryType string // "point" | "line" | "polygon" - hints tippecanoe about tuning
}

// DefaultTileParams returns sensible defaults for a reference feature layer.
func DefaultTileParams(layerName, geomType string) TileGenParams {
	return TileGenParams{
		MinZoom:      0,
		MaxZoom:      16, // sufficient for utility asset inspection (city-street level)
		LayerName:    layerName,
		GeometryType: geomType,
	}
}

// featuresForTiles keeps geometry plus tap-identifiers in tile properties.
// Full attributes stay in SQLite (reference_search index). Use plain `fc_ref`
// (not underscore-prefixed) — some MapLibre query paths omit `_`-keys.
func featuresForTiles(features []map[string]interface{}) []map[string]interface{} {
	out := make([]map[string]interface{}, len(features))
	for i, f := range features {
		props := map[string]interface{}{}
		var ref string
		if rawProps, ok := f["properties"].(map[string]interface{}); ok {
			if v := rawProps["_source_ref"]; v != nil {
				ref = fmt.Sprint(v)
			}
			if ref == "" {
				if v := rawProps["fc_ref"]; v != nil {
					ref = fmt.Sprint(v)
				}
			}
		}
		if ref == "" {
			if id, ok := f["id"]; ok && id != nil {
				ref = fmt.Sprint(id)
			}
		}
		if ref != "" {
			props["fc_ref"] = ref
			// Keep legacy key for older mobile builds.
			props["_source_ref"] = ref
		}
		tile := map[string]interface{}{
			"type":       "Feature",
			"geometry":   f["geometry"],
			"properties": props,
		}
		if id, ok := f["id"]; ok {
			tile["id"] = id
		}
		out[i] = tile
	}
	return out
}

// GenerateTiles sends minimal GeoJSON features as NDJSON to tippecanoe and returns
// .mbtiles bytes. The body is buffered with Content-Length (not chunked streaming)
// because chunked uploads to the Python sidecar were stalling mid-transfer on
// Windows/Docker for large linked-table layers.
func (c *TippecanoeClient) GenerateTiles(
	ctx context.Context,
	features []map[string]interface{},
	params TileGenParams,
) ([]byte, error) {
	if len(features) == 0 {
		return nil, fmt.Errorf("no features to tile")
	}

	url := fmt.Sprintf(
		"%s/tile?min_zoom=%d&max_zoom=%d&layer_name=%s&geometry_type=%s",
		c.baseURL, params.MinZoom, params.MaxZoom, params.LayerName, params.GeometryType,
	)

	tileFeatures := featuresForTiles(features)
	var body bytes.Buffer
	body.Grow(len(tileFeatures) * 256)
	enc := json.NewEncoder(&body)
	for i, f := range tileFeatures {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if err := enc.Encode(f); err != nil {
			return nil, fmt.Errorf("encode feature %d: %w", i, err)
		}
	}

	slog.Info("tippecanoe: generating tiles",
		"features", len(tileFeatures),
		"layer", params.LayerName,
		"zoom", fmt.Sprintf("%d-%d", params.MinZoom, params.MaxZoom),
		"ndjson_kb", body.Len()/1024,
	)

	start := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body.Bytes()))
	if err != nil {
		return nil, fmt.Errorf("tippecanoe request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-ndjson")
	req.ContentLength = int64(body.Len())

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("tippecanoe request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("tippecanoe %d: %s", resp.StatusCode, string(errBody))
	}

	mbtiles, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read mbtiles response: %w", err)
	}

	slog.Info("tippecanoe: tiles generated",
		"layer", params.LayerName,
		"mbtiles_kb", len(mbtiles)/1024,
		"duration_ms", time.Since(start).Milliseconds(),
	)

	return mbtiles, nil
}

// Health checks whether the tippecanoe sidecar is reachable.
func (c *TippecanoeClient) Health() error {
	req, err := http.NewRequest("GET", c.baseURL+"/health", nil)
	if err != nil {
		return err
	}
	// Short timeout for health checks — don't block startup for minutes
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health returned %d", resp.StatusCode)
	}
	return nil
}
