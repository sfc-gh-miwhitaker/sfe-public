/*==============================================================================
  02_data/03_create_document_table.sql
  Media Campaign Analytics — Campaign Documents Table
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Unstructured campaign content for Cortex Search:
    - Campaign briefs (objectives, target audience, KPIs)
    - Creative copy (ad headlines, body copy, CTAs)
    - Channel strategy notes (why this channel for this client)
    - Client relationship notes (account context, preferences)
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE TABLE DOC_CAMPAIGN_CONTENT (
    DOC_ID        NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_ID     NUMBER        NOT NULL,
    CAMPAIGN_ID   NUMBER,
    DOC_TYPE      VARCHAR(30)   NOT NULL,
    TITLE         VARCHAR(200)  NOT NULL,
    CONTENT       VARCHAR(4000) NOT NULL,
    CREATED_DATE  DATE          NOT NULL
) COMMENT = 'DEMO: Campaign documents for Cortex Search — briefs, copy, strategy notes (Expires: 2026-08-12)';
