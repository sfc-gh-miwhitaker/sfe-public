/*==============================================================================
APPROACH 2: Medallion Architecture with Dynamic Tables
Philosophy: Declarative pipeline from raw to analytics-ready. Snowflake
            handles incremental refresh automatically. No orchestrator needed.

  Bronze (RAW_*) → Silver (DT_*) → Gold (DT_*_SUMMARY / DT_*_ANALYTICS)
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;
USE WAREHOUSE SFE_OPENAI_DATA_ENG_WH;

/*------------------------------------------------------------------------------
SILVER: DT_COMPLETIONS — Typed, flattened chat completions.
One row per choice with all fields extracted to native types.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_COMPLETIONS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Silver - typed chat completions (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                              AS completion_id,
    raw:model::STRING                                           AS model,
    TO_TIMESTAMP(raw:created::NUMBER)                           AS created_at,
    raw:system_fingerprint::STRING                              AS system_fingerprint,
    c.value:index::NUMBER                                       AS choice_index,
    c.value:finish_reason::STRING                               AS finish_reason,
    c.value:message:role::STRING                                AS message_role,
    c.value:message:content::STRING                             AS content,
    LENGTH(c.value:message:content::STRING)                     AS content_length,
    c.value:message:refusal::STRING                             AS refusal,
    IFF(c.value:message:refusal IS NOT NULL, TRUE, FALSE)       AS is_refusal,
    IFF(c.value:message:tool_calls IS NOT NULL, TRUE, FALSE)    AS has_tool_calls,
    COALESCE(ARRAY_SIZE(c.value:message:tool_calls), 0)         AS tool_call_count,
    IFF(TRY_PARSE_JSON(c.value:message:content::STRING) IS NOT NULL
        AND c.value:message:refusal IS NULL, TRUE, FALSE)       AS is_structured_output,
    raw:usage:prompt_tokens::NUMBER                             AS prompt_tokens,
    raw:usage:completion_tokens::NUMBER                         AS completion_tokens,
    raw:usage:total_tokens::NUMBER                              AS total_tokens,
    raw:usage:prompt_tokens_details:cached_tokens::NUMBER       AS cached_tokens,
    raw:usage:completion_tokens_details:reasoning_tokens::NUMBER AS reasoning_tokens,
    ROUND(raw:usage:prompt_tokens_details:cached_tokens::NUMBER /
          NULLIF(raw:usage:prompt_tokens::NUMBER, 0), 3)        AS cache_hit_ratio,
    loaded_at,
    source_file
FROM RAW_CHAT_COMPLETIONS,
     LATERAL FLATTEN(INPUT => raw:choices) c;


/*------------------------------------------------------------------------------
SILVER: DT_TOOL_CALLS — One row per tool invocation with parsed arguments.
Downstream can query argument keys/values without re-parsing.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_TOOL_CALLS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Silver - parsed tool calls (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                              AS completion_id,
    raw:model::STRING                                           AS model,
    TO_TIMESTAMP(raw:created::NUMBER)                           AS created_at,
    c.value:index::NUMBER                                       AS choice_index,
    t.index                                                     AS tool_call_index,
    t.value:id::STRING                                          AS tool_call_id,
    t.value:type::STRING                                        AS tool_type,
    t.value:function:name::STRING                               AS function_name,
    t.value:function:arguments::STRING                          AS arguments_json,
    TRY_PARSE_JSON(t.value:function:arguments::STRING)          AS arguments_parsed,
    ARRAY_SIZE(OBJECT_KEYS(
        TRY_PARSE_JSON(t.value:function:arguments::STRING)
    ))                                                          AS argument_count,
    raw:usage:prompt_tokens::NUMBER                             AS prompt_tokens,
    raw:usage:completion_tokens::NUMBER                         AS completion_tokens,
    loaded_at
FROM RAW_CHAT_COMPLETIONS,
     LATERAL FLATTEN(INPUT => raw:choices) c,
     LATERAL FLATTEN(INPUT => c.value:message:tool_calls) t;


/*------------------------------------------------------------------------------
SILVER: DT_BATCH_OUTCOMES — Unwrapped batch results with success/error status.
Clean separation of response metadata from completion content.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_BATCH_OUTCOMES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Silver - batch outcomes with error handling (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                              AS batch_request_id,
    raw:custom_id::STRING                                       AS custom_id,
    CASE
        WHEN raw:error IS NOT NULL                    THEN 'API_ERROR'
        WHEN c.value:message:refusal IS NOT NULL      THEN 'REFUSAL'
        WHEN raw:response:status_code::NUMBER != 200  THEN 'HTTP_ERROR'
        ELSE 'SUCCESS'
    END                                                         AS outcome,
    raw:error:code::STRING                                      AS error_code,
    raw:error:message::STRING                                   AS error_message,
    raw:response:status_code::NUMBER                            AS http_status,
    raw:response:body:model::STRING                             AS model,
    c.value:message:content::STRING                             AS content,
    TRY_PARSE_JSON(c.value:message:content::STRING)             AS content_parsed,
    c.value:message:refusal::STRING                             AS refusal,
    c.value:finish_reason::STRING                               AS finish_reason,
    COALESCE(raw:response:body:usage:total_tokens::NUMBER, 0)   AS total_tokens,
    loaded_at
FROM RAW_BATCH_OUTPUTS,
     LATERAL FLATTEN(INPUT => raw:response:body:choices, OUTER => TRUE) c;


/*------------------------------------------------------------------------------
SILVER: DT_USAGE_FLAT — Flattened usage buckets with proper timestamps.
Foundation for all Gold-layer aggregations.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_USAGE_FLAT
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Silver - flattened usage records (Expires: 2026-03-28)'
AS
SELECT
    TO_TIMESTAMP(raw:start_time::NUMBER)                        AS bucket_start,
    TO_TIMESTAMP(raw:end_time::NUMBER)                          AS bucket_end,
    DATE_TRUNC('day', TO_TIMESTAMP(raw:start_time::NUMBER))     AS bucket_date,
    r.value:model::STRING                                       AS model,
    r.value:project_id::STRING                                  AS project_id,
    r.value:user_id::STRING                                     AS user_id,
    r.value:api_key_id::STRING                                  AS api_key_id,
    r.value:batch::BOOLEAN                                      AS is_batch,
    r.value:input_tokens::NUMBER                                AS input_tokens,
    r.value:output_tokens::NUMBER                               AS output_tokens,
    COALESCE(r.value:input_cached_tokens::NUMBER, 0)            AS cached_tokens,
    r.value:num_model_requests::NUMBER                          AS request_count,
    loaded_at
FROM RAW_USAGE_BUCKETS,
     LATERAL FLATTEN(INPUT => raw:results) r;


/*------------------------------------------------------------------------------
GOLD: DT_DAILY_TOKEN_SUMMARY — Aggregated daily cost estimation.
Pricing is illustrative; adjust rates to match your contract.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_DAILY_TOKEN_SUMMARY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Gold - daily token spend estimates (Expires: 2026-03-28)'
AS
SELECT
    bucket_date,
    model,
    project_id,
    is_batch,
    SUM(input_tokens)                                           AS total_input_tokens,
    SUM(output_tokens)                                          AS total_output_tokens,
    SUM(cached_tokens)                                          AS total_cached_tokens,
    SUM(request_count)                                          AS total_requests,
    SUM(input_tokens) + SUM(output_tokens)                      AS total_tokens,
    ROUND(SUM(input_tokens)  * IFF(model ILIKE '%mini%', 0.15, 2.50) / 1e6, 4)
                                                                AS est_input_cost_usd,
    ROUND(SUM(output_tokens) * IFF(model ILIKE '%mini%', 0.60, 10.0) / 1e6, 4)
                                                                AS est_output_cost_usd,
    ROUND(SUM(input_tokens)  * IFF(model ILIKE '%mini%', 0.15, 2.50) / 1e6
        + SUM(output_tokens) * IFF(model ILIKE '%mini%', 0.60, 10.0) / 1e6, 4)
                                                                AS est_total_cost_usd,
    ROUND(SUM(cached_tokens) / NULLIF(SUM(input_tokens), 0), 3)
                                                                AS overall_cache_hit_ratio,
    ROUND(SUM(input_tokens + output_tokens) / NULLIF(SUM(request_count), 0), 0)
                                                                AS avg_tokens_per_request
FROM DT_USAGE_FLAT
GROUP BY bucket_date, model, project_id, is_batch;


/*------------------------------------------------------------------------------
GOLD: DT_TOOL_CALL_ANALYTICS — Function call frequency and argument patterns.
Useful for understanding which tools get used and how.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_TOOL_CALL_ANALYTICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Gold - tool call analytics (Expires: 2026-03-28)'
AS
SELECT
    function_name,
    model,
    COUNT(*)                                                    AS invocation_count,
    COUNT(DISTINCT completion_id)                               AS unique_completions,
    AVG(argument_count)                                         AS avg_argument_count,
    SUM(prompt_tokens)                                          AS total_prompt_tokens,
    SUM(completion_tokens)                                      AS total_completion_tokens,
    ROUND(AVG(completion_tokens), 1)                            AS avg_tokens_per_call,
    MIN(created_at)                                             AS first_seen,
    MAX(created_at)                                             AS last_seen
FROM DT_TOOL_CALLS
GROUP BY function_name, model;


/*------------------------------------------------------------------------------
GOLD: DT_BATCH_SUMMARY — Batch job health dashboard.
Track success rates, error patterns, and token efficiency.
------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE DT_BATCH_SUMMARY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: Approach 2 Gold - batch health summary (Expires: 2026-03-28)'
AS
SELECT
    outcome,
    error_code,
    model,
    COUNT(*)                                                    AS record_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 1)                             AS pct_of_total,
    SUM(total_tokens)                                           AS total_tokens_used,
    ROUND(AVG(total_tokens), 0)                                 AS avg_tokens_per_record
FROM DT_BATCH_OUTCOMES
GROUP BY outcome, error_code, model;
