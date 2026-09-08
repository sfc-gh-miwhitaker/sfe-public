/*=============================================================================
  04_workshop/03_consume_and_reconcile.sql
  Exercise 3 - Consume Transactionally and Reconcile Current State
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

CALL SP_CONSUME_ORDER_CHANGES();

SELECT
  (SELECT COUNT(*) FROM RAW_ORDERS) AS source_rows,
  (SELECT COUNT(*) FROM CURRENT_ORDERS) AS target_rows,
  (SELECT COUNT(*) FROM ORDER_CHANGE_AUDIT) AS audit_rows,
  SYSTEM$STREAM_HAS_DATA('RAW_ORDERS_STREAM') AS stream_has_data,
  CASE
    WHEN NOT EXISTS (
      SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_STATUS,
        ORDER_TOTAL,
        ORDER_TS,
        UPDATED_AT
      FROM RAW_ORDERS
      MINUS
      SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_STATUS,
        ORDER_TOTAL,
        ORDER_TS,
        UPDATED_AT
      FROM CURRENT_ORDERS
    )
    AND NOT EXISTS (
      SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_STATUS,
        ORDER_TOTAL,
        ORDER_TS,
        UPDATED_AT
      FROM CURRENT_ORDERS
      MINUS
      SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_STATUS,
        ORDER_TOTAL,
        ORDER_TS,
        UPDATED_AT
      FROM RAW_ORDERS
    )
    THEN 'PASS'
    ELSE 'FAIL'
  END AS exact_reconciliation;
