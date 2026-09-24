package service

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// RoutingService proxies guide routes to an OSRM-compatible HTTP API.
type RoutingService struct {
	osrmBase   string
	httpClient *http.Client
}

func NewRoutingService(osrmBase string) *RoutingService {
	base := strings.TrimRight(strings.TrimSpace(osrmBase), "/")
	if base == "" {
		base = "https://router.project-osrm.org"
	}
	return &RoutingService{
		osrmBase: base,
		httpClient: &http.Client{
			Timeout: 25 * time.Second,
		},
	}
}

// GuideRoutePoint is one vertex of a guide polyline.
type GuideRoutePoint struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// GuideDirectionStep is one turn-by-turn line for the mobile guide card.
type GuideDirectionStep struct {
	Instruction    string  `json:"instruction"`
	DistanceMeters float64 `json:"distance_meters"`
	StreetName     string  `json:"street_name,omitempty"`
}

// GuideRoute is returned to mobile clients for map guidance.
type GuideRoute struct {
	Geometry       []GuideRoutePoint    `json:"geometry"`
	DistanceMeters float64              `json:"distance_meters"`
	FollowsRoads   bool                 `json:"follows_roads"`
	Steps          []GuideDirectionStep `json:"steps"`
}

func (s *RoutingService) GuideRoute(
	ctx context.Context,
	fromLat, fromLng, toLat, toLng float64,
) (*GuideRoute, error) {
	if fromLat < -90 || fromLat > 90 || toLat < -90 || toLat > 90 {
		return nil, fmt.Errorf("latitude out of range")
	}
	if fromLng < -180 || fromLng > 180 || toLng < -180 || toLng > 180 {
		return nil, fmt.Errorf("longitude out of range")
	}

	path := fmt.Sprintf(
		"%s/route/v1/driving/%f,%f;%f,%f",
		s.osrmBase,
		fromLng, fromLat,
		toLng, toLat,
	)
	reqURL := path + "?overview=full&geometries=geojson&steps=true"

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "fc-api-routing/1.0")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("routing upstream status %d", resp.StatusCode)
	}

	var parsed struct {
		Routes []struct {
			Distance float64 `json:"distance"`
			Geometry struct {
				Coordinates [][]float64 `json:"coordinates"`
			} `json:"geometry"`
			Legs []struct {
				Steps []struct {
					Distance float64 `json:"distance"`
					Name     string  `json:"name"`
					Maneuver struct {
						Type     string  `json:"type"`
						Modifier string  `json:"modifier"`
						Bearing  float64 `json:"bearing_after"`
					} `json:"maneuver"`
				} `json:"steps"`
			} `json:"legs"`
		} `json:"routes"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, fmt.Errorf("parse routing response: %w", err)
	}
	if len(parsed.Routes) == 0 {
		return nil, fmt.Errorf("no routes in response")
	}
	r0 := parsed.Routes[0]
	coords := r0.Geometry.Coordinates
	if len(coords) < 2 {
		return nil, fmt.Errorf("route geometry too short")
	}

	pts := make([]GuideRoutePoint, 0, len(coords))
	for _, c := range coords {
		if len(c) < 2 {
			continue
		}
		pts = append(pts, GuideRoutePoint{Lat: c[1], Lng: c[0]})
	}
	if len(pts) < 2 {
		return nil, fmt.Errorf("route geometry empty")
	}

	steps := make([]GuideDirectionStep, 0, 16)
	for _, leg := range r0.Legs {
		for _, st := range leg.Steps {
			instr := formatOSRMStep(
				st.Maneuver.Type,
				st.Maneuver.Modifier,
				st.Name,
				st.Maneuver.Bearing,
			)
			if instr == "" {
				continue
			}
			if st.Distance < 3 && st.Maneuver.Type != "depart" && st.Maneuver.Type != "arrive" {
				continue
			}
			steps = append(steps, GuideDirectionStep{
				Instruction:    instr,
				DistanceMeters: st.Distance,
				StreetName:     st.Name,
			})
		}
	}

	if len(steps) == 0 {
		steps = []GuideDirectionStep{{
			Instruction:    fmt.Sprintf("Follow the highlighted road route (%.1f km)", r0.Distance/1000),
			DistanceMeters: r0.Distance,
		}}
	}

	return &GuideRoute{
		Geometry:       pts,
		DistanceMeters: r0.Distance,
		FollowsRoads:   true,
		Steps:          steps,
	}, nil
}

func formatOSRMStep(mType, modifier, street string, bearingAfter float64) string {
	street = strings.TrimSpace(street)
	road := street
	if road == "" {
		road = "the road"
	}
	mod := strings.ReplaceAll(strings.TrimSpace(modifier), "_", " ")

	switch mType {
	case "depart":
		if mod != "" {
			return fmt.Sprintf("Head %s", mod)
		}
		if bearingAfter > 0 {
			return fmt.Sprintf("Head %s", bearingToCompass(bearingAfter))
		}
		return "Start on " + road
	case "arrive":
		return "Arrive at destination"
	case "turn":
		if mod == "" {
			return fmt.Sprintf("Turn onto %s", road)
		}
		return fmt.Sprintf("Turn %s onto %s", mod, road)
	case "new name":
		return fmt.Sprintf("Continue on %s", road)
	case "continue":
		return fmt.Sprintf("Continue on %s", road)
	case "merge":
		return fmt.Sprintf("Merge %s", mod)
	case "fork":
		if mod == "" {
			return fmt.Sprintf("Take the fork onto %s", road)
		}
		return fmt.Sprintf("At the fork, keep %s onto %s", mod, road)
	case "end of road":
		if mod == "" {
			return fmt.Sprintf("At the end of the road, continue on %s", road)
		}
		return fmt.Sprintf("At the end of the road, turn %s onto %s", mod, road)
	case "roundabout", "rotary":
		return fmt.Sprintf("Enter the roundabout and take the exit onto %s", road)
	case "roundabout turn":
		return fmt.Sprintf("At the roundabout, turn %s onto %s", mod, road)
	case "on ramp":
		return fmt.Sprintf("Take the ramp %s onto %s", mod, road)
	case "off ramp":
		return fmt.Sprintf("Take the exit %s onto %s", mod, road)
	default:
		if street != "" {
			return fmt.Sprintf("Continue on %s", road)
		}
		return ""
	}
}

func bearingToCompass(bearing float64) string {
	labels := []string{"north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"}
	idx := int((bearing+22.5)/45.0) % 8
	if idx < 0 {
		idx += 8
	}
	return labels[idx]
}
