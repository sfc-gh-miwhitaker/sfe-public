/*=============================================================================
  04_workshop/04_second_change_batch.sql
  Exercise 4 - Prove Repeatability With a Second Batch
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
  (1006, 506, 'PROCESSING', 155.40, '2026-09-08 11:00:00', '2026-09-08 11:00:00');

UPDATE RAW_ORDERS
SET
  ORDER_STATUS = 'DELIVERED',
  UPDATED_AT = '2026-09-08 11:05:00'
WHERE ORDER_ID = 1004;

SELECT
  COUNT(*) AS second_batch_cdc_rows,
  COUNT_IF(METADATA$ISUPDATE) AS update_pair_rows,
  COUNT_IF(NOT METADATA$ISUPDATE) AS standalone_rows
FROM RAW_ORDERS_STREAM;

CALL SP_CONSUME_ORDER_CHANGES();

SELECT
  (SELECT COUNT(*) FROM RAW_ORDERS) AS source_rows,
  (SELECT COUNT(*) FROM CURRENT_ORDERS) AS target_rows,
  (SELECT COUNT(*) FROM ORDER_CHANGE_AUDIT) AS cumulative_audit_rows,
  SYSTEM$STREAM_HAS_DATA('RAW_ORDERS_STREAM') AS stream_has_data;
