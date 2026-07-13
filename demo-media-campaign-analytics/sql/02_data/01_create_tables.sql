/*==============================================================================
  02_data/01_create_tables.sql
  Media Campaign Analytics — Table Definitions
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE TABLE DIM_CLIENT (
    CLIENT_ID       NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_NAME     VARCHAR(50)   NOT NULL,
    VERTICAL        VARCHAR(30)   NOT NULL,
    TIER            VARCHAR(20)   NOT NULL,
    COMMENT         VARCHAR(200)
) COMMENT = 'DEMO: Advertising client dimension — 20 fictional clients (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE DIM_CHANNEL (
    CHANNEL_ID      NUMBER        NOT NULL PRIMARY KEY,
    CHANNEL_NAME    VARCHAR(50)   NOT NULL,
    CHANNEL_TYPE    VARCHAR(30)   NOT NULL
) COMMENT = 'DEMO: Media channel dimension — 5 paid media channels (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE DIM_CAMPAIGN (
    CAMPAIGN_ID     NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_ID       NUMBER        NOT NULL,
    CHANNEL_ID      NUMBER        NOT NULL,
    CAMPAIGN_NAME   VARCHAR(100)  NOT NULL,
    OBJECTIVE       VARCHAR(50)   NOT NULL,
    BUDGET          NUMBER(12,2)  NOT NULL,
    START_DATE      DATE          NOT NULL,
    END_DATE        DATE          NOT NULL,
    STATUS          VARCHAR(20)   NOT NULL
) COMMENT = 'DEMO: Campaign dimension — ~300 synthetic campaigns (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE FACT_DAILY_PERFORMANCE (
    PERF_ID                   NUMBER        NOT NULL PRIMARY KEY,
    CAMPAIGN_ID               NUMBER        NOT NULL,
    CHANNEL_ID                NUMBER        NOT NULL,
    CLIENT_ID                 NUMBER        NOT NULL,
    PERF_DATE                 DATE          NOT NULL,
    IMPRESSIONS               NUMBER(15,0)  NOT NULL,
    CLICKS                    NUMBER(12,0)  NOT NULL,
    CONVERSIONS               NUMBER(10,0)  NOT NULL,
    SPEND                     NUMBER(12,2)  NOT NULL,
    REVENUE                   NUMBER(14,2)  NOT NULL,
    DAILY_BUDGET_ALLOCATION   NUMBER(12,2)  NOT NULL
) COMMENT = 'DEMO: Daily campaign performance fact table — Jan 2025 to Jun 2026 (Expires: 2026-08-12)';
