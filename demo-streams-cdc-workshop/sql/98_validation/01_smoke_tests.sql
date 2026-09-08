/*=============================================================================
  98_validation/01_smoke_tests.sql
  Snowflake Streams CDC Workshop - Current-State Smoke Tests
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

WITH SOURCE_STATE AS (
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM RAW_ORDERS
),
TARGET_STATE AS (
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM CURRENT_ORDERS
),
SOURCE_ONLY AS (
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM SOURCE_STATE
  MINUS
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM TARGET_STATE
),
TARGET_ONLY AS (
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM TARGET_STATE
  MINUS
  SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_STATUS,
    ORDER_TOTAL,
    ORDER_TS,
    UPDATED_AT
  FROM SOURCE_STATE
),
TESTS AS (
  SELECT
    1 AS TEST_ORDER,
    'SOURCE_KEYS_UNIQUE' AS TEST_NAME,
    IFF(COUNT(*) = COUNT(DISTINCT ORDER_ID), 'PASS', 'FAIL') AS STATUS,
    'RAW_ORDERS must have one row per ORDER_ID.' AS DETAILS
  FROM RAW_ORDERS

  UNION ALL

  SELECT
    2,
    'TARGET_KEYS_UNIQUE',
    IFF(COUNT(*) = COUNT(DISTINCT ORDER_ID), 'PASS', 'FAIL'),
    'CURRENT_ORDERS must have one row per ORDER_ID.'
  FROM CURRENT_ORDERS

  UNION ALL

  SELECT
    3,
    'SOURCE_TARGET_EXACT_MATCH',
    IFF(
      (SELECT COUNT(*) FROM SOURCE_ONLY) = 0
      AND (SELECT COUNT(*) FROM TARGET_ONLY) = 0,
      'PASS',
      'FAIL'
    ),
    'Run the consumer when this fails and the Stream has data.'

  UNION ALL

  SELECT
    4,
    'STREAM_EMPTY_AFTER_CONSUMPTION',
    IFF(NOT SYSTEM$STREAM_HAS_DATA('RAW_ORDERS_STREAM'), 'PASS', 'FAIL'),
    'A pending workshop batch intentionally makes this fail before consumption.'

  UNION ALL

  SELECT
    5,
    'UPDATE_PAIRS_BALANCED',
    IFF(
      COALESCE(COUNT_IF(PAIR_STATUS <> 'BALANCED'), 0) = 0,
      'PASS',
      'FAIL'
    ),
    'Every update must balance within its batch and immutable row ID.'
  FROM (
    SELECT
      BATCH_ID,
      CDC_ROW_ID,
      IFF(
        COUNT_IF(CDC_ACTION = 'INSERT' AND CDC_IS_UPDATE) = 1
        AND COUNT_IF(CDC_ACTION = 'DELETE' AND CDC_IS_UPDATE) = 1,
        'BALANCED',
        'UNBALANCED'
      ) AS PAIR_STATUS
    FROM ORDER_CHANGE_AUDIT
    WHERE CDC_IS_UPDATE
    GROUP BY BATCH_ID, CDC_ROW_ID
  )
)
SELECT
  TEST_NAME,
  STATUS,
  DETAILS
FROM TESTS
ORDER BY TEST_ORDER;
