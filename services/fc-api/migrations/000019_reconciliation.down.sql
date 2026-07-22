-- D2.1 down: drop all reconciliation tables and revert layer_data_sources additions.

DROP TABLE IF EXISTS reconciliation_log;
DROP TABLE IF EXISTS reconciliation_conflicts;
DROP TABLE IF EXISTS reconciliation_jobs;

ALTER TABLE layer_data_sources
    DROP COLUMN IF EXISTS soft_delete_value,
    DROP COLUMN IF EXISTS soft_delete_column,
    DROP COLUMN IF EXISTS delete_strategy;