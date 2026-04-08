-- Project-scoped infrastructure managed by DCM.
-- The DCM project object lives in SNOWFLAKE_EXAMPLE.TOOLS (shared schema)
-- so it CAN declaratively manage the project's own schema.
-- Shared objects (database, TOOLS schema, warehouse) are created
-- in the pre-hook section of deploy_dcm.sql to avoid DCM dropping them
-- if this project is removed.

DEFINE SCHEMA {{db}}.{{schema}}
    COMMENT = 'TOOL: DR/replication cost estimation agent (Expires: {{expiration_date}})';
