package service

import (
    "context"
    "encoding/json"
    "fmt"
    "regexp"
    "strings"

    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type ValidationError struct {
    FieldID string `json:"field_id"`
    Message string `json:"message"`
}

type ValidationService struct {
    formRepo *repository.FormRepo
}

func NewValidationService(formRepo *repository.FormRepo) *ValidationService {
    return &ValidationService{formRepo: formRepo}
}

func (v *ValidationService) ValidateFormSchema(schema *model.FormSchema) []ValidationError {
    var errors []ValidationError
    seen := make(map[string]bool)
    for _, field := range schema.Fields {
        errors = append(errors, v.validateSchemaField(field, seen)...)
    }
    return errors
}

func (v *ValidationService) validateSchemaField(field model.FormField, seen map[string]bool) []ValidationError {
    var errors []ValidationError

    if field.ID == "" {
        errors = append(errors, ValidationError{FieldID: "(empty)", Message: "field ID is required"})
        return errors
    }
    if seen[field.ID] {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: "duplicate field ID"})
    }
    seen[field.ID] = true

    if !model.ValidFieldTypes[field.Type] {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: fmt.Sprintf("invalid field type: %s", field.Type)})
    }
    if len(field.Label) == 0 {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: "label is required"})
    }

    if field.Type == model.FieldTypeSelectOne || field.Type == model.FieldTypeSelectMultiple {
        if len(field.Choices) == 0 && field.ChoiceListID == nil {
            errors = append(errors, ValidationError{FieldID: field.ID, Message: "select fields must have choices or a choice_list_id"})
        }
        for i, choice := range field.Choices {
            if choice.Value == "" {
                errors = append(errors, ValidationError{FieldID: field.ID, Message: fmt.Sprintf("choice[%d] has empty value", i)})
            }
        }
    }

    if field.Type == model.FieldTypeGroup || field.Type == model.FieldTypeRepeat {
        if len(field.Children) == 0 {
            errors = append(errors, ValidationError{FieldID: field.ID, Message: fmt.Sprintf("%s fields must have children", field.Type)})
        }
        for _, child := range field.Children {
            errors = append(errors, v.validateSchemaField(child, seen)...)
        }
    }

    if field.Type == model.FieldTypeCalculation && field.Calculation == "" {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: "calculation fields must have a calculation expression"})
    }

    return errors
}

func (v *ValidationService) ValidateAttributes(ctx context.Context, formID uuid.UUID, formVersion int, attributes json.RawMessage) []ValidationError {
    var errors []ValidationError
    var schema *model.FormSchema
    var err error

    if formVersion > 0 {
        fv, findErr := v.formRepo.FindVersionByFormAndVersion(ctx, formID, formVersion)
        if findErr != nil {
            errors = append(errors, ValidationError{FieldID: "_form", Message: fmt.Sprintf("form version %d not found", formVersion)})
            return errors
        }
        schema, err = fv.GetSchema()
    } else {
        form, findErr := v.formRepo.FindByID(ctx, formID)
        if findErr != nil {
            errors = append(errors, ValidationError{FieldID: "_form", Message: "form not found"})
            return errors
        }
        schema, err = form.GetSchema()
    }

    if err != nil {
        errors = append(errors, ValidationError{FieldID: "_form", Message: "failed to parse form schema"})
        return errors
    }

    var attrs map[string]interface{}
    if err := json.Unmarshal(attributes, &attrs); err != nil {
        errors = append(errors, ValidationError{FieldID: "_attributes", Message: "invalid JSON attributes"})
        return errors
    }

    for _, field := range schema.Fields {
        errors = append(errors, v.validateField(field, attrs)...)
    }
    return errors
}

func (v *ValidationService) validateField(field model.FormField, attrs map[string]interface{}) []ValidationError {
    var errors []ValidationError

    if field.Type == model.FieldTypeNote || field.Type == model.FieldTypeGroup {
        if field.Type == model.FieldTypeGroup {
            for _, child := range field.Children {
                errors = append(errors, v.validateField(child, attrs)...)
            }
        }
        return errors
    }

    value, exists := attrs[field.ID]

    if field.Required && (!exists || value == nil || value == "") {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: "required field missing"})
        return errors
    }
    if !exists || value == nil {
        return errors
    }

    if typeErr := isValidType(value, field.Type); typeErr != "" {
        errors = append(errors, ValidationError{FieldID: field.ID, Message: typeErr})
        return errors
    }

    if field.Type == model.FieldTypePhoto || field.Type == model.FieldTypeAudio {
        c := field.Constraints
        if c == nil {
            c = &model.FieldConstraints{}
        }
        errors = append(errors, checkMediaCountConstraints(field.ID, value, c)...)
    } else if field.Constraints != nil {
        errors = append(errors, checkConstraints(field.ID, value, field.Constraints)...)
    }

    if field.Type == model.FieldTypeRepeat {
        if arr, ok := value.([]interface{}); ok {
            for i, item := range arr {
                if row, ok := item.(map[string]interface{}); ok {
                    for _, child := range field.Children {
                        childErrors := v.validateField(child, row)
                        for _, ce := range childErrors {
                            ce.FieldID = fmt.Sprintf("%s[%d].%s", field.ID, i, ce.FieldID)
                            errors = append(errors, ce)
                        }
                    }
                }
            }
        }
    }

    return errors
}

