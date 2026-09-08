/*=============================================================================
  04_workshop/02_inspect_stream.sql
  Exercise 2 - Inspect CDC Metadata Without Advancing the Offset
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

SELECT
  ORDER_ID,
  CUSTOMER_ID,
  ORDER_STATUS,
  ORDER_TOTAL,
  UPDATED_AT,
  METADATA$ACTION AS CDC_ACTION,
  METADATA$ISUPDATE AS CDC_IS_UPDATE,
  METADATA$ROW_ID AS CDC_ROW_ID
FROM RAW_ORDERS_STREAM
ORDER BY ORDER_ID, CDC_ACTION;

SELECT
  COUNT(*) AS rows_still_available_after_select,
  COUNT_IF(METADATA$ACTION = 'INSERT' AND NOT METADATA$ISUPDATE) AS standalone_inserts,
  COUNT_IF(METADATA$ACTION = 'INSERT' AND METADATA$ISUPDATE) AS update_after_rows,
  COUNT_IF(METADATA$ACTION = 'DELETE' AND METADATA$ISUPDATE) AS update_before_rows,
  COUNT_IF(METADATA$ACTION = 'DELETE' AND NOT METADATA$ISUPDATE) AS standalone_deletes
FROM RAW_ORDERS_STREAM;
