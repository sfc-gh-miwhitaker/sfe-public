/*==============================================================================
01 - Table Definitions
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

CREATE OR REPLACE TABLE RAW_BORROWERS (
    borrower_id         VARCHAR(10)   NOT NULL,
    company_name        VARCHAR(100)  NOT NULL,
    industry            VARCHAR(50)   NOT NULL,
    annual_revenue      NUMBER(15,2)  NOT NULL,
    ebitda              NUMBER(15,2)  NOT NULL,
    employee_count      NUMBER(6)     NOT NULL,
    state               VARCHAR(2)    NOT NULL,
    risk_rating         NUMBER(1)     NOT NULL,
    relationship_start  DATE          NOT NULL
) COMMENT = 'DEMO: Middle-market borrower company profiles (Expires: 2026-04-09)';

CREATE OR REPLACE TABLE RAW_FACILITIES (
    facility_id         VARCHAR(15)   NOT NULL,
    borrower_id         VARCHAR(10)   NOT NULL,
    facility_type       VARCHAR(30)   NOT NULL,
    origination_date    DATE          NOT NULL,
    maturity_date       DATE          NOT NULL,
    commitment_amount   NUMBER(15,2)  NOT NULL,
    outstanding_balance NUMBER(15,2)  NOT NULL,
    interest_rate       NUMBER(5,3)   NOT NULL,
    advance_rate        NUMBER(5,2),
    ltv_ratio           NUMBER(5,2),
    status              VARCHAR(20)   NOT NULL
) COMMENT = 'DEMO: Credit facilities -- asset-based, term, equipment, bridge, revolver (Expires: 2026-04-09)';

CREATE OR REPLACE TABLE RAW_COVENANTS (
    covenant_id         VARCHAR(15)   NOT NULL,
    facility_id         VARCHAR(15)   NOT NULL,
    covenant_type       VARCHAR(30)   NOT NULL,
    threshold_value     NUMBER(10,2)  NOT NULL,
    actual_value        NUMBER(10,2)  NOT NULL,
    reporting_period    VARCHAR(7)    NOT NULL,
    in_compliance       BOOLEAN       NOT NULL,
    waiver_granted      BOOLEAN       NOT NULL DEFAULT FALSE
) COMMENT = 'DEMO: Quarterly covenant test results -- leverage, coverage, EBITDA (Expires: 2026-04-09)';

CREATE OR REPLACE TABLE RAW_PORTFOLIO_METRICS (
    metric_id           VARCHAR(15)   NOT NULL,
    facility_id         VARCHAR(15)   NOT NULL,
    reporting_date      DATE          NOT NULL,
    outstanding_balance NUMBER(15,2)  NOT NULL,
    collateral_value    NUMBER(15,2),
    dscr                NUMBER(5,2),
    leverage_ratio      NUMBER(5,2),
    interest_coverage   NUMBER(5,2),
    days_past_due       NUMBER(4)     NOT NULL DEFAULT 0,
    payment_status      VARCHAR(20)   NOT NULL
) COMMENT = 'DEMO: Time-series facility health metrics (Expires: 2026-04-09)';

CREATE OR REPLACE TABLE RAW_DOCUMENTS (
    doc_id              VARCHAR(15)   NOT NULL,
    facility_id         VARCHAR(15)   NOT NULL,
    doc_type            VARCHAR(40)   NOT NULL,
    title               VARCHAR(200)  NOT NULL,
    content             VARCHAR       NOT NULL,
    author              VARCHAR(80)   NOT NULL,
    created_date        DATE          NOT NULL
) COMMENT = 'DEMO: Unstructured credit memos, legal docs, compliance certificates (Expires: 2026-04-09)';
