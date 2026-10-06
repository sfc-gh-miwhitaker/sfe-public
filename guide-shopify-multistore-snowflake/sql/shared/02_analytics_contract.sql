/*
  guide-shopify-multistore-snowflake — sql/shared/02_analytics_contract.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Make the DAILY_SHOP_ACTIVITY contract machine-checkable, and give downstream
    reports ONE object name to query regardless of which implementation path
    produced the data.

    The column contract itself is defined once, in prose, in README.md
    ("The one analytics contract"). This file encodes the same list as data so a
    drifting implementation fails a query instead of quietly producing a
    different table.

  WHAT IT CREATES
    SHOPIFY_CONTROL.META.CONTRACT_COLUMNS      expected column list + types
    SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE  pass/fail per expected column

  WHAT EACH PATH MUST CREATE
    Each path is responsible for pointing two fixed view names at its own
    objects. Everything shared -- monitoring, reconciliation, BI -- reads only
    these two names, so switching paths does not rewrite anything downstream.

      SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY   the contract surface
      SHOPIFY_CONTROL.META.V_STORE_FRESHNESS       ops surface

    Openflow path: created by sql/openflow/06_analytics_layer.sql
    Native path:   created by sql/native/05_analytics_layer.sql

  RUN AS      SHOPIFY_CONTROL_ADMIN
  RUNTIME     < 1 minute
  SOURCE      https://docs.snowflake.com/en/user-guide/dynamic-tables/overview
*/

USE ROLE SHOPIFY_CONTROL_ADMIN;

-- 1. The contract, as data -----------------------------------------------------
CREATE OR REPLACE TABLE SHOPIFY_CONTROL.META.CONTRACT_COLUMNS (
  ORDINAL      NUMBER      NOT NULL,
  COLUMN_NAME  VARCHAR(64) NOT NULL,
  DATA_TYPE    VARCHAR(32) NOT NULL,
  IS_GRAIN     BOOLEAN     NOT NULL,
  DEFINITION   VARCHAR     NOT NULL,
  CONSTRAINT PK_CONTRACT_COLUMNS PRIMARY KEY (COLUMN_NAME)
)
COMMENT = 'Expected columns of V_DAILY_SHOP_ACTIVITY. Must match README.md exactly.';

INSERT INTO SHOPIFY_CONTROL.META.CONTRACT_COLUMNS
  (ORDINAL, COLUMN_NAME, DATA_TYPE, IS_GRAIN, DEFINITION)
SELECT COLUMN1, COLUMN2, COLUMN3, COLUMN4, COLUMN5
FROM VALUES
  ( 1, 'STORE_KEY',           'TEXT',   TRUE,  'Registry key. Openflow path: also the landing schema name.'),
  ( 2, 'SHOP_URL',            'TEXT',   FALSE, 'STORE_REGISTRY.SHOP_DOMAIN for STORE_KEY. Attribute, not grain.'),
  ( 3, 'ACTIVITY_DATE',       'DATE',   TRUE,  'UTC calendar date. Orders bucket on PROCESSED_AT; shipments on fulfillment CREATED_AT.'),
  ( 4, 'CURRENCY_CODE',       'TEXT',   TRUE,  'Shop presentment currency of the order. NULL only for a shipment whose parent order is outside the loaded window.'),
  ( 5, 'ORDERS_PLACED',       'NUMBER', FALSE, 'Orders processed on ACTIVITY_DATE. Excludes test and soft-deleted orders.'),
  ( 6, 'ORDERS_CANCELLED',    'NUMBER', FALSE, 'Subset of ORDERS_PLACED with a non-null CANCELLED_AT. Not a separate day bucket.'),
  ( 7, 'UNITS_SOLD',          'NUMBER', FALSE, 'SUM of line-item QUANTITY over the orders counted in ORDERS_PLACED.'),
  ( 8, 'GROSS_SALES',         'NUMBER', FALSE, 'SUM of order TOTAL_PRICE (shop money). Already net of discounts per Shopify.'),
  ( 9, 'DISCOUNTS',           'NUMBER', FALSE, 'SUM of order TOTAL_DISCOUNTS. Reported, never subtracted again.'),
  (10, 'REFUNDS',             'NUMBER', FALSE, 'SUM of order TOTAL_REFUNDED, attributed to the order date, not the refund date.'),
  (11, 'NET_SALES',           'NUMBER', FALSE, 'GROSS_SALES - REFUNDS.'),
  (12, 'SHIPMENTS_CREATED',   'NUMBER', FALSE, 'Fulfillments created on ACTIVITY_DATE, any status.'),
  (13, 'SHIPMENTS_SUCCESS',   'NUMBER', FALSE, 'Subset of SHIPMENTS_CREATED with STATUS = ''SUCCESS''.'),
  (14, 'SHIPMENTS_DELIVERED', 'NUMBER', FALSE, 'Subset of SHIPMENTS_CREATED with a non-null DELIVERED_AT.');

-- 2. Conformance check ---------------------------------------------------------
--    Run after deploying either path. Any row with STATUS <> 'OK' is drift:
--    fix the implementation, not this table.
CREATE OR REPLACE VIEW SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE
COMMENT = 'Compares the deployed V_DAILY_SHOP_ACTIVITY column list against the published contract'
AS
WITH DEPLOYED AS (
  SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
  FROM SHOPIFY_CONTROL.INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'META'
    AND TABLE_NAME   = 'V_DAILY_SHOP_ACTIVITY'
)
SELECT
  COALESCE(C.COLUMN_NAME, D.COLUMN_NAME)                       AS COLUMN_NAME,
  C.ORDINAL                                                    AS EXPECTED_ORDINAL,
  D.ORDINAL_POSITION                                           AS DEPLOYED_ORDINAL,
  C.DATA_TYPE                                                  AS EXPECTED_TYPE,
  D.DATA_TYPE                                                  AS DEPLOYED_TYPE,
  C.IS_GRAIN,
  CASE
    WHEN D.COLUMN_NAME IS NULL THEN 'MISSING - implementation does not produce this contract column'
    WHEN C.COLUMN_NAME IS NULL THEN 'EXTRA - not in the contract; add it to README.md and CONTRACT_COLUMNS or drop it'
    WHEN D.DATA_TYPE <> C.DATA_TYPE THEN 'TYPE DRIFT - expected ' || C.DATA_TYPE || ', got ' || D.DATA_TYPE
    WHEN D.ORDINAL_POSITION <> C.ORDINAL THEN 'ORDER DRIFT - expected position ' || C.ORDINAL
    ELSE 'OK'
  END                                                          AS STATUS
FROM SHOPIFY_CONTROL.META.CONTRACT_COLUMNS C
FULL OUTER JOIN DEPLOYED D
  ON D.COLUMN_NAME = C.COLUMN_NAME;

-- 3. Verify --------------------------------------------------------------------
--    Expect 14 rows, every STATUS = 'OK'. Before either path is deployed the
--    view returns 14 MISSING rows; that is the correct pre-deployment answer.
SELECT COLUMN_NAME, EXPECTED_ORDINAL, DEPLOYED_ORDINAL, EXPECTED_TYPE, DEPLOYED_TYPE, STATUS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE
ORDER BY COALESCE(EXPECTED_ORDINAL, 999), COLUMN_NAME;

SELECT COUNT_IF(STATUS <> 'OK') AS CONTRACT_VIOLATIONS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE;
