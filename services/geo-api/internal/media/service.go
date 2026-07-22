package media

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/features"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/layers"
)

// Config holds shared RustFS settings (same bucket as FC).
type Config struct {
	Endpoint       string
	PublicEndpoint string
	Bucket         string
	AccessKey      string
	SecretKey      string
}

type Service struct {
	db     *bun.DB
	layers *layers.Service
	feats  *features.Service
	signer *minio.Client
	bucket string
}

func NewService(db *bun.DB, layersSvc *layers.Service, featsSvc *features.Service, cfg Config) (*Service, error) {
	s := &Service{db: db, layers: layersSvc, feats: featsSvc, bucket: cfg.Bucket}
	if cfg.Bucket == "" || cfg.AccessKey == "" || cfg.SecretKey == "" {
		return s, nil // media disabled — List returns empty
	}
	endpoint := cfg.PublicEndpoint
	if endpoint == "" {
		endpoint = cfg.Endpoint
	}
	if endpoint == "" {
		return s, nil
	}
	host := strings.TrimPrefix(strings.TrimPrefix(endpoint, "http://"), "https://")
	useSSL := strings.HasPrefix(endpoint, "https://")
	client, err := minio.New(host, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: useSSL,
		Region: "us-east-1",
	})
	if err != nil {
		return nil, fmt.Errorf("init s3 signer: %w", err)
	}
	s.signer = client
	return s, nil
}

type AttachmentView struct {
	ID          string     `json:"id"`
	Kind        string     `json:"kind"`
	MimeType    string     `json:"mime_type"`
	FieldID     string     `json:"field_id"`
	SizeBytes   int64      `json:"size_bytes"`
	DownloadURL string     `json:"download_url,omitempty"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
}

// ListForFeature returns FC attachments linked to this dbo asset via source_ref.
func (s *Service) ListForFeature(ctx context.Context, layerID uuid.UUID, ogcFid int64) ([]AttachmentView, error) {
	if s.signer == nil || s.bucket == "" {
		return []AttachmentView{}, nil
	}

	layer, err := s.layers.Get(ctx, layerID)
	if err != nil {
		return nil, err
	}

	feat, err := s.feats.Get(ctx, layerID, ogcFid)
	if err != nil {
		return nil, err
	}

	var props map[string]any
	if err := json.Unmarshal(feat.Properties, &props); err != nil {
		return nil, fmt.Errorf("decode properties: %w", err)
	}

	_, refs := resolveSourceRefs(ctx, s.db, layer.SchemaName, layer.TableName, props)
	// Feature PK is stripped from properties (see projectGeomAndProps) but is
	// exactly what FC stores as source_ref after write-back — always include it.
	refs = appendUniqueRef(refs, fmt.Sprintf("%d", ogcFid))
	if len(refs) == 0 {
		return []AttachmentView{}, nil
	}

	type row struct {
		ID         uuid.UUID `bun:"id"`
		Kind       string    `bun:"kind"`
		MimeType   string    `bun:"mime_type"`
		FieldID    string    `bun:"field_id"`
		SizeBytes  int64     `bun:"size_bytes"`
		StorageKey string    `bun:"storage_key"`
	}

	var rows []row
	err = s.db.NewRaw(`
		SELECT DISTINCT ON (fa.id)
			fa.id, fa.kind, fa.mime_type, fa.field_id, fa.size_bytes, fa.storage_key
		FROM public.feature_attachments AS fa
		JOIN public.features AS f ON f.id = fa.feature_id
		LEFT JOIN public.layer_data_sources AS lds ON lds.id = f.data_source_id
		WHERE fa.status = 'uploaded'
		  AND f.source_ref IN (?)
		  AND (
		    (COALESCE(lds.config->>'schema', '') = ? AND COALESCE(lds.config->>'table', '') = ?)
		    OR COALESCE(lds.config->>'table', '') = ?
		    OR (
		      lds.id IS NULL
		      AND EXISTS (
		        SELECT 1 FROM public.layers AS fl
		        WHERE fl.id = f.layer_id
		          AND (fl.name = ? OR fl.name ILIKE ?)
		      )
		    )
		  )
		ORDER BY fa.id, fa.uploaded_at DESC NULLS LAST
	`, bun.In(refs), layer.SchemaName, layer.TableName, layer.TableName,
		layer.TableName, "%"+layer.TableName+"%",
	).Scan(ctx, &rows)
	if err != nil {
		return nil, fmt.Errorf("list fc attachments: %w", err)
	}

	out := make([]AttachmentView, 0, len(rows))
	for _, r := range rows {
		v := AttachmentView{
			ID:        r.ID.String(),
			Kind:      r.Kind,
			MimeType:  r.MimeType,
			FieldID:   r.FieldID,
			SizeBytes: r.SizeBytes,
		}
		if r.StorageKey != "" {
			expiry := time.Hour
			u, err := s.signer.PresignedGetObject(ctx, s.bucket, r.StorageKey, expiry, nil)
			if err == nil {
				v.DownloadURL = u.String()
				t := time.Now().Add(expiry)
				v.ExpiresAt = &t
			}
		}
		out = append(out, v)
	}
	return out, nil
}

func resolveSourceRefs(ctx context.Context, db *bun.DB, schema, table string, props map[string]any) (string, []string) {
	var idCol sql.NullString
	_ = db.NewRaw(`
		SELECT lds.config->>'id_column'
		FROM public.layer_data_sources AS lds
		WHERE COALESCE(lds.config->>'schema', '') = ?
		  AND COALESCE(lds.config->>'table', '') = ?
		ORDER BY lds.updated_at DESC NULLS LAST
		LIMIT 1
	`, schema, table).Scan(ctx, &idCol)

	candidates := make([]string, 0, 4)
	preferred := ""
	if idCol.Valid && strings.TrimSpace(idCol.String) != "" {
		preferred = idCol.String
		candidates = append(candidates, idCol.String)
	}
	for _, k := range []string{"objectid", "globalid", "id", "ogc_fid"} {
		candidates = append(candidates, k)
	}

	refs := make([]string, 0, 4)
	for _, col := range candidates {
		val, ok := props[col]
		if !ok {
			val, ok = props[strings.ToLower(col)]
		}
		if !ok {
			continue
		}
		ref := strings.TrimSpace(fmt.Sprint(val))
		if ref == "" || ref == "<nil>" {
			continue
		}
		refs = appendUniqueRef(refs, ref)
	}
	return preferred, refs
}

func appendUniqueRef(refs []string, ref string) []string {
	ref = strings.TrimSpace(ref)
	if ref == "" {
		return refs
	}
	for _, existing := range refs {
		if existing == ref {
			return refs
		}
	}
	return append(refs, ref)
}
