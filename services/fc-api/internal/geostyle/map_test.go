package geostyle

import (
	"testing"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

func TestSymbolSVG(t *testing.T) {
	svg, ok := SymbolSVG("transformer")
	if !ok || !containsSVG(svg) {
		t.Fatalf("expected transformer.svg, ok=%v len=%d", ok, len(svg))
	}
	if _, ok := SymbolSVG("nope"); ok {
		t.Fatal("expected missing symbol")
	}
}

func TestMapToFCPoint(t *testing.T) {
	raw := []byte(`{"point":{"icon":"pole","color":"#ca8a04","size":1}}`)
	style, err := MapToFC(raw, "point")
	if err != nil {
		t.Fatal(err)
	}
	if style.Default.Color != "#ca8a04" {
		t.Fatalf("color: %s", style.Default.Color)
	}
	if style.Default.IconSvg == "" {
		t.Fatal("expected icon_svg")
	}
	if style.Default.Icon != "geo:pole" {
		t.Fatalf("icon: %q", style.Default.Icon)
	}
}

func TestMapFromFCRoundTrip(t *testing.T) {
	fc := &model.LayerStyle{
		Default: model.StyleProps{
			Icon:  "geo:transformer",
			Color: "#dc2626",
		},
	}
	sz := 16.0
	fc.Default.Size = &sz
	geoJSON, err := MapFromFC(fc, "point", nil)
	if err != nil {
		t.Fatal(err)
	}
	back, err := MapToFC(geoJSON, "point")
	if err != nil {
		t.Fatal(err)
	}
	if back.Default.Icon != "geo:transformer" {
		t.Fatalf("icon: %q", back.Default.Icon)
	}
	if back.Default.Color != "#dc2626" {
		t.Fatalf("color: %q", back.Default.Color)
	}
}

func TestMapToFCLineDash(t *testing.T) {
	raw := []byte(`{"line":{"color":"#2563eb","width":2,"dash":[3,2]}}`)
	style, err := MapToFC(raw, "line")
	if err != nil {
		t.Fatal(err)
	}
	if style.Default.LineStyle != "dashed" {
		t.Fatalf("line_style: %s", style.Default.LineStyle)
	}
	if style.Default.Color != "#2563eb" {
		t.Fatalf("color: %s", style.Default.Color)
	}
	if style.Default.Size == nil || *style.Default.Size != 2 {
		t.Fatalf("size: %v", style.Default.Size)
	}
}

func containsSVG(s string) bool {
	return len(s) > 4 && (s[0] == '<' || s[1] == 's')
}
