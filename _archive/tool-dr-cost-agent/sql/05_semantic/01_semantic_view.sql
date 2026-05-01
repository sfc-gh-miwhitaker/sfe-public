/******************************************************************************
 * DR Cost Agent - Semantic View
 * Powers the Cortex Analyst tool inside the SI agent.
 * Location: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST
 ******************************************************************************/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST

  COMMENT = 'TOOL: DR replication cost estimation semantic view (Expires: 2026-05-01)'

  TABLES (
    pricing AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT
      PRIMARY KEY (SERVICE_TYPE, CLOUD, REGION, UNIT)
      WITH SYNONYMS = ('rates', 'pricing rates', 'cost rates')
      COMMENT = 'Replication pricing rates by service type, cloud, and region (Business Critical baseline)',

    databases AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DB_METADATA_V2
      PRIMARY KEY (DATABASE_NAME)
      WITH SYNONYMS = ('database sizes', 'database metadata', 'db sizes')
      COMMENT = 'Per-database storage sizes with hybrid table exclusions. Sourced from ACCOUNT_USAGE TABLE_STORAGE_METRICS (up to 3-hour latency). Check DATA_STALENESS_HOURS for freshness.',

    hybrid_tables AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.HYBRID_TABLE_METADATA
      PRIMARY KEY (DATABASE_NAME, TABLE_SCHEMA, TABLE_NAME)
      WITH SYNONYMS = ('hybrid table inventory', 'hybrid table details')
      COMMENT = 'Individual hybrid tables -- these are SKIPPED during replication refresh',

    repl_history AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.REPLICATION_HISTORY
      PRIMARY KEY (REPLICATION_GROUP_ID, START_TIME)
      WITH SYNONYMS = ('replication costs', 'actual replication usage', 'replication history')
      COMMENT = 'Actual replication credits and bytes from ACCOUNT_USAGE. Returns ZERO ROWS if no replication/failover groups are configured. Up to 3-hour latency.'
  )

  RELATIONSHIPS (
    hybrid_to_databases AS
      hybrid_tables (DATABASE_NAME) REFERENCES databases
  )

  DIMENSIONS (
    pricing.cloud AS pricing.CLOUD
      WITH SYNONYMS = ('cloud provider', 'CSP')
      COMMENT = 'Cloud provider: AWS, AZURE, or GCP',

    pricing.region AS pricing.REGION
      WITH SYNONYMS = ('cloud region', 'destination region')
      COMMENT = 'Cloud region identifier (e.g. us-east-1, eastus2, us-central1)',

    pricing.service_type AS pricing.SERVICE_TYPE
      WITH SYNONYMS = ('cost component', 'service category')
      COMMENT = 'Cost category: DATA_TRANSFER, REPLICATION_COMPUTE, STORAGE_TB_MONTH, SERVERLESS_MAINT, HYBRID_STORAGE',

    databases.database_name AS databases.DATABASE_NAME
      WITH SYNONYMS = ('database', 'db name')
      COMMENT = 'Snowflake database name',

    databases.has_hybrid_tables AS databases.HAS_HYBRID_TABLES
      COMMENT = 'TRUE if the database contains hybrid tables that are SILENTLY SKIPPED during replication refresh (BCR-1560-1582)',

    repl_history.replication_group_name AS repl_history.REPLICATION_GROUP_NAME
      WITH SYNONYMS = ('replication group', 'failover group')
      COMMENT = 'Name of the replication or failover group',

    repl_history.usage_date AS repl_history.USAGE_DATE
      COMMENT = 'Date of replication usage',

    repl_history.usage_month AS repl_history.USAGE_MONTH
      COMMENT = 'Month of replication usage'
  )

  FACTS (
    pricing.rate AS pricing.RATE
      COMMENT = 'Cost rate in credits per unit',

    databases.total_size_tb AS databases.TOTAL_SIZE_TB
      COMMENT = 'Total database size in TB including hybrid tables',

    databases.replicable_size_tb AS databases.REPLICABLE_SIZE_TB
      COMMENT = 'Size in TB that will actually be replicated (excludes hybrid tables)',

    databases.hybrid_excluded_tb AS databases.HYBRID_EXCLUDED_TB
      COMMENT = 'Hybrid table storage in TB excluded from replication',

    databases.hybrid_table_count AS databases.HYBRID_TABLE_COUNT
      COMMENT = 'Number of hybrid tables in the database',

    databases.data_staleness_hours AS databases.DATA_STALENESS_HOURS
      COMMENT = 'Hours since ACCOUNT_USAGE storage data was last refreshed. Values over 3 indicate stale data.',

    hybrid_tables.size_gb AS hybrid_tables.SIZE_GB
      COMMENT = 'Individual hybrid table size in GB',

    repl_history.credits_used AS repl_history.CREDITS_USED
      COMMENT = 'Actual credits consumed for replication in the time window',

    repl_history.tb_transferred AS repl_history.TB_TRANSFERRED
      COMMENT = 'Actual TB transferred for replication in the time window'
  )

  METRICS (
    databases.total_replicable_tb AS SUM(databases.REPLICABLE_SIZE_TB)
      COMMENT = 'Sum of replicable storage across selected databases (excludes hybrid tables)',

    databases.total_hybrid_excluded_tb AS SUM(databases.HYBRID_EXCLUDED_TB)
      COMMENT = 'Sum of hybrid table storage excluded from replication',

    databases.database_count AS COUNT(databases.DATABASE_NAME)
      COMMENT = 'Number of databases',

    databases.databases_with_hybrid AS COUNT_IF(databases.HAS_HYBRID_TABLES)
      COMMENT = 'Number of databases containing hybrid tables',

    repl_history.total_credits AS SUM(repl_history.CREDITS_USED)
      COMMENT = 'Total replication credits consumed',

    repl_history.total_tb_transferred AS SUM(repl_history.TB_TRANSFERRED)
      COMMENT = 'Total TB transferred for replication',

    pricing.avg_rate AS AVG(pricing.RATE)
      COMMENT = 'Average rate across pricing entries'
  );
