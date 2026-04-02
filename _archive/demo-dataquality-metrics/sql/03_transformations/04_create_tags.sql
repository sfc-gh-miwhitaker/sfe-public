-- ============================================================================
-- Script: sql/03_transformations/04_create_tags.sql
-- Purpose: Create governance tags, assign to tables/columns, and add
--          a tag-based masking policy for CONFIDENTIAL columns.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY tags, masking policy, and view.
-- Deps: RAW tables, STG table, and curated views exist.
-- ============================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;

-- ============================================================================
-- STEP 0: Idempotency — unset masking policy from tag so re-runs succeed
--         (a tag cannot be replaced while a policy is attached)
-- ============================================================================

EXECUTE IMMEDIATE $$
BEGIN
  ALTER TAG DATA_SENSITIVITY UNSET MASKING POLICY CONFIDENTIAL_STRING_MASK;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

EXECUTE IMMEDIATE $$
BEGIN
  DROP MASKING POLICY CONFIDENTIAL_STRING_MASK;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

-- ============================================================================
-- STEP 1: Create governance tags with constrained allowed values
-- ============================================================================

CREATE OR REPLACE TAG DATA_DOMAIN
  ALLOWED_VALUES 'PERFORMANCE', 'ENGAGEMENT', 'QUALITY_METRICS'
  COMMENT = 'DEMO: Business domain classification for tables and columns (Expires: 2026-05-01)';

CREATE OR REPLACE TAG DATA_SENSITIVITY
  ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL'
  COMMENT = 'DEMO: Column-level sensitivity classification (Expires: 2026-05-01)';

CREATE OR REPLACE TAG DATA_QUALITY_TIER
  ALLOWED_VALUES 'RAW', 'VALIDATED', 'CURATED'
  COMMENT = 'DEMO: Data quality tier for tables and views (Expires: 2026-05-01)';

-- ============================================================================
-- STEP 2: Assign tags to tables (domain + quality tier)
-- ============================================================================

ALTER TABLE RAW_ATHLETE_PERFORMANCE SET TAG
  DATA_DOMAIN = 'PERFORMANCE',
  DATA_QUALITY_TIER = 'RAW';

ALTER TABLE RAW_FAN_ENGAGEMENT SET TAG
  DATA_DOMAIN = 'ENGAGEMENT',
  DATA_QUALITY_TIER = 'RAW';

ALTER TABLE STG_DATA_QUALITY_METRICS SET TAG
  DATA_DOMAIN = 'QUALITY_METRICS',
  DATA_QUALITY_TIER = 'VALIDATED';

ALTER VIEW V_ATHLETE_PERFORMANCE SET TAG
  DATA_DOMAIN = 'PERFORMANCE',
  DATA_QUALITY_TIER = 'CURATED';

ALTER VIEW V_FAN_ENGAGEMENT SET TAG
  DATA_DOMAIN = 'ENGAGEMENT',
  DATA_QUALITY_TIER = 'CURATED';

-- ============================================================================
-- STEP 3: Assign sensitivity tags to columns
-- ============================================================================

-- CONFIDENTIAL: identifier columns that could link to real individuals
ALTER TABLE RAW_ATHLETE_PERFORMANCE ALTER COLUMN athlete_id SET TAG DATA_SENSITIVITY = 'CONFIDENTIAL';
ALTER TABLE RAW_FAN_ENGAGEMENT     ALTER COLUMN fan_id      SET TAG DATA_SENSITIVITY = 'CONFIDENTIAL';

-- INTERNAL: metric/measurement columns with business-sensitive values
ALTER TABLE RAW_ATHLETE_PERFORMANCE ALTER COLUMN metric_value      SET TAG DATA_SENSITIVITY = 'INTERNAL';
ALTER TABLE RAW_FAN_ENGAGEMENT     ALTER COLUMN session_duration   SET TAG DATA_SENSITIVITY = 'INTERNAL';

-- PUBLIC: dimensional/categorical columns safe for broad access
ALTER TABLE RAW_ATHLETE_PERFORMANCE ALTER COLUMN sport        SET TAG DATA_SENSITIVITY = 'PUBLIC';
ALTER TABLE RAW_ATHLETE_PERFORMANCE ALTER COLUMN ngb_code     SET TAG DATA_SENSITIVITY = 'PUBLIC';
ALTER TABLE RAW_ATHLETE_PERFORMANCE ALTER COLUMN data_source  SET TAG DATA_SENSITIVITY = 'PUBLIC';
ALTER TABLE RAW_FAN_ENGAGEMENT     ALTER COLUMN channel       SET TAG DATA_SENSITIVITY = 'PUBLIC';
ALTER TABLE RAW_FAN_ENGAGEMENT     ALTER COLUMN event_type    SET TAG DATA_SENSITIVITY = 'PUBLIC';

-- ============================================================================
-- STEP 4: Tag-based masking policy (protects CONFIDENTIAL columns)
--
-- Any VARCHAR column tagged DATA_SENSITIVITY = 'CONFIDENTIAL' is masked
-- for roles other than ACCOUNTADMIN. Because the policy is assigned to
-- the tag (not individual columns), new CONFIDENTIAL columns are
-- protected automatically.
-- ============================================================================

CREATE OR REPLACE MASKING POLICY CONFIDENTIAL_STRING_MASK AS (val STRING)
RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('ACCOUNTADMIN') THEN val
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('DATA_QUALITY.DATA_SENSITIVITY') = 'CONFIDENTIAL'
      THEN '***MASKED***'
    ELSE val
  END
COMMENT = 'DEMO: Masks VARCHAR columns tagged CONFIDENTIAL for non-admin roles (Expires: 2026-05-01)';

ALTER TAG DATA_SENSITIVITY SET MASKING POLICY CONFIDENTIAL_STRING_MASK;

-- ============================================================================
-- STEP 5: Governance summary view (queries TAG_REFERENCES)
-- ============================================================================

CREATE OR REPLACE VIEW V_TAG_GOVERNANCE_SUMMARY
  COMMENT = 'DEMO: All tag assignments across DATA_QUALITY objects (Expires: 2026-05-01)'
AS
WITH table_tags AS (
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE', 'TABLE'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_FAN_ENGAGEMENT', 'TABLE'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.STG_DATA_QUALITY_METRICS', 'TABLE'))
),
view_tags AS (
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.V_ATHLETE_PERFORMANCE', 'TABLE'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.V_FAN_ENGAGEMENT', 'TABLE'))
),
column_tags AS (
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.ATHLETE_ID', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_FAN_ENGAGEMENT.FAN_ID', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.METRIC_VALUE', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_FAN_ENGAGEMENT.SESSION_DURATION', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.SPORT', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.NGB_CODE', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.DATA_SOURCE', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_FAN_ENGAGEMENT.CHANNEL', 'COLUMN'))
  UNION ALL
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_FAN_ENGAGEMENT.EVENT_TYPE', 'COLUMN'))
)
SELECT
  TAG_NAME,
  TAG_VALUE,
  OBJECT_NAME,
  DOMAIN,
  COLUMN_NAME,
  LEVEL
FROM table_tags
UNION ALL
SELECT
  TAG_NAME,
  TAG_VALUE,
  OBJECT_NAME,
  DOMAIN,
  COLUMN_NAME,
  LEVEL
FROM view_tags
UNION ALL
SELECT
  TAG_NAME,
  TAG_VALUE,
  OBJECT_NAME,
  DOMAIN,
  COLUMN_NAME,
  LEVEL
FROM column_tags;
