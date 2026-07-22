package model

import "encoding/json"

// LocalizedString maps locale codes to translated strings.
// Example: {"en": "Water Source", "fr": "Source d'Eau"}
type LocalizedString map[string]string

// FieldType defines the type of a form field.
type FieldType string

const (
    FieldTypeText           FieldType = "text"
    FieldTypeInteger        FieldType = "integer"
    FieldTypeDecimal        FieldType = "decimal"
    FieldTypeSelectOne      FieldType = "select_one"
    FieldTypeSelectMultiple FieldType = "select_multiple"
    FieldTypeDate           FieldType = "date"
    FieldTypeDatetime       FieldType = "datetime"
    FieldTypeTime           FieldType = "time"
    FieldTypeGeopoint       FieldType = "geopoint"
    FieldTypeGeotrace       FieldType = "geotrace"
    FieldTypeGeoshape       FieldType = "geoshape"
    FieldTypePhoto          FieldType = "photo"
    FieldTypeAudio          FieldType = "audio"
    FieldTypeBarcode        FieldType = "barcode"
    FieldTypeNote           FieldType = "note"
    FieldTypeGroup          FieldType = "group"
    FieldTypeRepeat         FieldType = "repeat"
    FieldTypeCalculation    FieldType = "calculation"
)

// ValidFieldTypes is the set of all valid field types for validation.
var ValidFieldTypes = map[FieldType]bool{
    FieldTypeText: true, FieldTypeInteger: true, FieldTypeDecimal: true,
    FieldTypeSelectOne: true, FieldTypeSelectMultiple: true,
    FieldTypeDate: true, FieldTypeDatetime: true, FieldTypeTime: true,
    FieldTypeGeopoint: true, FieldTypeGeotrace: true, FieldTypeGeoshape: true,
    FieldTypePhoto: true, FieldTypeAudio: true, FieldTypeBarcode: true,
    FieldTypeNote: true, FieldTypeGroup: true, FieldTypeRepeat: true,
    FieldTypeCalculation: true,
}

// FormSchema is the top-level schema definition for a form.
type FormSchema struct {
    Fields   []FormField   `json:"fields"`
    Settings *FormSettings `json:"settings,omitempty"`
}

// FormField defines a single field in a form.
type FormField struct {
    ID          string          `json:"id"`
    Type        FieldType       `json:"type"`
    Label       LocalizedString `json:"label"`
    Description LocalizedString `json:"description,omitempty"`
    Appearance  string          `json:"appearance,omitempty"`
    Required    bool            `json:"required,omitempty"`
    Default     interface{}     `json:"default,omitempty"`
    Relevant    string          `json:"relevant,omitempty"`
    Constraints *FieldConstraints `json:"constraints,omitempty"`
    ChoiceListID *string  `json:"choice_list_id,omitempty"`
    Choices      []Choice `json:"choices,omitempty"`
    Children []FormField `json:"children,omitempty"`
    Calculation string `json:"calculation,omitempty"`
    Properties json.RawMessage `json:"properties,omitempty"`
}

// FieldConstraints defines validation constraints for a field.
type FieldConstraints struct {
    Min       *float64        `json:"min,omitempty"`
    Max       *float64        `json:"max,omitempty"`
    MinLength *int            `json:"min_length,omitempty"`
    MaxLength *int            `json:"max_length,omitempty"`
    Pattern   string          `json:"pattern,omitempty"`
    Message   LocalizedString `json:"message,omitempty"`
}

// Choice represents a single option in a select field.
type Choice struct {
    Value string          `json:"value"`
    Label LocalizedString `json:"label"`
}

// FormSettings contains form-level configuration.
type FormSettings struct {
    DefaultLanguage    string   `json:"default_language,omitempty"`
    Languages          []string `json:"languages,omitempty"`
    SubmissionWorkflow []string `json:"submission_workflow,omitempty"`
}