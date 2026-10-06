/*
  guide-shopify-multistore-snowflake — sql/shared/03_monitoring.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    The monitoring that is identical on both paths, because it reads only the
    shared registry and the two published contract views:

      A. Per-store freshness, with an actionable status label
      B. Registry hygiene: registered-but-never-loaded, active-but-unqualified
      C. Contract conformance
      D. Cutover reconciliation against the incumbent baseline

    Path-specific monitoring lives beside its implementation:
      sql/openflow/07_monitoring.sql  compute-pool credits, event-table errors
      sql/native/06_monitoring.sql    run log, task history, per-store credits

  PREREQUISITE
    One path deployed, so SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY and
    V_STORE_FRESHNESS exist.

  RUN AS      SHOPIFY_CONTROL_ADMIN
  LATENCY     Reads Dynamic Tables and base tables; no ACCOUNT_USAGE lag here.
*/

USE ROLE SHOPIFY_CONTROL_ADMIN;

-- A. Per-store freshness -------------------------------------------------------
--    Thresholds assume a daily sync. NEVER LOADED is deliberately separated
--    from STALE: they have different fixes.
SELECT
  STORE_KEY,
  SHOP_DOMAIN,
  BUSINESS_OWNER,
  ORDERS_LOADED,
  LAST_ORDER_UPDATE,
  HOURS_SINCE_LAST_UPDATE,
  CASE
    WHEN ORDERS_LOADED = 0            THEN 'NEVER LOADED - extraction has never succeeded for this store'
    WHEN HOURS_SINCE_LAST_UPDATE > 48 THEN 'STALE - two or more daily cycles missed'
    WHEN HOURS_SINCE_LAST_UPDATE > 30 THEN 'LATE - one daily cycle missed'
    ELSE 'OK'
  END AS FRESHNESS_STATUS
FROM SHOPIFY_CONTROL.META.V_STORE_FRESHNESS
ORDER BY ORDERS_LOADED = 0 DESC, HOURS_SINCE_LAST_UPDATE DESC NULLS FIRST;

-- B. Registry hygiene ----------------------------------------------------------
--    Every row returned here is a discrepancy between intent and reality.
SELECT
  R.STORE_KEY,
  R.SHOP_DOMAIN,
  R.IS_ACTIVE,
  R.QUALIFICATION_STATUS,
  R.LAST_QUALIFIED_AT,
  R.CONNECTOR_INSTALLED_AT,
  R.CREDENTIAL_OBJECT_FQN,
  CASE
    WHEN R.IS_ACTIVE AND R.QUALIFICATION_STATUS <> 'PASSED'
      THEN 'ACTIVE WITHOUT QUALIFICATION - promotion gate was bypassed'
    WHEN NOT R.IS_ACTIVE AND R.QUALIFICATION_STATUS = 'PASSED'
      THEN 'QUALIFIED BUT NOT ACTIVE - promotion never completed'
    WHEN R.QUALIFICATION_STATUS = 'PASSED'
     AND R.LAST_QUALIFIED_AT < DATEADD('day', -90, CURRENT_TIMESTAMP())
      THEN 'QUALIFICATION STALE - re-qualify after 90 days or an API version bump'
    ELSE 'OK'
  END AS REGISTRY_STATUS
FROM SHOPIFY_CONTROL.META.STORE_REGISTRY R
QUALIFY REGISTRY_STATUS <> 'OK'
ORDER BY R.STORE_KEY;

-- C. Contract conformance ------------------------------------------------------
SELECT COLUMN_NAME, EXPECTED_ORDINAL, DEPLOYED_ORDINAL, EXPECTED_TYPE, DEPLOYED_TYPE, STATUS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE
QUALIFY STATUS <> 'OK'
ORDER BY COALESCE(EXPECTED_ORDINAL, 999), COLUMN_NAME;

-- D. Cutover reconciliation ----------------------------------------------------
--    Compare the new pipeline against the incumbent on the shared contract
--    surface. Both paths reconcile identically because both expose the same view.
--    Run this for at least three daily cycles per store before cutting over.
SELECT
  B.STORE_KEY,
  B.ACTIVITY_DATE,
  B.CURRENCY_CODE,
  B.SOURCE_NAME,
  B.ORDER_COUNT                                        AS BASELINE_ORDERS,
  A.ORDERS_PLACED                                      AS SNOWFLAKE_ORDERS,
  A.ORDERS_PLACED - B.ORDER_COUNT                      AS ORDER_DELTA,
  B.GROSS_SALES                                        AS BASELINE_GROSS,
  A.GROSS_SALES                                        AS SNOWFLAKE_GROSS,
  ROUND(A.GROSS_SALES - B.GROSS_SALES, 4)              AS GROSS_DELTA,
  CASE
    WHEN A.STORE_KEY IS NULL                                     THEN 'NO SNOWFLAKE ROW - day missing from the pipeline'
    WHEN A.ORDERS_PLACED <> B.ORDER_COUNT                        THEN 'ORDER COUNT MISMATCH - check the 60-day window and test-order exclusion'
    WHEN ABS(COALESCE(A.GROSS_SALES, 0) - B.GROSS_SALES) > 0.01  THEN 'GROSS SALES MISMATCH - check currency grain and refund attribution'
    ELSE 'MATCH'
  END                                                  AS RECONCILIATION_STATUS
FROM SHOPIFY_CONTROL.META.RECONCILIATION_BASELINE B
LEFT JOIN SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY A
  ON A.STORE_KEY     = B.STORE_KEY
 AND A.ACTIVITY_DATE = B.ACTIVITY_DATE
 AND A.CURRENCY_CODE = B.CURRENCY_CODE
WHERE B.ACTIVITY_DATE >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY B.STORE_KEY, B.ACTIVITY_DATE DESC;

-- E. Contract surface smoke test ----------------------------------------------
--    Confirms the grain is unique. Any row returned means the implementation
--    fans out and the numbers cannot be trusted.
SELECT STORE_KEY, ACTIVITY_DATE, CURRENCY_CODE, COUNT(*) AS DUPLICATE_ROWS
FROM SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY
GROUP BY STORE_KEY, ACTIVITY_DATE, CURRENCY_CODE
HAVING COUNT(*) > 1
ORDER BY DUPLICATE_ROWS DESC
LIMIT 50;
