package model

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type ChoiceList struct {
    bun.BaseModel `bun:"table:choice_lists,alias:cl"`

    ID        uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    ProjectID uuid.UUID       `bun:"project_id,type:uuid,notnull"              json:"project_id"`
    Name      string          `bun:"name,notnull"                               json:"name"`
    Choices   json.RawMessage `bun:"choices,type:jsonb,default:'[]'::jsonb"     json:"choices"`
    CreatedAt time.Time       `bun:"created_at,nullzero,default:now()"          json:"created_at"`
    UpdatedAt time.Time       `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`
}

func (cl *ChoiceList) GetChoices() ([]Choice, error) {
    var choices []Choice
    if err := json.Unmarshal(cl.Choices, &choices); err != nil {
        return nil, err
    }
    return choices, nil
}

func (cl *ChoiceList) SetChoices(choices []Choice) error {
    data, err := json.Marshal(choices)
    if err != nil {
        return err
    }
    cl.Choices = data
    return nil
}