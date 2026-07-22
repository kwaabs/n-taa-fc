ALTER TABLE features DROP CONSTRAINT IF EXISTS fk_features_data_source;

DROP TABLE IF EXISTS layer_data_sources;

DROP INDEX IF EXISTS idx_features_deleted_at;
DROP INDEX IF EXISTS idx_features_source_ref;
DROP INDEX IF EXISTS idx_features_data_source;
DROP INDEX IF EXISTS idx_features_change_type;
DROP INDEX IF EXISTS idx_features_source;

ALTER TABLE features
    DROP COLUMN IF EXISTS deleted_at,
    DROP COLUMN IF EXISTS original_geometry,
    DROP COLUMN IF EXISTS original_attributes,
    DROP COLUMN IF EXISTS change_by,
    DROP COLUMN IF EXISTS change_at,
    DROP COLUMN IF EXISTS change_type,
    DROP COLUMN IF EXISTS data_source_id,
    DROP COLUMN IF EXISTS source_ref,
    DROP COLUMN IF EXISTS source;