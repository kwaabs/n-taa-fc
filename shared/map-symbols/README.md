# Shared map symbols (SVG)

Canonical artwork for geo-web sprites and FC linked-layer `icon_svg` resolution.

- Edit files here.
- Run `make sync-symbols` to copy into `services/fc-api/internal/geostyle/symbols/` (go:embed).
- geo-web imports via Vite alias `@map-symbols`.

Layer colors / which icon name to use live in `app.layers.style` (DB), not in these files.
