# Efficient sync hybrid

Target architecture for Field Collector at 500+ concurrent field devices.

## Goals

- Minimize download bytes (do not ship unused reference geometry by default)
- Keep upload efficient: batched `sync/push` + presigned S3 for attachments
- Scale API with replicas + load balancer; warm hot packs to avoid rebuild storms

## Download model

| Pack | Contents | When |
|------|----------|------|
| **Core pack** | Project, forms, layer catalog, choice lists, assignments | Always on prepare |
| **Reference pack (per layer)** | GeoJSON + optional mbtiles for one layer (AOI-clipped) | Working set / on demand |
| **Legacy full bundle** | Core + all published layer reference | Optional / small projects |

### Core pack API (landed)

```http
GET /api/v1/projects/{projectID}/core-pack
GET /api/v1/projects/{projectID}/core-pack/jobs/{jobID}
```

Equivalent to `GET .../bundle?reference_data=false` (layers catalog kept; no `reference_features` / `reference_tiles`).

### Reference pack API (landed)

```http
GET /api/v1/projects/{projectID}/layers/{layerID}/reference-pack
GET /api/v1/projects/{projectID}/layers/{layerID}/reference-pack/jobs/{jobID}
```

ZIP contains `reference_features/{layerId}.geojson`, optional `reference_tiles/{layerId}.mbtiles`, and `manifest.json`.

Working-set rule (product): auto-include layers on assignments + layers marked required offline; catalog may list all project layers.

### Mobile client (landed)

Default **Download for offline** on project detail:

1. `GET .../core-pack` → seed catalog/forms/assignments (no ref wipe of other projects)
2. Resolve working-set layer IDs (assignment `layer_id` if present, else all local layers)
3. For each layer: `GET .../layers/{id}/reference-pack` → merge into local DB + mbtiles

Legacy full bundle remains behind an optional toggle.

## Upload model (unchanged direction)

1. Attachments → create + presigned PUT to object storage + confirm  
2. Features → `POST .../sync/push` in batches (insert/update/delete)  
3. `sync/verify` for crash recovery  

### Upload hardening (landed)

- fc-api DB pool caps: `DB_MAX_OPEN_CONNS` (20), `DB_MAX_IDLE_CONNS` (5), `DB_CONN_MAX_LIFETIME` (30m)
- Auth profile upsert debounced via Valkey (`AUTH_PROFILE_UPSERT_TTL`, default 5m)
- Mobile sync: exponential backoff on retryable push batches (up to 3 attempts) and attachment uploads

## Capacity (runtime)

### fc-api replicas + LB (landed)

```bash
# Stop local `make fc-api` first (port 5355).
make fc-api-up    # builds image, scales 2 replicas behind Caddy :5355
make fc-api-down  # stops LB + API containers only
```

Overlay: `infra/docker-compose.fc-api.yml` + `infra/caddy/Caddyfile` (round-robin, `/health` checks, no sticky sessions).

### Warm packs (landed)

```http
POST /api/v1/projects/{projectID}/packs/warm
Authorization: Bearer <admin JWT>
Content-Type: application/json

{ "layer_ids": [] }   # optional; empty → published (else all) layers
```

Enqueues slim core (caller-scoped) + per-layer reference packs. Layer packs share Valkey hot keys across devices — use before peak shift.

### Incremental manifest (landed)

```http
GET /api/v1/projects/{projectID}/packs/manifest
```

Returns `core_hash` + per-layer `content_hash`. Mobile skips core/layer downloads when local hashes match.

### CDN for pack bytes

Point `S3_PUBLIC_ENDPOINT` (and CDN origin) at a CDN in front of RustFS/S3. Presigned download URLs use that host — no API change required. Keep `S3_ENDPOINT` as the internal origin for PUT/stat.
