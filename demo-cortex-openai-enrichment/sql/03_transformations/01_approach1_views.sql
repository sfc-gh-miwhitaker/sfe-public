/*==============================================================================
APPROACH 1: Schema-on-Read with FLATTEN + Views
Philosophy: Keep raw VARIANT intact. Create layered views that extract and
            flatten on demand. Zero ETL lag, full schema evolution tolerance.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

/*------------------------------------------------------------------------------
V_COMPLETIONS — One row per choice from Chat Completions responses.
Handles: text content, refusals, multi-choice (n>1), polymorphic content field.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_COMPLETIONS
  COMMENT = 'DEMO: Approach 1 - Flattened chat completions, one row per choice (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                          AS completion_id,
    raw:model::STRING                                       AS model,
    TO_TIMESTAMP(raw:created::NUMBER)                       AS created_at,
    raw:system_fingerprint::STRING                          AS system_fingerprint,
    c.value:index::NUMBER                                   AS choice_index,
    c.value:finish_reason::STRING                           AS finish_reason,
    c.value:message:role::STRING                            AS message_role,
    c.value:message:content::STRING                         AS content,
    c.value:message:refusal::STRING                         AS refusal,
    IFF(c.value:message:tool_calls IS NOT NULL, TRUE, FALSE)
                                                            AS has_tool_calls,
    ARRAY_SIZE(c.value:message:tool_calls)                  AS tool_call_count,
    raw:usage:prompt_tokens::NUMBER                         AS prompt_tokens,
    raw:usage:completion_tokens::NUMBER                     AS completion_tokens,
    raw:usage:total_tokens::NUMBER                          AS total_tokens,
    raw:usage:prompt_tokens_details:cached_tokens::NUMBER   AS cached_tokens,
    raw:usage:completion_tokens_details:reasoning_tokens::NUMBER
                                                            AS reasoning_tokens,
    loaded_at,
    source_file
FROM RAW_CHAT_COMPLETIONS,
     LATERAL FLATTEN(INPUT => raw:choices) c;


/*------------------------------------------------------------------------------
V_TOOL_CALLS — One row per tool/function call extracted from completions.
Parses the JSON arguments string into a traversable VARIANT.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_TOOL_CALLS
  COMMENT = 'DEMO: Approach 1 - Flattened tool calls with parsed arguments (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                          AS completion_id,
    raw:model::STRING                                       AS model,
    TO_TIMESTAMP(raw:created::NUMBER)                       AS created_at,
    c.value:index::NUMBER                                   AS choice_index,
    t.value:id::STRING                                      AS tool_call_id,
    t.value:type::STRING                                    AS tool_type,
    t.value:function:name::STRING                           AS function_name,
    t.value:function:arguments::STRING                      AS arguments_raw,
    TRY_PARSE_JSON(t.value:function:arguments::STRING)      AS arguments_parsed,
    raw:usage:prompt_tokens::NUMBER                         AS prompt_tokens,
    raw:usage:completion_tokens::NUMBER                     AS completion_tokens
FROM RAW_CHAT_COMPLETIONS,
     LATERAL FLATTEN(INPUT => raw:choices) c,
     LATERAL FLATTEN(INPUT => c.value:message:tool_calls, OUTER => TRUE) t
WHERE c.value:message:tool_calls IS NOT NULL;


/*------------------------------------------------------------------------------
V_STRUCTURED_OUTPUTS — Completions where content is valid JSON (structured mode).
Extracts the parsed content as a traversable object.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_STRUCTURED_OUTPUTS
  COMMENT = 'DEMO: Approach 1 - Structured JSON outputs parsed from content (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                          AS completion_id,
    raw:model::STRING                                       AS model,
    TO_TIMESTAMP(raw:created::NUMBER)                       AS created_at,
    c.value:message:content::STRING                         AS content_raw,
    TRY_PARSE_JSON(c.value:message:content::STRING)         AS content_parsed,
    raw:usage:total_tokens::NUMBER                          AS total_tokens
FROM RAW_CHAT_COMPLETIONS,
     LATERAL FLATTEN(INPUT => raw:choices) c
WHERE TRY_PARSE_JSON(c.value:message:content::STRING) IS NOT NULL
  AND c.value:message:refusal IS NULL;


/*------------------------------------------------------------------------------
V_BATCH_RESULTS — Unwrapped batch API responses joined to custom_id metadata.
Separates successes from errors for clean downstream consumption.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_BATCH_RESULTS
  COMMENT = 'DEMO: Approach 1 - Unwrapped batch results with error handling (Expires: 2026-03-28)'
AS
SELECT
    raw:id::STRING                                          AS batch_request_id,
    raw:custom_id::STRING                                   AS custom_id,
    IFF(raw:error IS NOT NULL, 'ERROR', 'SUCCESS')          AS outcome,
    raw:error:code::STRING                                  AS error_code,
    raw:error:message::STRING                               AS error_message,
    raw:response:status_code::NUMBER                        AS http_status,
    raw:response:request_id::STRING                         AS request_id,
    raw:response:body:id::STRING                            AS completion_id,
    raw:response:body:model::STRING                         AS model,
    TO_TIMESTAMP(raw:response:body:created::NUMBER)         AS created_at,
    c.value:message:content::STRING                         AS content,
    c.value:message:refusal::STRING                         AS refusal,
    c.value:finish_reason::STRING                           AS finish_reason,
    raw:response:body:usage:prompt_tokens::NUMBER           AS prompt_tokens,
    raw:response:body:usage:completion_tokens::NUMBER       AS completion_tokens,
    raw:response:body:usage:total_tokens::NUMBER            AS total_tokens,
    loaded_at
FROM RAW_BATCH_OUTPUTS,
     LATERAL FLATTEN(INPUT => raw:response:body:choices, OUTER => TRUE) c;


/*------------------------------------------------------------------------------
V_TOKEN_USAGE — Flattened usage API buckets with time, model, and project dims.
Converts Unix timestamps to proper TIMESTAMP_NTZ for time-series analysis.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW V_TOKEN_USAGE
  COMMENT = 'DEMO: Approach 1 - Flattened usage buckets for time-series analysis (Expires: 2026-03-28)'
AS
SELECT
    TO_TIMESTAMP(raw:start_time::NUMBER)                    AS bucket_start,
    TO_TIMESTAMP(raw:end_time::NUMBER)                      AS bucket_end,
    r.value:model::STRING                                   AS model,
    r.value:project_id::STRING                              AS project_id,
    r.value:user_id::STRING                                 AS user_id,
    r.value:api_key_id::STRING                              AS api_key_id,
    r.value:batch::BOOLEAN                                  AS is_batch,
    r.value:input_tokens::NUMBER                            AS input_tokens,
    r.value:output_tokens::NUMBER                           AS output_tokens,
    r.value:input_cached_tokens::NUMBER                     AS cached_tokens,
    r.value:num_model_requests::NUMBER                      AS request_count,
    r.value:input_tokens::NUMBER + r.value:output_tokens::NUMBER
                                                            AS total_tokens,
    loaded_at
FROM RAW_USAGE_BUCKETS,
     LATERAL FLATTEN(INPUT => raw:results) r;


/*------------------------------------------------------------------------------
EXAMPLE QUERIES — Run these interactively to explore Approach 1.
(Uncomment and run individually in Snowsight.)
------------------------------------------------------------------------------*/

-- Token cost by model (assumes $2.50/1M input, $10/1M output for gpt-4o):
--
-- SELECT
--     model,
--     SUM(input_tokens)   AS total_input_tokens,
--     SUM(output_tokens)  AS total_output_tokens,
--     SUM(request_count)  AS total_requests,
--     ROUND(SUM(input_tokens)  * 2.50 / 1000000, 2) AS est_input_cost,
--     ROUND(SUM(output_tokens) * 10.0 / 1000000, 2) AS est_output_cost
-- FROM V_TOKEN_USAGE
-- GROUP BY model
-- ORDER BY est_output_cost DESC;
--
-- Tool call frequency:
--
-- SELECT function_name, COUNT(*) AS call_count
-- FROM V_TOOL_CALLS
-- GROUP BY function_name
-- ORDER BY call_count DESC;
