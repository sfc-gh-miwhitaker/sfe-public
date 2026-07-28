/*=============================================================================
  Universal Governance — Policies Follow the Data Across Engines

  Status: Mixed (see individual components below)
  Blog:   https://www.snowflake.com/en/blog/interoperable-lakehouse-architecture/

  What this does:
    Ensures governance policies defined in Horizon Catalog are enforced
    regardless of which engine queries the data — Snowflake, Spark, Trino, etc.

  Components:
    - Horizon Catalog as universal governance layer (GA for Snowflake-managed)
    - Catalog-Linked Databases (GA) — discover + access external Iceberg
    - Iceberg REST Scan Plan API (Private Preview) — enforce policies on external engines
    - Comprehensive Auditing (Private Preview) — log all engine operations
    - Snowflake Connector for Apache Spark (GA) — enforce policies for Spark TODAY
=============================================================================*/

-------------------------------------------------------------------------------
-- Part 1: Define policies once in Horizon Catalog
--   These policies will be enforced on ALL engines accessing the data.
-------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Row access policy: restrict by region
CREATE OR REPLACE ROW ACCESS POLICY region_access_policy
  AS (region_val STRING) RETURNS BOOLEAN ->
  CASE
    WHEN CURRENT_ROLE() = 'GLOBAL_ANALYST' THEN TRUE
    WHEN CURRENT_ROLE() = 'AMER_ANALYST' AND region_val = 'AMER' THEN TRUE
    WHEN CURRENT_ROLE() = 'EMEA_ANALYST' AND region_val = 'EMEA' THEN TRUE
    ELSE FALSE
  END;

-- Dynamic masking policy: mask PII for non-privileged roles
CREATE OR REPLACE MASKING POLICY email_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('DATA_STEWARD', 'COMPLIANCE_ADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '.+@', '***@')
  END;

USE ROLE SYSADMIN;

-- Apply to Iceberg table
ALTER TABLE my_db.shared_schema.customer_data
  ADD ROW ACCESS POLICY region_access_policy ON (region);

ALTER TABLE my_db.shared_schema.customer_data
  MODIFY COLUMN email SET MASKING POLICY email_mask;

-------------------------------------------------------------------------------
-- Part 2: Snowflake Connector for Apache Spark (GA)
--   The "today" answer for customers who need policy enforcement on Spark.
--   No need to wait for Scan Plan API.
--
--   How it works:
--     Spark reads via the connector → connector authenticates to Horizon →
--     Horizon evaluates policies → only permitted data returned to Spark.
--
--   Setup reference:
--     https://docs.snowflake.com/en/user-guide/spark-connector
--
--   Spark config (conceptual — actual config is in Spark, not Snowflake SQL):
--
--   spark.conf.set("sfUrl", "https://<account>.snowflakecomputing.com")
--   spark.conf.set("sfUser", "<service_user>")
--   spark.conf.set("sfRole", "AMER_ANALYST")  -- policies evaluated for this role
--   spark.conf.set("sfWarehouse", "SPARK_WH")
--
--   # Policies are enforced: AMER_ANALYST only sees AMER rows,
--   # emails are masked per the masking policy above.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Part 3: Catalog-Linked Databases (GA)
--   Discover and access ALL your external Iceberg tables from Snowflake.
--   Combined with Part 1, governance extends to externally-managed tables.
--
--   Full docs:
--     https://docs.snowflake.com/en/sql-reference/sql/create-database
--     (section: CREATE DATABASE ... FROM CATALOG INTEGRATION)
-------------------------------------------------------------------------------

-- Example: Link an external catalog (Glue, Unity, Polaris)
-- CREATE DATABASE external_lake
--   FROM CATALOG INTEGRATION = 'my_glue_integration'
--   AUTO_REFRESH = TRUE;
--
-- Tables are automatically discovered and queryable.
-- Policies defined in Horizon apply to these tables too.

-------------------------------------------------------------------------------
-- Part 4: Iceberg REST Scan Plan API (Private Preview)
--   Pushes row-access and masking policies to external engines at query time.
--   No code required on the engine side — the API handles enforcement.
--
--   When GA, this replaces the need for the Spark Connector for policy enforcement.
--   Any IRC-compatible engine gets policies enforced automatically.
--
--   No customer-facing SQL to configure — this is a platform-level capability.
--   Policies defined in Part 1 above are automatically enforced.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Part 5: Comprehensive Auditing (Private Preview)
--   All external engine operations logged in Access History.
--   Single audit trail regardless of which engine accessed the data.
--
--   Query example (available when feature is enabled):
-------------------------------------------------------------------------------

-- SELECT
--     query_start_time,
--     user_name,
--     direct_objects_accessed,
--     base_objects_accessed,
--     objects_modified
-- FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
-- WHERE source = 'EXTERNAL_ENGINE'
-- ORDER BY query_start_time DESC
-- LIMIT 20;
