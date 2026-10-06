/*
  Snowflake ML Lifecycle — ML Lineage audit queries (read-only)
  Pair-programmed by SE Community + Cortex Code

  Requires Enterprise Edition and: GRANT VIEW LINEAGE ON ACCOUNT TO ROLE <role>;
  Domains: feature views are 'TABLE' (they are dynamic tables or views), datasets are
  'DATASET', models are 'MODULE'. There is no FEATURE_VIEW domain.
  Lineage is not replicated, and model -> prediction-table edges are not captured.
*/

-- 1. What trained this model version? (upstream: dataset -> feature views -> source tables)
SELECT
    distance,
    source_object_domain,
    source_object_database || '.' || source_object_schema || '.' || source_object_name AS source_object,
    source_object_version,
    target_object_domain,
    target_object_name
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
    'ML_DB.ML.CHURN_MODEL', 'MODULE', 'UPSTREAM', 5, 'V1'))
ORDER BY distance;

-- 2. Impact analysis: which datasets and models depend on this source table?
SELECT
    distance,
    target_object_domain,
    target_object_database || '.' || target_object_schema || '.' || target_object_name AS dependent_object,
    target_object_version
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
    'ML_DB.RAW.CUSTOMER_EVENTS', 'TABLE', 'DOWNSTREAM', 5))
WHERE target_object_domain IN ('DATASET', 'MODULE')
ORDER BY distance;

-- 3. Registry inventory for the audit pack: every model and version in the schema
SHOW VERSIONS IN MODEL ML_DB.ML.CHURN_MODEL;
