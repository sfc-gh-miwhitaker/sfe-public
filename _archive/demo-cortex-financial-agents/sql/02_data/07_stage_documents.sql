/*==============================================================================
07 - Stage Financial Documents (PDF)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Copies PDF documents from the Git repository into an internal stage so that
Cortex Search citations produce clickable presigned URLs.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

CREATE STAGE IF NOT EXISTS DOC_STAGE
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'DEMO: Staged financial documents for RAG citations (Expires: 2026-04-09)';

COPY FILES
  INTO @DOC_STAGE
  FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-financial-agents/documents/
  PATTERN = '.*[.]pdf';

ALTER STAGE DOC_STAGE REFRESH;

GRANT READ ON STAGE DOC_STAGE TO ROLE PUBLIC;
