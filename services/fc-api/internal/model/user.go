package model

import (
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type UserProfile struct {
	bun.BaseModel `bun:"table:user_profiles,alias:u"`

	ID            uuid.UUID `bun:"id,pk,type:uuid"                  json:"id"`
	Email         string    `bun:"email,notnull"                     json:"email"`
	FullName      string    `bun:"full_name"                         json:"full_name"`
	Phone         string    `bun:"phone"                             json:"phone,omitempty"`
	AvatarURL     string    `bun:"avatar_url"                        json:"avatar_url,omitempty"`
	Role          string    `bun:"role,default:'field_worker'"       json:"role"`
	IsSystemAdmin bool      `bun:"is_system_admin,default:false"     json:"is_system_admin"`
	CreatedAt     time.Time `bun:"created_at,nullzero,default:now()" json:"created_at"`
	UpdatedAt     time.Time `bun:"updated_at,nullzero,default:now()" json:"updated_at"`
}
