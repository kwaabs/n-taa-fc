package model

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
)

// LayerStyle is the JSON spec for layer rendering.
type LayerStyle struct {
	Default    StyleProps  `json:"default"`
	Rules      []StyleRule `json:"rules,omitempty"`
	Label      *LabelSpec  `json:"label,omitempty"`
	Visibility *Visibility `json:"visibility,omitempty"`
}

// StyleProps holds visual properties. All fields optional inside a rule.
type StyleProps struct {
	Icon          string   `json:"icon,omitempty"`  // "lucide:water_drop" or "custom:<id>"
	Color         string   `json:"color,omitempty"` // hex
	Size          *float64 `json:"size,omitempty"`  // pixels
	StrokeColor   string   `json:"stroke_color,omitempty"`
	StrokeWidth   *float64 `json:"stroke_width,omitempty"`
	Opacity       *float64 `json:"opacity,omitempty"`        // 0-1
	StrokeOpacity *float64 `json:"stroke_opacity,omitempty"` // 0-1
	LineStyle     string   `json:"line_style,omitempty"`     // solid|dashed|dotted|dash_dot
	IconSvg       string   `json:"icon_svg,omitempty"`       // raw SVG for point markers
}

// StyleRule is a conditional style override.
type StyleRule struct {
	ID    string     `json:"id"`
	Name  string     `json:"name,omitempty"`
	When  RuleClause `json:"when"`
	Style StyleProps `json:"style"`
}

// RuleClause defines a condition: field op value, or a logical combination.
type RuleClause struct {
	Field string      `json:"field,omitempty"`
	Op    string      `json:"op,omitempty"`
	Value interface{} `json:"value,omitempty"`

	// Logical operators for combining clauses
	And []RuleClause `json:"and,omitempty"`
	Or  []RuleClause `json:"or,omitempty"`
}

// LabelSpec defines text labels for features.
type LabelSpec struct {
	Field     string   `json:"field"`
	Color     string   `json:"color,omitempty"`
	HaloColor string   `json:"halo_color,omitempty"`
	HaloWidth *float64 `json:"halo_width,omitempty"`
	Size      *float64 `json:"size,omitempty"`
	MinZoom   *float64 `json:"min_zoom,omitempty"`
	MaxZoom   *float64 `json:"max_zoom,omitempty"`
}

// Visibility controls when the layer is visible.
type Visibility struct {
	MinZoom          *float64 `json:"min_zoom,omitempty"`
	MaxZoom          *float64 `json:"max_zoom,omitempty"`
	VisibleByDefault *bool    `json:"visible_by_default,omitempty"`
}

// ValidOperators are the supported comparison operators.
var ValidOperators = map[string]bool{
	"eq": true, "neq": true,
	"gt": true, "lt": true, "gte": true, "lte": true,
	"in": true, "not_in": true,
	"contains": true,
	"is_null":  true, "is_not_null": true,
}

var hexColorRegex = regexp.MustCompile(`^#[0-9a-fA-F]{6}$|^#[0-9a-fA-F]{8}$`)

// Validate checks the style spec for correctness.
func (s *LayerStyle) Validate() error {
	if err := s.Default.Validate(); err != nil {
		return fmt.Errorf("default: %w", err)
	}
	seenIDs := map[string]bool{}
	for i, rule := range s.Rules {
		if rule.ID == "" {
			return fmt.Errorf("rule[%d]: id is required", i)
		}
		if seenIDs[rule.ID] {
			return fmt.Errorf("rule[%d]: duplicate id '%s'", i, rule.ID)
		}
		seenIDs[rule.ID] = true
		if err := rule.When.Validate(); err != nil {
			return fmt.Errorf("rule[%d] (%s): %w", i, rule.ID, err)
		}
		if err := rule.Style.Validate(); err != nil {
			return fmt.Errorf("rule[%d] (%s) style: %w", i, rule.ID, err)
		}
	}
	if s.Label != nil && s.Label.Field == "" {
		return fmt.Errorf("label: field is required when label section is present")
	}
	return nil
}

