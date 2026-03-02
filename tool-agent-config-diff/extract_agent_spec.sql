-- =============================================================================
-- Extract Cortex Agent Specification for Configuration Management
-- =============================================================================
-- Author: SE Community
-- Purpose: Reliably extract agent specs for comparison and version control
--
-- DESCRIBE AGENT Output Columns (per Snowflake docs):
--   name, database_name, schema_name, owner, comment, profile, agent_spec, created_on
--
-- Note: agent_spec is returned as YAML text, not JSON
--
-- IMPORTANT: This script uses session variables and RESULT_SCAN which require
-- an interactive session (Snowsight, SnowSQL, or Snowflake connector with
-- session persistence). It will NOT work with stateless SQL API calls.
--
-- For programmatic access, see extract_agent_spec.py in this directory.
-- =============================================================================

-- =============================================================================
-- Configuration - modify these for your agent
-- =============================================================================
SET agent_fqn = 'SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN';
SET output_format = 'export';  -- Options: 'full', 'spec_only', 'export'

-- =============================================================================
-- Extract agent metadata (single DESC call)
-- =============================================================================
DESC AGENT IDENTIFIER($agent_fqn);

CREATE OR REPLACE TEMPORARY TABLE _agent_desc AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Option 1: Full Agent Metadata (output_format = 'full')
-- Recommended for config management - includes all fields with validation
-- =============================================================================
SELECT
    "name" AS agent_name,
    "database_name" || '.' || "schema_name" || '.' || "name" AS agent_fqn,
    "owner",
    "comment",
    TRY_PARSE_JSON("profile") AS profile_json,
    IFF(TRY_PARSE_JSON("profile") IS NULL AND "profile" IS NOT NULL,
        'INVALID_JSON', 'OK') AS profile_status,
    "agent_spec" AS spec_yaml,
    "created_on",
    MD5(COALESCE("agent_spec", '') || COALESCE("profile", '')) AS config_hash
FROM _agent_desc
WHERE $output_format = 'full';

-- =============================================================================
-- Option 2: Spec YAML Only (output_format = 'spec_only')
-- Minimal output for diff/comparison tools
-- =============================================================================
SELECT
    "agent_spec" AS spec_yaml,
    MD5(COALESCE("agent_spec", '')) AS spec_hash
FROM _agent_desc
WHERE $output_format = 'spec_only';

-- =============================================================================
-- Option 3: Export-Ready Format (output_format = 'export')
-- Single JSON document with all config data for version control
-- =============================================================================
SELECT OBJECT_CONSTRUCT(
    'extracted_at', TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'agent_fqn', "database_name" || '.' || "schema_name" || '.' || "name",
    'config_hash', MD5(COALESCE("agent_spec", '') || COALESCE("profile", '')),
    'metadata', OBJECT_CONSTRUCT_KEEP_NULL(
        'name', "name",
        'database', "database_name",
        'schema', "schema_name",
        'owner', "owner",
        'comment', "comment",
        'created_on', "created_on"
    ),
    'profile', TRY_PARSE_JSON("profile"),
    'profile_valid', TRY_PARSE_JSON("profile") IS NOT NULL OR "profile" IS NULL,
    'spec_yaml', "agent_spec"
) AS agent_config_export
FROM _agent_desc
WHERE $output_format = 'export';

-- =============================================================================
-- Cleanup
-- =============================================================================
DROP TABLE IF EXISTS _agent_desc;

-- =============================================================================
-- Utility: List All Agents in a Schema
-- =============================================================================
-- SHOW AGENTS IN SCHEMA SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN;
