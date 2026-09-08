/*=============================================================================
  04_workshop/01_first_change_batch.sql
  Exercise 1 - Generate One Insert, One Update, and One Delete
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
  (1005, 505, 'PENDING', 64.95, '2026-09-08 10:00:00', '2026-09-08 10:00:00');

UPDATE RAW_ORDERS
SET
  ORDER_STATUS = 'SHIPPED',
  UPDATED_AT = '2026-09-08 10:05:00'
WHERE ORDER_ID = 1001;

DELETE FROM RAW_ORDERS
WHERE ORDER_ID = 1003;

SELECT
  'Expected: four net CDC rows (insert + update delete/insert pair + delete).' AS next_step,
  SYSTEM$STREAM_HAS_DATA('RAW_ORDERS_STREAM') AS stream_has_data;
