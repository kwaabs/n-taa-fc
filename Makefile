# n-taa-fc Makefile — Windows / PowerShell via explicit -ExecutionPolicy Bypass
# (GnuWin32 make does not reliably honor .SHELLFLAGS)

SHELL := cmd.exe
.SHELLFLAGS := /c

ROOT_WIN    := $(subst /,\,$(abspath $(dir $(lastword $(MAKEFILE_LIST)))))
ROOT        := $(subst \,/,$(abspath $(dir $(lastword $(MAKEFILE_LIST)))))
INFRA_DIR   := $(ROOT)/infra
FC_API      := $(ROOT)/services/fc-api
GEO_API     := $(ROOT)/services/geo-api
FC_WEB      := $(ROOT)/apps/fc-web
GEO_WEB     := $(ROOT)/apps/geo-web
MOBILE      := $(ROOT)/mobile
COMPOSE_PS1 := $(ROOT)/scripts/compose.ps1
MIGRATE_PS1 := $(ROOT)/scripts/migrate.ps1
ENSURE_PS1  := $(ROOT)/scripts/ensure-env.ps1
PS          := powershell -NoProfile -ExecutionPolicy Bypass
PWSH        := $(PS) -File

COMPOSE_ENV := $(ROOT)/.env
ifeq ($(wildcard $(COMPOSE_ENV)),)
  COMPOSE_ENV := $(ROOT)/.env.example
endif

DB_DSN      := postgres://supabase_admin:ntaafc@postgres:5432/ntaafc?sslmode=disable
DB_PASS     := ntaafc
COMPOSE_NET := n-taa-fc_default
PG_CTR      := ntaafc-postgres

.PHONY: help
help:
	@echo   n-taa-fc - shared Field Collector + geo-app platform
	@echo   ----------------------------------------------------
	@echo   help / infra-up / infra-down / infra-clean / infra-restart
	@echo   infra-logs / infra-ps / migrate-up / migrate-down / migrate-version
	@echo   geo-bootstrap / geo-migrate / env-files / setup
	@echo   fc-api / geo-api / fc-web / geo-web
	@echo   fc-api-up / fc-api-down   (replicas behind Caddy :5355)
	@echo   mobile-run / adb-reverse / adb-reverse-status / adb-reverse-clear
	@echo   smoke / psql / geo-seed-layers

.PHONY: infra-up infra-down infra-clean infra-restart infra-logs infra-ps

infra-up:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "up -d --no-build"
	@echo Infrastructure is running
	@echo   Postgres .... localhost:5350  (db=ntaafc)
	@echo   Valkey ...... localhost:5351
	@echo   RustFS ...... localhost:5352 / 5353
	@echo   GoTrue ...... localhost:5354
	@echo   FC API ...... localhost:5355  (make fc-api)
	@echo   FC web ...... localhost:5356  (make fc-web)
	@echo   Geo web ..... localhost:5357  (make geo-web)
	@echo   Martin ...... localhost:5360
	@echo   Tippecanoe .. localhost:5361
	@echo   Geo API ..... localhost:5442  (make geo-api)

infra-down:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "down"

infra-clean:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "down -v --remove-orphans"

infra-restart:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "down"
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "up -d --no-build"

infra-logs:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "logs -f --tail=100"

infra-ps:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "ps"

.PHONY: migrate-up migrate-down migrate-version geo-migrate geo-bootstrap env-files setup tippecanoe-build

tippecanoe-build:
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "build tippecanoe"

migrate-up:
	$(PWSH) "$(MIGRATE_PS1)" -Root "$(ROOT)" -Network "$(COMPOSE_NET)" -DatabaseUrl "$(DB_DSN)" -Action up
	@echo FC migrations applied

migrate-down:
	$(PWSH) "$(MIGRATE_PS1)" -Root "$(ROOT)" -Network "$(COMPOSE_NET)" -DatabaseUrl "$(DB_DSN)" -Action down
	@echo FC migrations rolled back

migrate-version:
	$(PWSH) "$(MIGRATE_PS1)" -Root "$(ROOT)" -Network "$(COMPOSE_NET)" -DatabaseUrl "$(DB_DSN)" -Action version

geo-bootstrap:
	docker exec -e PGPASSWORD=$(DB_PASS) -i $(PG_CTR) psql -U supabase_admin -d ntaafc -v ON_ERROR_STOP=1 -f /sql/bootstrap.sql
	@echo Geo bootstrap applied

geo-migrate:
	docker exec -e PGPASSWORD=$(DB_PASS) -i $(PG_CTR) psql -U supabase_admin -d ntaafc -v ON_ERROR_STOP=1 -f /sql/migrations/002_azure_auth.sql
	docker exec -e PGPASSWORD=$(DB_PASS) -i $(PG_CTR) psql -U supabase_admin -d ntaafc -v ON_ERROR_STOP=1 -f /sql/migrations/003_layer_permissions.sql
	@echo Geo migrations applied

