package service

import (
	"bytes"
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
			Timeout: 5 * time.Minute, // large layers can take a while
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

// GenerateTiles pipes GeoJSON features to tippecanoe and returns .mbtiles bytes.
// features should be a slice of standard GeoJSON Feature dicts.
// Returns an error if the sidecar is unreachable or tippecanoe fails.
func (c *TippecanoeClient) GenerateTiles(features []map[string]interface{}, params TileGenParams) ([]byte, error) {
	if len(features) == 0 {
		return nil, fmt.Errorf("no features to tile")
	}

	// Encode features as newline-delimited JSON — tippecanoe reads this efficiently
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	for _, f := range features {
		if err := enc.Encode(f); err != nil {
			return nil, fmt.Errorf("encode feature: %w", err)
		}
	}

	url := fmt.Sprintf(
		"%s/tile?min_zoom=%d&max_zoom=%d&layer_name=%s&geometry_type=%s",
		c.baseURL, params.MinZoom, params.MaxZoom, params.LayerName, params.GeometryType,
	)

	slog.Info("tippecanoe: generating tiles",
		"features", len(features),
		"layer", params.LayerName,
		"zoom", fmt.Sprintf("%d-%d", params.MinZoom, params.MaxZoom),
		"size_kb", buf.Len()/1024,
	)

	start := time.Now()
	resp, err := c.httpClient.Post(url, "application/json", &buf)
	if err != nil {
		return nil, fmt.Errorf("tippecanoe request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(resp.Body)
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
