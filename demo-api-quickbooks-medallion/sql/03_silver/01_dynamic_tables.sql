/*==============================================================================
03_SILVER / 01_DYNAMIC_TABLES
Typed dynamic tables that flatten raw QBO JSON into relational columns.
Uses traditional JSON path extraction with QUALIFY for deduplication.
Incremental refresh processes only new/changed rows from Bronze.
Author: SE Community | Expires: 2026-03-29

TEACHING NOTE: Compare this approach with 02_cortex_enrichment.sql which
uses AI_COMPLETE structured outputs to achieve similar extraction without
hard-coded JSON paths -- useful when upstream schemas drift.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- STG_CUSTOMER
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_CUSTOMER
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged customers from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS customer_id,
    raw_payload:DisplayName::VARCHAR                              AS display_name,
    raw_payload:CompanyName::VARCHAR                              AS company_name,
    raw_payload:PrimaryEmailAddr.Address::VARCHAR                 AS email,
    raw_payload:PrimaryPhone.FreeFormNumber::VARCHAR              AS phone,
    raw_payload:BillAddr.Line1::VARCHAR                           AS bill_addr_line1,
    raw_payload:BillAddr.City::VARCHAR                            AS bill_addr_city,
    raw_payload:BillAddr.CountrySubDivisionCode::VARCHAR          AS bill_addr_state,
    raw_payload:BillAddr.PostalCode::VARCHAR                      AS bill_addr_zip,
    raw_payload:Balance::NUMBER(12,2)                             AS balance,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_CUSTOMER
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_VENDOR
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_VENDOR
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged vendors from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS vendor_id,
    raw_payload:DisplayName::VARCHAR                              AS display_name,
    raw_payload:CompanyName::VARCHAR                              AS company_name,
    raw_payload:PrimaryEmailAddr.Address::VARCHAR                 AS email,
    raw_payload:PrimaryPhone.FreeFormNumber::VARCHAR              AS phone,
    raw_payload:Balance::NUMBER(12,2)                             AS balance,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_VENDOR
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_ITEM
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_ITEM
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged items/products from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS item_id,
    raw_payload:Name::VARCHAR                                     AS item_name,
    raw_payload:Type::VARCHAR                                     AS item_type,
    raw_payload:UnitPrice::NUMBER(12,2)                           AS unit_price,
    raw_payload:QtyOnHand::NUMBER(12,2)                           AS qty_on_hand,
    raw_payload:IncomeAccountRef.value::VARCHAR                   AS income_account_id,
    raw_payload:Active::BOOLEAN                                   AS is_active,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_ITEM
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_ACCOUNT
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_ACCOUNT
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged chart of accounts from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS account_id,
    raw_payload:Name::VARCHAR                                     AS account_name,
    raw_payload:AccountType::VARCHAR                              AS account_type,
    raw_payload:AccountSubType::VARCHAR                           AS account_sub_type,
    raw_payload:CurrentBalance::NUMBER(14,2)                      AS current_balance,
    raw_payload:Active::BOOLEAN                                   AS is_active,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_ACCOUNT
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_INVOICE
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_INVOICE
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged invoices from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS invoice_id,
    raw_payload:DocNumber::VARCHAR                                AS doc_number,
    raw_payload:CustomerRef.value::VARCHAR                        AS customer_id,
    raw_payload:TxnDate::DATE                                     AS txn_date,
    raw_payload:DueDate::DATE                                     AS due_date,
    raw_payload:TotalAmt::NUMBER(12,2)                            AS total_amount,
    raw_payload:Balance::NUMBER(12,2)                              AS balance,
    raw_payload:PrivateNote::VARCHAR                               AS private_note,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_INVOICE
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_INVOICE_LINE (flattened from the nested Line array)
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_INVOICE_LINE
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged invoice line items from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS invoice_id,
    raw_payload:DocNumber::VARCHAR                                AS doc_number,
    line.value:Id::VARCHAR                                        AS line_id,
    line.value:Amount::NUMBER(12,2)                               AS line_amount,
    line.value:DetailType::VARCHAR                                AS detail_type,
    line.value:SalesItemLineDetail.ItemRef.value::VARCHAR         AS item_id,
    line.value:SalesItemLineDetail.Qty::NUMBER(12,2)              AS quantity,
    line.value:SalesItemLineDetail.UnitPrice::NUMBER(12,2)        AS unit_price,
    fetched_at
FROM RAW_INVOICE,
    LATERAL FLATTEN(input => raw_payload:Line) AS line
WHERE line.value:DetailType::VARCHAR = 'SalesItemLineDetail'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY raw_payload:Id::VARCHAR, line.value:Id::VARCHAR
    ORDER BY fetched_at DESC
) = 1;

-------------------------------------------------------------------------------
-- STG_PAYMENT
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_PAYMENT
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged payments from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS payment_id,
    raw_payload:CustomerRef.value::VARCHAR                        AS customer_id,
    raw_payload:TxnDate::DATE                                     AS txn_date,
    raw_payload:TotalAmt::NUMBER(12,2)                            AS total_amount,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_PAYMENT
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- STG_BILL
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STG_BILL
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Staged vendor bills from QBO (Expires: 2026-03-29)'
AS
SELECT
    raw_payload:Id::VARCHAR                                       AS bill_id,
    raw_payload:DocNumber::VARCHAR                                AS doc_number,
    raw_payload:VendorRef.value::VARCHAR                          AS vendor_id,
    raw_payload:TxnDate::DATE                                     AS txn_date,
    raw_payload:DueDate::DATE                                     AS due_date,
    raw_payload:TotalAmt::NUMBER(12,2)                            AS total_amount,
    raw_payload:Balance::NUMBER(12,2)                              AS balance,
    raw_payload:MetaData.CreateTime::TIMESTAMP_NTZ                AS qbo_created_at,
    raw_payload:MetaData.LastUpdatedTime::TIMESTAMP_NTZ           AS qbo_updated_at,
    fetched_at
FROM RAW_BILL
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;
