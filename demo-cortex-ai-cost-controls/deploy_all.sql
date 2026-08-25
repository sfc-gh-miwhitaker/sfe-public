-- ============================================================================
-- demo-cortex-ai-cost-controls: One-Command Deploy (SQL Data Layer)
-- Pair-programmed by SE Community + Cortex Code
--
-- Usage:
--   1. Run this script to create the SQL data layer (schema, tables, task, quota)
--   2. Deploy the React app separately: cd app && snow app setup && snow app deploy
--
-- Prerequisites:
--   - SYSADMIN + ACCOUNTADMIN roles available
--   - SNOWFLAKE database imported privileges
-- ============================================================================

-- Setup: database, warehouse, schema, grants
EXECUTE IMMEDIATE FROM 'sql/01_setup/01_create_schema.sql';

-- Materialized tables + refresh task
EXECUTE IMMEDIATE FROM 'sql/02_materialization/01_tables_and_task.sql';

-- Per-user quota example (exception-guarded; requires QUOTA_CREATOR)
EXECUTE IMMEDIATE FROM 'sql/03_quota_example/01_quota_setup.sql';

-- Done
SELECT '✓ Data layer deployed. Run "cd app && snow app setup && snow app deploy" to deploy the dashboard.' AS status;
