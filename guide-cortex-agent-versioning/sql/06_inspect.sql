-- =============================================================================
-- 06_inspect.sql — See exactly what each version contains
-- Pair-programmed by SE Community + Cortex Code
--
-- DESCRIBE AGENT is convenient but LIES about LIVE once you have committed
-- versions: it resolves to the DEFAULT version's spec, not LIVE. To read a
-- SPECIFIC version's spec verbatim, read its file from the versioned stage.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- --- The version inventory ----------------------------------------------------
SHOW VERSIONS IN AGENT ORDERS_AGENT;

-- --- What DESCRIBE resolves to (DEFAULT once committed versions exist) --------
DESCRIBE AGENT ORDERS_AGENT;

-- Pull specific columns out of the DESCRIBE result (output names are lowercase).
SELECT "name", "default_version_name", "versions", "aliases"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- --- Read ANY version's spec verbatim from its stage -------------------------
-- The <version> segment accepts: live, version$N, or an alias
-- (uppercase unless the alias was created double-quoted).

-- List files that make up a version.
LIST snow://agent/ORDERS_AGENT/versions/version$2/;

-- Reconstruct VERSION$2's agent_spec.yaml as a single text value.
SELECT LISTAGG(RTRIM($1), '\n') WITHIN GROUP (ORDER BY METADATA$FILE_ROW_NUMBER)
         AS agent_specification
FROM snow://agent/ORDERS_AGENT/versions/version$2/agent_spec.yaml
WHERE TRIM($1) <> '';

-- Do the same for the production alias (proves what is actually serving prod).
LIST snow://agent/ORDERS_AGENT/versions/PRODUCTION/;

-- Round-trip to Git: GET a version's spec to a local file, then commit it.
-- GET snow://agent/ORDERS_AGENT/versions/version$2/agent_spec.yaml file:///tmp/;
