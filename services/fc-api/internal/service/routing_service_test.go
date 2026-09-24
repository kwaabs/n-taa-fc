package service

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGuideRouteExtractsTurnByTurnSteps(t *testing.T) {
	// Fragment of a real OSRM response (Accra area).
	body := `{
	  "routes": [{
	    "distance": 9315.2,
	    "geometry": {"coordinates": [[-0.22,5.566],[-0.277,5.604]]},
	    "legs": [{
	      "steps": [
	        {"distance": 187.3, "name": "", "maneuver": {"type": "depart", "modifier": "right", "bearing_after": 5}},
	        {"distance": 159.8, "name": "", "maneuver": {"type": "turn", "modifier": "left", "bearing_after": 255}},
	        {"distance": 113.7, "name": "Ring Road West High Street", "maneuver": {"type": "roundabout", "modifier": "right", "bearing_after": 73}},
	        {"distance": 50, "name": "Target St", "maneuver": {"type": "arrive", "modifier": "left", "bearing_after": 0}}
	      ]
	    }]
	  }]
	}`

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("steps") != "true" {
			t.Errorf("expected steps=true, got %q", r.URL.RawQuery)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(body))
	}))
	defer srv.Close()

	rs := NewRoutingService(srv.URL)
	route, err := rs.GuideRoute(context.Background(), 5.566, -0.22, 5.604, -0.277)
	if err != nil {
		t.Fatalf("GuideRoute: %v", err)
	}
	if len(route.Steps) < 3 {
		t.Fatalf("expected at least 3 steps, got %d: %+v", len(route.Steps), route.Steps)
	}
	if route.Steps[0].Instruction == "" {
		t.Fatalf("first step missing instruction")
	}
}

func TestGuideRouteStepsJSONRoundTrip(t *testing.T) {
	route := GuideRoute{
		Steps: []GuideDirectionStep{{
			Instruction:    "Turn left onto Main St",
			DistanceMeters: 120,
			StreetName:     "Main St",
		}},
		FollowsRoads: true,
	}
	b, err := json.Marshal(route)
	if err != nil {
		t.Fatal(err)
	}
	var decoded struct {
		Steps []GuideDirectionStep `json:"steps"`
	}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatal(err)
	}
	if len(decoded.Steps) != 1 || decoded.Steps[0].Instruction == "" {
		t.Fatalf("unexpected: %+v", decoded)
	}
}
