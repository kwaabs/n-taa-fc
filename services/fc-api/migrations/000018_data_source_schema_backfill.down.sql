-- D2.0 down: best-effort — remove the structured schema/table fields we added.
UPDATE layer_data_sources
SET config = config - 'schema' - 'table' - 'connection_id'
WHERE source_type = 'database';