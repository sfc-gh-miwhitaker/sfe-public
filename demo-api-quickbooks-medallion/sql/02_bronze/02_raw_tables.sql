/*==============================================================================
02_BRONZE / 02_RAW_TABLES
Raw landing tables for 7 QuickBooks Online entities.
Each stores the full JSON payload as VARIANT with ingestion metadata.
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- Dimensions
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RAW_CUSTOMER (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Customer JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_VENDOR (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Vendor JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_ITEM (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Item JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_ACCOUNT (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Account JSON (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- Transactions
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RAW_INVOICE (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Invoice JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_PAYMENT (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Payment JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_BILL (
    qbo_id        VARCHAR   NOT NULL,
    raw_payload   VARIANT   NOT NULL,
    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    api_endpoint  VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Bill JSON (Expires: 2026-03-29)';
