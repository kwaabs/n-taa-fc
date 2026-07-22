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

## Capacity (later phases)

- fc-api replicas behind OSS LB (JWT, no sticky sessions)
- DB pool caps; warm core + hot layer packs before peak
- Incremental manifests + CDN for pack bytes
