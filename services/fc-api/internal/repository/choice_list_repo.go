package repository

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type ChoiceListRepo struct {
    db *bun.DB
}

func NewChoiceListRepo(db *bun.DB) *ChoiceListRepo {
    return &ChoiceListRepo{db: db}
}

func (r *ChoiceListRepo) Create(ctx context.Context, cl *model.ChoiceList) error {
    _, err := r.db.NewInsert().Model(cl).Exec(ctx)
    return err
}

func (r *ChoiceListRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.ChoiceList, error) {
    cl := new(model.ChoiceList)
    err := r.db.NewSelect().
        Model(cl).
        Where("cl.id = ?", id).
        Scan(ctx)
    return cl, err
}

func (r *ChoiceListRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.ChoiceList, error) {
    var lists []model.ChoiceList
    err := r.db.NewSelect().
        Model(&lists).
        Where("cl.project_id = ?", projectID).
        OrderExpr("cl.name ASC").
        Scan(ctx)
    return lists, err
}

func (r *ChoiceListRepo) Update(ctx context.Context, cl *model.ChoiceList) error {
    cl.UpdatedAt = time.Now()
    _, err := r.db.NewUpdate().
        Model(cl).
        WherePK().
        Column("name", "choices", "updated_at").
        Exec(ctx)
    return err
}

func (r *ChoiceListRepo) Delete(ctx context.Context, id uuid.UUID) error {
    _, err := r.db.NewDelete().
        Model((*model.ChoiceList)(nil)).
        Where("id = ?", id).
        Exec(ctx)
    return err
}