.PHONY: geo-seed-layers
geo-seed-layers:
	docker exec -e PGPASSWORD=$(DB_PASS) -i $(PG_CTR) psql -U supabase_admin -d ntaafc -v ON_ERROR_STOP=1 -f /sql/dbo_layers_seed.sql
	docker exec -e PGPASSWORD=$(DB_PASS) -i $(PG_CTR) psql -U supabase_admin -d ntaafc -v ON_ERROR_STOP=1 -f /sql/dbo_layers_style_seed.sql
	@echo Geo layers seeded from dbo.*

env-files:
	$(PWSH) "$(ENSURE_PS1)"

setup: env-files
	-$(MAKE) tippecanoe-build
	$(MAKE) infra-up
	@echo Waiting for Postgres...
	$(PS) -Command "Start-Sleep -Seconds 8"
	$(MAKE) migrate-up
	$(MAKE) geo-migrate
	$(PWSH) "$(COMPOSE_PS1)" -ComposeFile "$(INFRA_DIR)/docker-compose.yml" -ProjectDir "$(INFRA_DIR)" -EnvFile "$(COMPOSE_ENV)" -Args "restart martin"
	@echo Setup complete.

.PHONY: fc-api geo-api fc-web geo-web mobile-run adb-reverse adb-reverse-status adb-reverse-clear tidy-fc tidy-geo fc-api-up fc-api-down

fc-api:
	cd /d "$(subst /,\,$(FC_API))" && go run ./cmd/server/main.go

# Containerized fc-api replicas behind Caddy on :5355 (stop local `make fc-api` first).
fc-api-up:
	docker compose -f "$(INFRA_DIR)/docker-compose.yml" -f "$(INFRA_DIR)/docker-compose.fc-api.yml" --env-file "$(COMPOSE_ENV)" up -d --build --scale fc-api=2

fc-api-down:
	docker compose -f "$(INFRA_DIR)/docker-compose.yml" -f "$(INFRA_DIR)/docker-compose.fc-api.yml" --env-file "$(COMPOSE_ENV)" stop fc-api fc-api-lb
	docker compose -f "$(INFRA_DIR)/docker-compose.yml" -f "$(INFRA_DIR)/docker-compose.fc-api.yml" --env-file "$(COMPOSE_ENV)" rm -f fc-api fc-api-lb

geo-api:
	cd /d "$(subst /,\,$(GEO_API))" && go run ./cmd/server/main.go

fc-web:
	cd /d "$(subst /,\,$(FC_WEB))" && bun install && bun run dev

geo-web:
	cd /d "$(subst /,\,$(GEO_WEB))" && bun install && bun run dev

# Flutter on a USB device or emulator: reverse host ports, then run.
# In the app, pick server http://localhost:5355 (Local Browser / custom).
mobile-run: adb-reverse
	cd /d "$(subst /,\,$(MOBILE))" && flutter pub get && flutter devices && flutter run

adb-reverse:
	adb reverse tcp:5352 tcp:5352
	adb reverse tcp:5353 tcp:5353
	adb reverse tcp:5354 tcp:5354
	adb reverse tcp:5355 tcp:5355
	@echo ADB reverse active - device localhost maps to host:
	@echo   5355  FC API
	@echo   5354  GoTrue (required for Microsoft sign-in callback)
	@echo   5352  RustFS S3
	@echo   5353  RustFS console
	adb reverse --list

adb-reverse-status:
	adb reverse --list

adb-reverse-clear:
	adb reverse --remove-all

tidy-fc:
	cd /d "$(subst /,\,$(FC_API))" && go mod tidy

tidy-geo:
	cd /d "$(subst /,\,$(GEO_API))" && go mod tidy

.PHONY: smoke
smoke:
	$(PS) -Command "try { Invoke-RestMethod http://localhost:5355/health | Out-Null; 'FC API OK' } catch { 'FC API DOWN' }"
	$(PS) -Command "try { Invoke-RestMethod http://localhost:5442/healthz | Out-Null; 'Geo API OK' } catch { 'Geo API DOWN' }"
	$(PS) -Command "try { Invoke-RestMethod http://localhost:5360/catalog | Out-Null; 'Martin OK' } catch { 'Martin DOWN' }"
	$(PS) -Command "try { Invoke-RestMethod http://localhost:5354/health | Out-Null; 'GoTrue OK' } catch { 'GoTrue DOWN' }"

.PHONY: psql
psql:
	docker exec -e PGPASSWORD=$(DB_PASS) -it $(PG_CTR) psql -U supabase_admin -d ntaafc