func (p *StyleProps) Validate() error {
	if p.Color != "" && !hexColorRegex.MatchString(p.Color) {
		return fmt.Errorf("color must be hex (#RRGGBB or #RRGGBBAA), got %q", p.Color)
	}
	if p.StrokeColor != "" && !hexColorRegex.MatchString(p.StrokeColor) {
		return fmt.Errorf("stroke_color must be hex, got %q", p.StrokeColor)
	}
	if p.Opacity != nil && (*p.Opacity < 0 || *p.Opacity > 1) {
		return fmt.Errorf("opacity must be 0-1, got %v", *p.Opacity)
	}
	if p.StrokeOpacity != nil && (*p.StrokeOpacity < 0 || *p.StrokeOpacity > 1) {
		return fmt.Errorf("stroke_opacity must be 0-1, got %v", *p.StrokeOpacity)
	}
	if p.Size != nil && *p.Size < 0 {
		return fmt.Errorf("size must be >= 0")
	}
	if p.StrokeWidth != nil && *p.StrokeWidth < 0 {
		return fmt.Errorf("stroke_width must be >= 0")
	}
	if p.Icon != "" {
		if !regexp.MustCompile(`^(lucide|custom|geo):[\w-]+$`).MatchString(p.Icon) {
			return fmt.Errorf("icon must match 'lucide:name', 'custom:id', or 'geo:name', got %q", p.Icon)
		}
	}
    if p.IconSvg != "" {
		if len(p.IconSvg) > 50000 {
			return fmt.Errorf("icon_svg too large (max 50KB)")
		}
		lower := strings.ToLower(strings.TrimSpace(p.IconSvg))
		if !strings.HasPrefix(lower, "<svg") {
			return fmt.Errorf("icon_svg must be an <svg> element")
		}
		for _, bad := range []string{
			"<script", "</script", "<foreignobject",
			"javascript:", "onload=", "onclick=", "onerror=",
			"onmouseover=", "onmouseenter=", "onfocus=", "onblur=",
		} {
			if strings.Contains(lower, bad) {
				return fmt.Errorf("icon_svg contains disallowed content")
			}
		}
	}
	if p.LineStyle != "" {
		switch p.LineStyle {
		case "solid", "dashed", "dotted", "dash_dot":
			// valid
		default:
			return fmt.Errorf(
				"line_style must be solid|dashed|dotted|dash_dot, got %q",
				p.LineStyle)
		}
	}
	return nil
}

func (c *RuleClause) Validate() error {
	hasField := c.Field != ""
	hasAnd := len(c.And) > 0
	hasOr := len(c.Or) > 0

	count := 0
	if hasField {
		count++
	}
	if hasAnd {
		count++
	}
	if hasOr {
		count++
	}
	if count == 0 {
		return fmt.Errorf("clause must have field+op OR and/or")
	}
	if count > 1 {
		return fmt.Errorf("clause cannot mix field+op with and/or")
	}

	if hasField {
		if !ValidOperators[c.Op] {
			return fmt.Errorf("invalid operator %q", c.Op)
		}
		// Operators that don't need value
		noValueOps := map[string]bool{"is_null": true, "is_not_null": true}
		if !noValueOps[c.Op] && c.Value == nil {
			return fmt.Errorf("operator %q requires a value", c.Op)
		}
	}

	for i, sub := range c.And {
		if err := sub.Validate(); err != nil {
			return fmt.Errorf("and[%d]: %w", i, err)
		}
	}
	for i, sub := range c.Or {
		if err := sub.Validate(); err != nil {
			return fmt.Errorf("or[%d]: %w", i, err)
		}
	}
	return nil
}

// DefaultStyle returns a baseline style for a new layer.
func DefaultStyle(geometryType string) *LayerStyle {
	size := 14.0
	strokeWidth := 2.0
	opacity := 1.0

	style := &LayerStyle{
		Default: StyleProps{
			Color:       "#3b82f6",
			Size:        &size,
			StrokeColor: "#ffffff",
			StrokeWidth: &strokeWidth,
			Opacity:     &opacity,
		},
		Visibility: &Visibility{
			VisibleByDefault: boolPtr(true),
		},
	}

	switch geometryType {
	case "point":
		style.Default.Icon = "lucide:map-pin"
	case "line":
		lineSize := 3.0
		style.Default.Size = &lineSize
	case "polygon":
		fillOp := 0.3
		style.Default.Opacity = &fillOp
	}
	return style
}

func boolPtr(b bool) *bool { return &b }

// MarshalToRaw serializes the style to json.RawMessage.
func (s *LayerStyle) MarshalToRaw() (json.RawMessage, error) {
	return json.Marshal(s)
}

// UnmarshalStyle parses a JSON raw message into a LayerStyle.
func UnmarshalStyle(raw json.RawMessage) (*LayerStyle, error) {
	if len(raw) == 0 || string(raw) == "null" || string(raw) == "{}" {
		return nil, nil
	}
	style := &LayerStyle{}
	if err := json.Unmarshal(raw, style); err != nil {
		return nil, err
	}
	return style, nil
}
