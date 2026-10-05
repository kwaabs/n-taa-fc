package features

import (
    "encoding/json"
    "strings"
    "testing"
)

func TestGeoJSONToKMLGeometry(t *testing.T) {
    cases := []struct {
        name string
        geo  string
        want string
    }{
        {
            name: "point",
            geo:  `{"type":"Point","coordinates":[1.5,2.5]}`,
            want: "<Point><coordinates>1.5,2.5</coordinates></Point>",
        },
        {
            name: "linestring",
            geo:  `{"type":"LineString","coordinates":[[0,0],[1,1]]}`,
            want: "<LineString><coordinates>0,0 1,1</coordinates></LineString>",
        },
        {
            name: "polygon with hole",
            geo: `{"type":"Polygon","coordinates":[` +
                `[[0,0],[4,0],[4,4],[0,4],[0,0]],` +
                `[[1,1],[2,1],[2,2],[1,2],[1,1]]]}`,
            want: "<Polygon>" +
                "<outerBoundaryIs><LinearRing><coordinates>0,0 4,0 4,4 0,4 0,0</coordinates></LinearRing></outerBoundaryIs>" +
                "<innerBoundaryIs><LinearRing><coordinates>1,1 2,1 2,2 1,2 1,1</coordinates></LinearRing></innerBoundaryIs>" +
                "</Polygon>",
        },
        {
            name: "multipolygon",
            geo: `{"type":"MultiPolygon","coordinates":[` +
                `[[[0,0],[1,0],[1,1],[0,0]]],` +
                `[[[2,2],[3,2],[3,3],[2,2]]]]}`,
            want: "<MultiGeometry>" +
                "<Polygon><outerBoundaryIs><LinearRing><coordinates>0,0 1,0 1,1 0,0</coordinates></LinearRing></outerBoundaryIs></Polygon>" +
                "<Polygon><outerBoundaryIs><LinearRing><coordinates>2,2 3,2 3,3 2,2</coordinates></LinearRing></outerBoundaryIs></Polygon>" +
                "</MultiGeometry>",
        },
        {
            name: "null geometry",
            geo:  `null`,
            want: "",
        },
        {
            name: "unsupported type",
            geo:  `{"type":"GeometryCollection","geometries":[]}`,
            want: "",
        },
    }

    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got, err := geoJSONToKMLGeometry(json.RawMessage(tc.geo))
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if got != tc.want {
                t.Errorf("got:\n%s\nwant:\n%s", got, tc.want)
            }
        })
    }
}

func TestXMLEscape(t *testing.T) {
    in := `Tom & Jerry's "clip" <test>`
    want := "Tom &amp; Jerry&apos;s &quot;clip&quot; &lt;test&gt;"
    if got := xmlEscape(in); got != want {
        t.Errorf("got %q, want %q", got, want)
    }
}

func TestBuildKMLPlacemarkContainsExtendedData(t *testing.T) {
    props := map[string]any{
        "name":    "DT-001",
        "voltage": "11kV",
        "status":  "active",
    }
    geomXML := "<Point><coordinates>1,2</coordinates></Point>"
    out := buildKMLPlacemark(42, "Distribution Transformer", props, geomXML)

    for _, want := range []string{
        "<name>DT-001</name>",
        `<Data name="status"><value>active</value></Data>`,
        `<Data name="ogc_fid"><value>42</value></Data>`,
        geomXML,
    } {
        if !strings.Contains(out, want) {
            t.Errorf("placemark missing %q:\n%s", want, out)
        }
    }
}

func TestPlacemarkNameFallsBackToLayerAndID(t *testing.T) {
    props := map[string]any{"voltage": "11kV"}
    got := placemarkName(42, "Distribution Transformer", props)
    want := "Distribution Transformer #42"
    if got != want {
        t.Errorf("got %q, want %q", got, want)
    }
}
