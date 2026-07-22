# n-taa-fc

Shared platform that runs **Field Collector** and **geo-app (n-taa)** as separate apps on one infrastructure stack.

Parent repos (`field-collector`, `n-taa`) are left untouched — this project is a copy-based combine.

## Architecture

```
┌─────────────┐  ┌─────────────┐     ┌─────────────┐  ┌─────────────┐
│  fc-web     │  │  fc-api     │     │  geo-web    │  │  geo-api    │
│  :5356      │──│  :5355      │     │  :5357      │──│  :5442      │
└─────────────┘  └──────┬──────┘     └──────┬──────┘  └──────┬──────┘
                        │                   │                 │
                        ▼                   ▼                 ▼
              ┌─────────────────────────────────────────────────────┐
              │  Shared infra (Docker Compose)                      │
              │  Postgres+PostGIS · Valkey · RustFS · GoTrue        │
              │  Martin · Tippecanoe                                │
              └─────────────────────────────────────────────────────┘
```

| App | Auth | Schema |
|-----|------|--------|
| Field Collector | **Shared GoTrue** (`auth.*`) + JWT → `public.user_profiles` | `public.*` |
| geo-app | **Same GoTrue** + JWT → geo RBAC in `app.users` | `app.*`, `dbo.*` |

FC platform super-admins (`user_profiles.is_system_admin`) are elevated to geo `superuser` (not pending) on each geo login. Other geo users still need geo approval.

One Postgres database: **`ntaafc`**. Schemas stay separate. **One identity provider** (GoTrue, including Azure AD) for both apps.

## Layout

```
n-taa-fc/
  apps/fc-web/          Field Collector admin (Vite)
  apps/geo-web/         geo-app map UI (Vite :5357)
  services/fc-api/      Field Collector Go API
  services/geo-api/     geo-app Go API
  mobile/               Field Collector Flutter app (same GoTrue + fc-api)
  infra/                docker-compose + Martin + geo SQL
  docker/tippecanoe/    Tippecanoe HTTP wrapper
```

## Prerequisites

