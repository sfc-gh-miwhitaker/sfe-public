/*==============================================================================
APPROACH 3: Cortex AI Enrichment Pipeline ★ HEADLINE FEATURE ★
Philosophy: Use Snowflake's native LLM functions to analyze, classify, and
            enrich OpenAI response data. Meta-analysis of AI outputs using AI,
            entirely within Snowflake -- no external API calls required.

This approach showcases Snowflake Cortex's power: topic classification,
sentiment analysis, summarization, and PII detection -- all serverless,
all governed, all within your data boundary.

Depends on: Approach 2 Silver tables (DT_COMPLETIONS, DT_BATCH_OUTCOMES).
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;
USE WAREHOUSE SFE_OPENAI_DATA_ENG_WH;

/*------------------------------------------------------------------------------
DT_ENRICHED_COMPLETIONS — Cortex-enriched completion analysis.
Classifies topic, scores sentiment, and summarizes long content.

NOTE: Cortex LLM functions consume credits. In production, consider:
  - Filtering to only new/unprocessed rows
  - Caching results in a persistent table instead of a dynamic table

MODEL SELECTION: Using claude-opus-4-6 per customer request.
  - Recommended for cost/performance: llama3.1-70b or mistral-large2
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_ENRICHED_COMPLETIONS
  TARGET_LAG = '10 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - Cortex-enriched completions (Expires: 2026-03-28)'
AS
WITH classified AS (
    SELECT
        completion_id,
        model,
        created_at,
        finish_reason,
        content,
        content_length,
        is_refusal,
        has_tool_calls,
        is_structured_output,
        prompt_tokens,
        completion_tokens,
        total_tokens,
        -- Single CLASSIFY_TEXT call, result reused for label and score
        SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            content,
            ['technical_explanation', 'data_analysis', 'code_generation',
             'summarization', 'general_knowledge', 'recommendation']
        )                                                   AS topic_result,
        SNOWFLAKE.CORTEX.SENTIMENT(content)                 AS sentiment_score,
        CASE
            WHEN content_length > 200
            THEN SNOWFLAKE.CORTEX.SUMMARIZE(content)
            ELSE content
        END                                                 AS content_summary
    FROM DT_COMPLETIONS
    WHERE content IS NOT NULL
      AND is_refusal = FALSE
)
SELECT
    completion_id,
    model,
    created_at,
    finish_reason,
    content,
    content_length,
    is_refusal,
    has_tool_calls,
    is_structured_output,
    prompt_tokens,
    completion_tokens,
    total_tokens,
    topic_result:label::STRING                              AS topic_classification,
    topic_result:score::FLOAT                               AS topic_confidence,
    sentiment_score,
    content_summary
FROM classified;


/*------------------------------------------------------------------------------
DT_BATCH_ENRICHED — Classified batch results for routing validation.
Compares OpenAI's classification against Cortex's independent analysis.
This is particularly compelling: showing Snowflake can QA another AI's outputs.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_BATCH_ENRICHED
  TARGET_LAG = '10 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - Cortex QA of batch classifications (Expires: 2026-03-28)'
AS
WITH classified AS (
    SELECT
        batch_request_id,
        custom_id,
        outcome,
        model,
        content,
        content_parsed,
        refusal,
        total_tokens,
        content_parsed:category::STRING                     AS openai_category,
        content_parsed:priority::STRING                     AS openai_priority,
        content_parsed:sentiment::STRING                    AS openai_sentiment,
        content_parsed:suggested_routing::STRING            AS openai_routing,
        -- Single CLASSIFY_TEXT call, result reused for category and agreement check
        SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            custom_id || ': ' || COALESCE(content, refusal, 'no content'),
            ['billing', 'technical_support', 'feature_request', 'account_access',
             'general_inquiry', 'outage_report', 'compliance', 'cancellation',
             'data_request']
        )                                                   AS cortex_result,
        SNOWFLAKE.CORTEX.SENTIMENT(
            COALESCE(content, refusal, 'no content')
        )                                                   AS cortex_sentiment_score
    FROM DT_BATCH_OUTCOMES
    WHERE outcome = 'SUCCESS'
      AND content_parsed IS NOT NULL
)
SELECT
    batch_request_id,
    custom_id,
    outcome,
    model,
    content,
    content_parsed,
    openai_category,
    openai_priority,
    openai_sentiment,
    openai_routing,
    cortex_result:label::STRING                             AS cortex_category,
    cortex_sentiment_score,
    IFF(openai_category = cortex_result:label::STRING,
        'AGREE', 'DISAGREE')                                AS classification_agreement,
    total_tokens
FROM classified;


/*------------------------------------------------------------------------------
DT_PII_SCAN — Scan completion content and tool call arguments for PII.
Uses Cortex COMPLETE with a focused prompt to detect sensitive data patterns.

MODEL SELECTION: Using claude-opus-4-6 per customer request.
  - Recommended for cost/performance: llama3.1-70b or mistral-large2
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_PII_SCAN
  TARGET_LAG = '30 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - PII detection in AI outputs (Expires: 2026-03-28)'
AS
WITH completion_texts AS (
    SELECT
        completion_id       AS source_id,
        'completion'        AS source_type,
        content             AS text_to_scan,
        created_at
    FROM DT_COMPLETIONS
    WHERE content IS NOT NULL
      AND is_refusal = FALSE

    UNION ALL

    SELECT
        completion_id       AS source_id,
        'tool_call_args'    AS source_type,
        arguments_json      AS text_to_scan,
        created_at
    FROM DT_TOOL_CALLS
    WHERE arguments_json IS NOT NULL
),
scanned AS (
    -- Single CORTEX.COMPLETE call per row, result reused for raw and parsed
    SELECT
        source_id,
        source_type,
        text_to_scan,
        created_at,
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-opus-4-6',
            'Analyze the following text and return ONLY a JSON object with these fields: '
            || '{"has_pii": true/false, "pii_types": ["list of types found"], '
            || '"risk_level": "none/low/medium/high"}. '
            || 'PII types to check: email, phone, SSN, credit card, address, name, date of birth. '
            || 'Text to analyze: ' || LEFT(text_to_scan, 2000)
        )                                                   AS pii_analysis_raw
    FROM completion_texts
)
SELECT
    source_id,
    source_type,
    text_to_scan,
    created_at,
    pii_analysis_raw,
    TRY_PARSE_JSON(pii_analysis_raw)                        AS pii_analysis_parsed
FROM scanned;


/*------------------------------------------------------------------------------
V_ENRICHMENT_DASHBOARD — Aggregated view for the Streamlit app.
Combines topic distribution, sentiment trends, and PII alerts.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_ENRICHMENT_DASHBOARD
  COMMENT = 'DEMO: Approach 3 - Enrichment dashboard aggregations (Expires: 2026-03-28)'
AS
SELECT
    topic_classification,
    COUNT(*)                                                AS response_count,
    ROUND(AVG(sentiment_score), 3)                          AS avg_sentiment,
    ROUND(AVG(topic_confidence), 3)                         AS avg_topic_confidence,
    SUM(total_tokens)                                       AS total_tokens_consumed,
    ROUND(AVG(total_tokens), 0)                             AS avg_tokens_per_response,
    SUM(IFF(has_tool_calls, 1, 0))                          AS tool_call_responses,
    SUM(IFF(is_structured_output, 1, 0))                    AS structured_output_count
FROM DT_ENRICHED_COMPLETIONS
GROUP BY topic_classification;
