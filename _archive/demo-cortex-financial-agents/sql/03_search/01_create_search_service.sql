/*==============================================================================
01 - Cortex Search Service for Document RAG
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Indexes credit memos, legal docs, and compliance certificates for
retrieval-augmented generation with citation support.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE FACILITY_DOCUMENT_SEARCH
  ON content
  PRIMARY KEY (doc_id)
  ATTRIBUTES doc_type, facility_id, title, author, source_url
  WAREHOUSE = SFE_FINANCIAL_AGENTS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'DEMO: RAG search over credit memos, covenant certs, appraisals, amendments, reviews (Expires: 2026-04-09)'
AS (
  SELECT
    doc_id,
    facility_id,
    doc_type,
    title,
    content,
    author,
    created_date,
    GET_PRESIGNED_URL(@DOC_STAGE, doc_id || '.pdf', 604800) AS source_url
  FROM RAW_DOCUMENTS
);