- Docker + Docker Compose v2
- Go 1.25+
- [Bun](https://bun.sh) (for frontends)
- Flutter (for `mobile/`)
- Android SDK `adb` (for `make mobile-run` on a device/emulator)
- `curl` (for smoke checks; optional — `make smoke` uses PowerShell)

## Quick start

```bash
cd n-taa-fc

# 1. Shared infra + FC migrations + geo SQL migrations
make setup

# 2. Start APIs (separate terminals)
make fc-api
make geo-api

# 3. Start frontends (separate terminals)
make fc-web    # http://localhost:5356
make geo-web   # http://localhost:5357

# Optional: Field Collector mobile (Flutter + ADB)
# Plug in a device (USB debugging) or start an emulator, then:
make mobile-run    # runs adb reverse, then flutter run
```

### Smoke checks

With infra + both APIs running:

```bash
make smoke
```

| Check | URL |
|-------|-----|
| FC API | http://localhost:5355/health |
| Geo API | http://localhost:5442/healthz |
| Martin | http://localhost:5360/catalog |
| GoTrue | http://localhost:5354/health |

## Ports

| Service | Port |
|---------|------|
| Postgres | 5350 |
| Valkey | 5351 |
| RustFS | 5352 / console 5353 |
| GoTrue | 5354 |
| FC API | 5355 |
| FC web | 5356 |
| Geo web | 5357 |
| Martin | 5360 |
| Tippecanoe | 5361 |
| Geo API | 5442 |

## Environment

Copy examples (also done by `make setup` / `make env-files` via `scripts/ensure-env.ps1`):

- root `.env.example` → `.env`
- `services/fc-api/.env.example` → `.env`
- `services/geo-api/.env.example` → `.env`
- `apps/fc-web/.env.example` → `.env`
- `apps/geo-web/.env.example` → `.env`

Both APIs load `.env` via godotenv when started from their service directory (`make fc-api` / `make geo-api`).

## Authentication (shared GoTrue)

Both UIs authenticate through the same GoTrue instance (`:5354`):

- Email/password via GoTrue `/token`
- Azure AD via GoTrue `/authorize?provider=azure` (compose `GOTRUE_EXTERNAL_AZURE_*`)
- JWT secret is shared: `GOTRUE_JWT_SECRET` = FC `JWT_SECRET` = geo `JWT_SECRET`

| Concern | Where it lives |
|---------|----------------|
| Identity (who) | GoTrue `auth.users` |
| FC profile | `public.user_profiles` (upserted by fc-api) |
| Geo roles (`superuser` / `editor` / `viewer`) | `app.users` (upserted by geo-api on each request) |

New geo users are created as **pending viewers** until a superuser approves them in geo admin (except `SUPERUSER_EMAIL`, which is auto-activated as superuser).

Set Azure credentials in root `.env` / compose env (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`) so GoTrue can talk to Microsoft.

## Mobile (Field Collector)

Flutter app lives in [`mobile/`](mobile/). It talks to **fc-api** (`:5355`) and GoTrue via the API’s `/gotrue` proxy — same shared auth as the web apps.

### Run on Android (ADB)

1. Start infra + `make fc-api` (and RustFS via compose for bundle/S3).
2. Connect a phone with USB debugging, or start an Android emulator.
3. From the repo root:

```bash
make mobile-run
```

That runs `adb reverse` for **5355** (FC API), **5354** (GoTrue — needed for Microsoft sign-in), **5352** / **5353** (RustFS), then `flutter pub get` + `flutter run`.

4. In the app server picker, use **`http://localhost:5355`** (Local Browser or a custom URL). With ADB reverse, device `localhost` is the host machine.

### Microsoft sign-in on mobile

Mobile uses the **same GoTrue + Azure flow as fc-web** (not a separate AppAuth client):

1. App opens `{api}/gotrue/authorize?provider=azure&redirect_to=fieldcollector://auth-callback`
2. Azure returns to GoTrue at `http://localhost:5354/callback` (must be reachable via `adb reverse`)
3. GoTrue deep-links back into the app with tokens

Requirements:

- `make adb-reverse` (includes **5354** and **5355**)
- Server URL **`http://localhost:5355`**
- Azure app registration already has `http://localhost:5354/callback` (same as web)
- Hot-restart after this change so the `fieldcollector://` intent-filter is installed

| Target | Make | Notes |
|--------|------|--------|
| Device / emulator via ADB | `make mobile-run` | Preferred; includes port reverse |
| Re-apply reverse only | `make adb-reverse` | After unplug/replug USB |
| List reverse tunnels | `make adb-reverse-status` | |
| Clear reverse tunnels | `make adb-reverse-clear` | |

Without ADB reverse, the Android emulator can still reach the host at `http://10.0.2.2:5355` (Local Emulator preset in `mobile/lib/core/server_config.dart`), but Microsoft sign-in and S3/RustFS need reverse for `:5354` / `:5352`.

## Database notes

- First Postgres boot runs [`infra/postgres/bootstrap.sql`](infra/postgres/bootstrap.sql) (creates `app`/`dbo` + role `geo_app`).
- `make migrate-up` applies Field Collector `golang-migrate` files.
- `make geo-migrate` applies Azure auth + layer permission SQL.
- GIS `dbo.*` feature tables are **not** created by bootstrap — restore a geo dump or load data separately, then `docker compose restart martin`.
- After `dbo` data is present: `make geo-seed-layers` to fill `app.layers` (+ styles) from geometry tables.
- Do **not** restore old geo `auth.*` dumps into this DB (GoTrue owns `auth`).

## Valkey / S3

- Shared Valkey; FC uses `bundle:*` keys. Any future geo cache must use another prefix (e.g. `geo:*`).
- Shared RustFS; FC bucket is `field-collector`. Add a separate bucket if geo needs object storage.

## Out of scope (v1)

- Merging the two APIs or frontends into one process
- Production Coolify cutover
- Deep data migration of live prod dumps