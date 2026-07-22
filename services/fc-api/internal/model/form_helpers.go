package model

import "encoding/json"

func (f *Form) GetSchema() (*FormSchema, error) {
    var schema FormSchema
    if err := json.Unmarshal(f.Schema, &schema); err != nil {
        return nil, err
    }
    return &schema, nil
}

func (f *Form) SetSchema(schema *FormSchema) error {
    data, err := json.Marshal(schema)
    if err != nil {
        return err
    }
    f.Schema = data
    return nil
}

func (fv *FormVersion) GetSchema() (*FormSchema, error) {
    var schema FormSchema
    if err := json.Unmarshal(fv.Schema, &schema); err != nil {
        return nil, err
    }
    return &schema, nil
}

func (fv *FormVersion) SetSchema(schema *FormSchema) error {
    data, err := json.Marshal(schema)
    if err != nil {
        return err
    }
    fv.Schema = data
    return nil
}