-- D2.0: backfill schema and table fields in layer_data_sources.config from existing query strings.
-- Existing imports embed schema + table inside the SELECT query as FROM "schema"."table".
-- We extract them into structured config fields so the reconciliation engine has clean access.

UPDATE layer_data_sources
SET config = jsonb_set(
    jsonb_set(
        config,
        '{schema}',
        to_jsonb(substring(config->>'query' FROM 'FROM\s+"([^"]+)"\."[^"]+"'))
    ),
    '{table}',
    to_jsonb(substring(config->>'query' FROM 'FROM\s+"[^"]+"\."([^"]+)"'))
)
WHERE source_type = 'database'
  AND config ? 'query'
  AND (config->>'query') ~ 'FROM\s+"[^"]+"\."[^"]+"'
  AND (NOT (config ? 'schema') OR config->>'schema' = '' OR config->>'schema' IS NULL);