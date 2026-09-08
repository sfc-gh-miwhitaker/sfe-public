/*=============================================================================
  02_data/02_load_baseline.sql
  Snowflake Streams CDC Workshop - Deterministic Synchronized Baseline
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

INSERT INTO RAW_ORDERS (
  ORDER_ID,
  CUSTOMER_ID,
  ORDER_STATUS,
  ORDER_TOTAL,
  ORDER_TS,
  UPDATED_AT
)
VALUES
  (1001, 501, 'PENDING',   125.00, '2026-09-08 09:00:00', '2026-09-08 09:00:00'),
  (1002, 502, 'PROCESSING', 89.50, '2026-09-08 09:05:00', '2026-09-08 09:05:00'),
  (1003, 503, 'PENDING',    42.25, '2026-09-08 09:10:00', '2026-09-08 09:10:00'),
  (1004, 504, 'SHIPPED',   210.75, '2026-09-08 09:15:00', '2026-09-08 09:15:00');

INSERT INTO CURRENT_ORDERS (
  ORDER_ID,
  CUSTOMER_ID,
  ORDER_STATUS,
  ORDER_TOTAL,
  ORDER_TS,
  UPDATED_AT,
  CDC_APPLIED_AT
)
SELECT
  ORDER_ID,
  CUSTOMER_ID,
  ORDER_STATUS,
  ORDER_TOTAL,
  ORDER_TS,
  UPDATED_AT,
  CURRENT_TIMESTAMP()
FROM RAW_ORDERS;