func isValidType(value interface{}, fieldType model.FieldType) string {
    switch fieldType {
    case model.FieldTypeText, model.FieldTypeDate, model.FieldTypeDatetime,
        model.FieldTypeTime, model.FieldTypeBarcode, model.FieldTypeSelectOne,
        model.FieldTypeCalculation:
        if _, ok := value.(string); !ok {
            return fmt.Sprintf("expected string for %s, got %T", fieldType, value)
        }
    case model.FieldTypeInteger:
        switch v := value.(type) {
        case float64:
            if v != float64(int64(v)) {
                return "expected integer, got decimal"
            }
        case json.Number:
            if _, err := v.Int64(); err != nil {
                return "expected integer"
            }
        default:
            return fmt.Sprintf("expected number for integer, got %T", value)
        }
    case model.FieldTypeDecimal:
        switch value.(type) {
        case float64, json.Number:
        default:
            return fmt.Sprintf("expected number for decimal, got %T", value)
        }
    case model.FieldTypeSelectMultiple:
        arr, ok := value.([]interface{})
        if !ok {
            return fmt.Sprintf("expected array for select_multiple, got %T", value)
        }
        for _, item := range arr {
            if _, ok := item.(string); !ok {
                return "select_multiple values must be strings"
            }
        }
    case model.FieldTypeGeopoint, model.FieldTypeGeotrace, model.FieldTypeGeoshape:
        switch value.(type) {
        case map[string]interface{}, string:
        default:
            return fmt.Sprintf("expected GeoJSON object or string for %s", fieldType)
        }
    case model.FieldTypePhoto, model.FieldTypeAudio:
        switch value.(type) {
        case string, []interface{}:
        default:
            return fmt.Sprintf("expected string or array for %s", fieldType)
        }
    case model.FieldTypeRepeat:
        if _, ok := value.([]interface{}); !ok {
            return "expected array for repeat"
        }
    }
    return ""
}

func checkConstraints(fieldID string, value interface{}, c *model.FieldConstraints) []ValidationError {
    var errors []ValidationError

    if c.Min != nil || c.Max != nil {
        var num float64
        switch v := value.(type) {
        case float64:
            num = v
        case json.Number:
            if f, err := v.Float64(); err == nil {
                num = f
            }
        }
        if c.Min != nil && num < *c.Min {
            errors = append(errors, ValidationError{FieldID: fieldID, Message: fmt.Sprintf("value must be >= %v", *c.Min)})
        }
        if c.Max != nil && num > *c.Max {
            errors = append(errors, ValidationError{FieldID: fieldID, Message: fmt.Sprintf("value must be <= %v", *c.Max)})
        }
    }

    if str, ok := value.(string); ok {
        if c.MinLength != nil && len(strings.TrimSpace(str)) < *c.MinLength {
            errors = append(errors, ValidationError{FieldID: fieldID, Message: fmt.Sprintf("minimum length is %d", *c.MinLength)})
        }
        if c.MaxLength != nil && len(str) > *c.MaxLength {
            errors = append(errors, ValidationError{FieldID: fieldID, Message: fmt.Sprintf("maximum length is %d", *c.MaxLength)})
        }
        if c.Pattern != "" {
            if matched, err := regexp.MatchString(c.Pattern, str); err == nil && !matched {
                msg := "value does not match required pattern"
                if errMsg, ok := c.Message["en"]; ok {
                    msg = errMsg
                }
                errors = append(errors, ValidationError{FieldID: fieldID, Message: msg})
            }
        }
    }

    return errors
}

// checkMediaCountConstraints treats max_length/min_length as attachment counts
// for photo/audio fields (values like "att:id1,id2" or string/array lists).
func checkMediaCountConstraints(fieldID string, value interface{}, c *model.FieldConstraints) []ValidationError {
    var errors []ValidationError
    count := mediaAttachmentCount(value)
    if c.MinLength != nil && count < *c.MinLength {
        errors = append(errors, ValidationError{
            FieldID: fieldID,
            Message: fmt.Sprintf("minimum %d attachment(s) required", *c.MinLength),
        })
    }
    maxAllowed := 10
    if c.MaxLength != nil {
        maxAllowed = *c.MaxLength
        if maxAllowed > 10 {
            maxAllowed = 10
        }
        if maxAllowed < 1 {
            maxAllowed = 1
        }
    }
    if count > maxAllowed {
        errors = append(errors, ValidationError{
            FieldID: fieldID,
            Message: fmt.Sprintf("maximum %d attachment(s) allowed", maxAllowed),
        })
    }
    return errors
}

func mediaAttachmentCount(value interface{}) int {
    switch v := value.(type) {
    case []interface{}:
        n := 0
        for _, item := range v {
            if s, ok := item.(string); ok && strings.TrimSpace(s) != "" {
                n++
            }
        }
        return n
    case string:
        s := strings.TrimSpace(v)
        if s == "" {
            return 0
        }
        if strings.HasPrefix(s, "att:") {
            parts := strings.Split(s[4:], ",")
            n := 0
            for _, p := range parts {
                if strings.TrimSpace(p) != "" {
                    n++
                }
            }
            return n
        }
        // Preview / comma-separated filenames
        parts := strings.Split(s, ",")
        n := 0
        for _, p := range parts {
            if strings.TrimSpace(p) != "" {
                n++
            }
        }
        return n
    default:
        return 0
    }
}