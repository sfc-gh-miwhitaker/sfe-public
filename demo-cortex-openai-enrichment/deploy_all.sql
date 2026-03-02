/*==============================================================================
DEPLOY ALL - OpenAI Data Engineering with Cortex AI
Author: SE Community | Expires: 2026-03-28
INSTRUCTIONS: Open in Snowsight → Click "Run All"

AI-first data engineering: Transform complex OpenAI API responses using
Snowflake's native Cortex AI functions for classification, sentiment,
and summarization - no external API calls required.

Three approaches demonstrated:
  1. Schema-on-Read (FLATTEN + Views)
  2. Medallion Architecture (Dynamic Tables)
  3. Cortex AI Enrichment Pipeline ← THE HEADLINE FEATURE
==============================================================================*/

-- Expiration check (informational — warns but does not block)
SELECT
    '2026-03-28'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-03-28'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-03-28'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-03-28'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-03-28'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-03-28'::DATE) || ' days remaining'
    END AS demo_status;

-------------------------------------------------------------------------------
-- 1. SETUP
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_OPENAI_DATA_ENG_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: OpenAI data engineering compute (Expires: 2026-03-28)';

USE WAREHOUSE SFE_OPENAI_DATA_ENG_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG
  COMMENT = 'DEMO: OpenAI API data engineering patterns (Expires: 2026-03-28)';

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

-------------------------------------------------------------------------------
-- 2. STAGING INFRASTRUCTURE
--    Mirrors real workflow: JSONL files land in a stage before loading.
-------------------------------------------------------------------------------

CREATE OR REPLACE FILE FORMAT openai_jsonl_ff
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  COMMENT = 'DEMO: JSON format for OpenAI API response files (Expires: 2026-03-28)';

CREATE OR REPLACE STAGE openai_raw_stage
  FILE_FORMAT = openai_jsonl_ff
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'DEMO: Landing zone for OpenAI API export files (Expires: 2026-03-28)';

-------------------------------------------------------------------------------
-- 3. RAW TABLES
-------------------------------------------------------------------------------

CREATE OR REPLACE TABLE RAW_CHAT_COMPLETIONS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Chat Completions API responses (Expires: 2026-03-28)';

CREATE OR REPLACE TABLE RAW_BATCH_OUTPUTS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Batch API output records (Expires: 2026-03-28)';

CREATE OR REPLACE TABLE RAW_USAGE_BUCKETS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Usage API bucket records (Expires: 2026-03-28)';

-------------------------------------------------------------------------------
-- 4. GENERATE SYNTHETIC DATA → STAGE FILES
--    Uses GENERATOR + OBJECT_CONSTRUCT to build proper VARIANT objects.
--    No PARSE_JSON, no string escaping — native Snowflake data generation.
-------------------------------------------------------------------------------

-- 4a. Chat Completions (50 rows: text, tool calls, structured output, refusals)

CREATE OR REPLACE TEMPORARY TABLE _stg_completions AS

-- Text completions (30 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',                  'chatcmpl-' || id_sfx,
    'object',              'chat.completion',
    'created',             ts,
    'model',               model_name,
    'choices', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT_KEEP_NULL(
        'index',           0,
        'message', OBJECT_CONSTRUCT_KEEP_NULL(
            'role',        'assistant',
            'content',     content_text,
            'refusal',     NULL
        ),
        'logprobs',        NULL,
        'finish_reason',   IFF(finish_roll > 8, 'length', 'stop')
    )),
    'usage', OBJECT_CONSTRUCT(
        'prompt_tokens',              pt,
        'completion_tokens',          ct,
        'total_tokens',               pt + ct,
        'prompt_tokens_details',      OBJECT_CONSTRUCT(
            'cached_tokens',          LEAST(pt, UNIFORM(0, 1024, RANDOM())),
            'audio_tokens',           0
        ),
        'completion_tokens_details',  OBJECT_CONSTRUCT(
            'reasoning_tokens',       IFF(model_name LIKE '%4o-2024%', UNIFORM(0, 128, RANDOM()), 0),
            'audio_tokens',           0,
            'accepted_prediction_tokens', 0,
            'rejected_prediction_tokens', 0
        )
    ),
    'system_fingerprint',  'fp_' || fp_sfx
) AS data
FROM (
    SELECT
        RANDSTR(10, RANDOM()) AS id_sfx,
        RANDSTR(8, RANDOM())  AS fp_sfx,
        UNIFORM(1740067200, 1740672000, RANDOM()) AS ts,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'gpt-4o-2024-08-06'
            WHEN 2 THEN 'gpt-4o-mini-2024-07-18'
            ELSE        'gpt-4o-2024-08-06'
        END AS model_name,
        UNIFORM(20, 2000, RANDOM())  AS pt,
        UNIFORM(10, 500, RANDOM())   AS ct,
        UNIFORM(1, 10, RANDOM())     AS finish_roll,
        CASE MOD(SEQ4(), 8)
            WHEN 0 THEN 'Snowflake''s VARIANT data type stores semi-structured data in a compressed columnar format, supporting up to 16 MB per value. It automatically handles schema detection and enables dot-notation traversal for JSON, Avro, Parquet, and XML.'
            WHEN 1 THEN 'Based on the Q4 earnings data, revenue grew 12% year-over-year to $2.1B. Key drivers include cloud migration acceleration in financial services, 34% growth in consumption-based contracts, and expansion in the APAC region. Operating margins improved 200bps to 28%.'
            WHEN 2 THEN 'The current UTC time would need to come from a real-time source. You can use SELECT CURRENT_TIMESTAMP() in Snowflake to get the current timestamp in your session time zone.'
            WHEN 3 THEN 'Machine learning pipelines typically involve several stages: data ingestion, feature engineering, model training, validation, and deployment. Raw data is collected from databases, APIs, and streaming platforms before feature engineering transforms it for modeling.'
            WHEN 4 THEN 'I recommend a medallion architecture with bronze, silver, and gold layers for progressive data refinement. Bronze holds raw ingested data, silver applies schema enforcement and deduplication, and gold serves business-level aggregations.'
            WHEN 5 THEN 'The report recommends migrating legacy on-prem data warehouses to a cloud-native architecture within 18 months. Key benefits include 40% cost reduction, 3x query performance, and elastic scaling. Risks include data gravity and team reskilling needs.'
            WHEN 6 THEN 'Here is a Python function that trains a RandomForestClassifier on the provided DataFrame. It splits data 80/20 for train/test, fits 100 estimators, prints accuracy, and returns the trained model.'
                        || CHR(10) || CHR(10)
                        || 'def train_model(df, target_col):' || CHR(10)
                        || '    from sklearn.ensemble import RandomForestClassifier' || CHR(10)
                        || '    from sklearn.model_selection import train_test_split' || CHR(10)
                        || '    X_train, X_test, y_train, y_test = train_test_split(' || CHR(10)
                        || '        df.drop(columns=[target_col]), df[target_col], test_size=0.2)' || CHR(10)
                        || '    model = RandomForestClassifier(n_estimators=100)' || CHR(10)
                        || '    model.fit(X_train, y_train)' || CHR(10)
                        || '    print(f"Accuracy: {model.score(X_test, y_test):.3f}")' || CHR(10)
                        || '    return model'
            ELSE 'To optimize Snowflake warehouse costs, use multi-cluster warehouses with auto-scaling policies. Set AUTO_SUSPEND to 60 seconds for interactive workloads, and use separate warehouses for ETL vs. BI to avoid resource contention.'
        END AS content_text
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
) g

UNION ALL

-- Tool call completions (8 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',                  'chatcmpl-' || id_sfx,
    'object',              'chat.completion',
    'created',             ts,
    'model',               'gpt-4o-2024-08-06',
    'choices', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT_KEEP_NULL(
        'index',           0,
        'message', OBJECT_CONSTRUCT_KEEP_NULL(
            'role',        'assistant',
            'content',     NULL,
            'tool_calls',  ARRAY_CONSTRUCT(OBJECT_CONSTRUCT(
                'id',       'call_' || RANDSTR(6, RANDOM()),
                'type',     'function',
                'function', OBJECT_CONSTRUCT(
                    'name',      func_name,
                    'arguments', func_args
                )
            )),
            'refusal',     NULL
        ),
        'logprobs',        NULL,
        'finish_reason',   'tool_calls'
    )),
    'usage', OBJECT_CONSTRUCT(
        'prompt_tokens',              pt,
        'completion_tokens',          ct,
        'total_tokens',               pt + ct,
        'prompt_tokens_details',      OBJECT_CONSTRUCT('cached_tokens', 0, 'audio_tokens', 0),
        'completion_tokens_details',  OBJECT_CONSTRUCT(
            'reasoning_tokens', 0, 'audio_tokens', 0,
            'accepted_prediction_tokens', 0, 'rejected_prediction_tokens', 0
        )
    ),
    'system_fingerprint',  'fp_' || fp_sfx
) AS data
FROM (
    SELECT
        RANDSTR(10, RANDOM()) AS id_sfx,
        RANDSTR(8, RANDOM())  AS fp_sfx,
        UNIFORM(1740067200, 1740672000, RANDOM()) AS ts,
        UNIFORM(80, 400, RANDOM())   AS pt,
        UNIFORM(20, 150, RANDOM())   AS ct,
        CASE MOD(SEQ4(), 4)
            WHEN 0 THEN 'get_weather'
            WHEN 1 THEN 'execute_sql'
            WHEN 2 THEN 'get_stock_price'
            ELSE        'create_dashboard'
        END AS func_name,
        CASE MOD(SEQ4(), 4)
            WHEN 0 THEN TO_VARCHAR(OBJECT_CONSTRUCT(
                            'location', 'San Francisco, CA', 'unit', 'fahrenheit'))
            WHEN 1 THEN TO_VARCHAR(OBJECT_CONSTRUCT(
                            'query', 'SELECT customer_name, SUM(order_total) AS ltv FROM orders GROUP BY 1 ORDER BY 2 DESC LIMIT 10',
                            'database', 'analytics'))
            WHEN 2 THEN TO_VARCHAR(OBJECT_CONSTRUCT(
                            'symbol', IFF(UNIFORM(1,2,RANDOM())=1, 'SNOW', 'MSFT')))
            ELSE        TO_VARCHAR(OBJECT_CONSTRUCT(
                            'title', 'Q4 Revenue Overview',
                            'charts', ARRAY_CONSTRUCT(
                                OBJECT_CONSTRUCT('type', 'bar', 'metric', 'revenue', 'groupBy', 'region'),
                                OBJECT_CONSTRUCT('type', 'line', 'metric', 'growth_rate', 'groupBy', 'month')
                            ),
                            'sharing', OBJECT_CONSTRUCT('teams', ARRAY_CONSTRUCT('finance', 'executive'), 'public', FALSE)))
        END AS func_args
    FROM TABLE(GENERATOR(ROWCOUNT => 8))
) g

UNION ALL

-- Structured output completions (7 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',                  'chatcmpl-' || id_sfx,
    'object',              'chat.completion',
    'created',             ts,
    'model',               'gpt-4o-2024-08-06',
    'choices', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT_KEEP_NULL(
        'index',           0,
        'message', OBJECT_CONSTRUCT_KEEP_NULL(
            'role',        'assistant',
            'content',     struct_content,
            'refusal',     NULL
        ),
        'logprobs',        NULL,
        'finish_reason',   'stop'
    )),
    'usage', OBJECT_CONSTRUCT(
        'prompt_tokens',              pt,
        'completion_tokens',          ct,
        'total_tokens',               pt + ct,
        'prompt_tokens_details',      OBJECT_CONSTRUCT('cached_tokens', 0, 'audio_tokens', 0),
        'completion_tokens_details',  OBJECT_CONSTRUCT(
            'reasoning_tokens', 0, 'audio_tokens', 0,
            'accepted_prediction_tokens', 0, 'rejected_prediction_tokens', 0
        )
    ),
    'system_fingerprint',  'fp_' || fp_sfx
) AS data
FROM (
    SELECT
        RANDSTR(10, RANDOM()) AS id_sfx,
        RANDSTR(8, RANDOM())  AS fp_sfx,
        UNIFORM(1740067200, 1740672000, RANDOM()) AS ts,
        UNIFORM(200, 1000, RANDOM()) AS pt,
        UNIFORM(30, 200, RANDOM())   AS ct,
        CASE MOD(SEQ4(), 3)
            WHEN 0 THEN TO_VARCHAR(OBJECT_CONSTRUCT(
                'sentiment',  CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'positive' WHEN 2 THEN 'negative' ELSE 'neutral' END,
                'confidence', ROUND(UNIFORM(0.65, 0.99, RANDOM())::FLOAT, 2),
                'topics',     ARRAY_CONSTRUCT('product_quality', 'customer_service'),
                'entities',   ARRAY_CONSTRUCT(
                    OBJECT_CONSTRUCT('name', 'Acme Widget Pro', 'type', 'product'),
                    OBJECT_CONSTRUCT('name', 'Sarah Chen', 'type', 'person')
                ),
                'summary',    'Customer expresses high satisfaction with product quality and support responsiveness.'
            ))
            WHEN 1 THEN TO_VARCHAR(OBJECT_CONSTRUCT(
                'invoice_number', 'INV-2026-' || LPAD(UNIFORM(100, 9999, RANDOM())::VARCHAR, 4, '0'),
                'vendor',         'CloudTech Solutions',
                'date',           '2026-01-15',
                'line_items',     ARRAY_CONSTRUCT(
                    OBJECT_CONSTRUCT('description', 'Cloud Compute (Jan)', 'quantity', 1, 'unit_price', 4500.00, 'total', 4500.00),
                    OBJECT_CONSTRUCT('description', 'Storage (500TB)',     'quantity', 500, 'unit_price', 23.00, 'total', 11500.00),
                    OBJECT_CONSTRUCT('description', 'Support Premium',    'quantity', 1, 'unit_price', 2000.00, 'total', 2000.00)
                ),
                'subtotal', 18000.00, 'tax', 1620.00, 'total', 19620.00, 'currency', 'USD'
            ))
            ELSE TO_VARCHAR(OBJECT_CONSTRUCT(
                'category',          CASE UNIFORM(1,5,RANDOM()) WHEN 1 THEN 'billing' WHEN 2 THEN 'technical_support' WHEN 3 THEN 'feature_request' WHEN 4 THEN 'account_access' ELSE 'general_inquiry' END,
                'priority',          CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'high' WHEN 2 THEN 'medium' ELSE 'low' END,
                'sentiment',         CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'positive' WHEN 2 THEN 'negative' ELSE 'neutral' END,
                'suggested_routing', CASE UNIFORM(1,5,RANDOM()) WHEN 1 THEN 'billing_escalation' WHEN 2 THEN 'tier2_support' WHEN 3 THEN 'product_feedback' WHEN 4 THEN 'security_team' ELSE 'self_service' END
            ))
        END AS struct_content
    FROM TABLE(GENERATOR(ROWCOUNT => 7))
) g

UNION ALL

-- Refusal completions (5 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',                  'chatcmpl-' || RANDSTR(10, RANDOM()),
    'object',              'chat.completion',
    'created',             UNIFORM(1740067200, 1740672000, RANDOM()),
    'model',               'gpt-4o-2024-08-06',
    'choices', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT_KEEP_NULL(
        'index',           0,
        'message', OBJECT_CONSTRUCT_KEEP_NULL(
            'role',        'assistant',
            'content',     NULL,
            'refusal',     CASE MOD(SEQ4(), 3)
                WHEN 0 THEN 'I''m unable to help with that request as it involves generating content that could be harmful.'
                WHEN 1 THEN 'I cannot provide instructions for that activity as it may pose safety risks.'
                ELSE        'This request falls outside my guidelines. I''d be happy to help with an alternative approach.'
            END
        ),
        'logprobs',        NULL,
        'finish_reason',   'stop'
    )),
    'usage', OBJECT_CONSTRUCT(
        'prompt_tokens',              UNIFORM(20, 100, RANDOM()),
        'completion_tokens',          UNIFORM(10, 30, RANDOM()),
        'total_tokens',               UNIFORM(30, 130, RANDOM()),
        'prompt_tokens_details',      OBJECT_CONSTRUCT('cached_tokens', 0, 'audio_tokens', 0),
        'completion_tokens_details',  OBJECT_CONSTRUCT(
            'reasoning_tokens', 0, 'audio_tokens', 0,
            'accepted_prediction_tokens', 0, 'rejected_prediction_tokens', 0
        )
    ),
    'system_fingerprint',  'fp_' || RANDSTR(8, RANDOM())
) AS data
FROM TABLE(GENERATOR(ROWCOUNT => 5));

COPY INTO @openai_raw_stage/chat_completions/
FROM (SELECT data FROM _stg_completions)
FILE_FORMAT = (TYPE = 'JSON', COMPRESSION = NONE)
SINGLE = TRUE
OVERWRITE = TRUE;

DROP TABLE _stg_completions;


-- 4b. Batch API Outputs (25 rows: successes + errors)

CREATE OR REPLACE TEMPORARY TABLE _stg_batch AS

-- Successful batch results (20 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',        'batch_req_' || LPAD(SEQ4()::VARCHAR, 3, '0'),
    'custom_id', 'ticket-classify-' || LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0'),
    'response', OBJECT_CONSTRUCT(
        'status_code', 200,
        'request_id',  'req_' || RANDSTR(8, RANDOM()),
        'body', OBJECT_CONSTRUCT_KEEP_NULL(
            'id',                  'chatcmpl-b' || RANDSTR(6, RANDOM()),
            'object',              'chat.completion',
            'created',             UNIFORM(1740070000, 1740080000, RANDOM()),
            'model',               'gpt-4o-mini-2024-07-18',
            'choices', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT_KEEP_NULL(
                'index',           0,
                'message', OBJECT_CONSTRUCT_KEEP_NULL(
                    'role',        'assistant',
                    'content',     TO_VARCHAR(OBJECT_CONSTRUCT(
                        'category',          CASE MOD(SEQ4(), 6) WHEN 0 THEN 'billing' WHEN 1 THEN 'technical_support' WHEN 2 THEN 'feature_request' WHEN 3 THEN 'account_access' WHEN 4 THEN 'outage_report' ELSE 'general_inquiry' END,
                        'priority',          CASE MOD(SEQ4(), 3) WHEN 0 THEN 'high' WHEN 1 THEN 'medium' ELSE 'low' END,
                        'sentiment',         CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'positive' WHEN 2 THEN 'negative' ELSE 'neutral' END,
                        'suggested_routing', CASE MOD(SEQ4(), 6) WHEN 0 THEN 'billing_escalation' WHEN 1 THEN 'tier2_support' WHEN 2 THEN 'product_feedback' WHEN 3 THEN 'security_team' WHEN 4 THEN 'incident_response' ELSE 'self_service' END
                    )),
                    'refusal',     NULL
                ),
                'logprobs',        NULL,
                'finish_reason',   'stop'
            )),
            'usage', OBJECT_CONSTRUCT(
                'prompt_tokens',     pt,
                'completion_tokens', ct,
                'total_tokens',      pt + ct
            ),
            'system_fingerprint',  'fp_batch01'
        )
    ),
    'error', NULL
) AS data
FROM (
    SELECT
        UNIFORM(150, 600, RANDOM()) AS pt,
        UNIFORM(30, 50, RANDOM())   AS ct
    FROM TABLE(GENERATOR(ROWCOUNT => 20))
) g

UNION ALL

-- Error batch results (5 rows)
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'id',        'batch_req_' || LPAD((100 + SEQ4())::VARCHAR, 3, '0'),
    'custom_id', 'ticket-classify-' || LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0'),
    'response',  NULL,
    'error', OBJECT_CONSTRUCT(
        'code',    IFF(UNIFORM(1, 2, RANDOM()) = 1, 'rate_limit_exceeded', 'server_error'),
        'message', IFF(UNIFORM(1, 2, RANDOM()) = 1,
            'Rate limit reached for gpt-4o-mini in organization org-abc123 on tokens per min. Limit: 200000, Used: 198542, Requested: 3200.',
            'The server had an error processing your request. Sorry about that!')
    )
) AS data
FROM TABLE(GENERATOR(ROWCOUNT => 5));

COPY INTO @openai_raw_stage/batch_outputs/
FROM (SELECT data FROM _stg_batch)
FILE_FORMAT = (TYPE = 'JSON', COMPRESSION = NONE)
SINGLE = TRUE
OVERWRITE = TRUE;

DROP TABLE _stg_batch;


-- 4c. Usage API Buckets (14 days, 3 result entries per bucket)

CREATE OR REPLACE TEMPORARY TABLE _stg_usage AS
SELECT OBJECT_CONSTRUCT_KEEP_NULL(
    'object',     'bucket',
    'start_time', start_ts,
    'end_time',   start_ts + 86400,
    'results', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT_KEEP_NULL(
            'object',             'organization.usage.completions.result',
            'input_tokens',       UNIFORM(200000, 400000, RANDOM()),
            'output_tokens',      UNIFORM(100000, 200000, RANDOM()),
            'num_model_requests', UNIFORM(2500, 5000, RANDOM()),
            'input_cached_tokens',UNIFORM(50000, 120000, RANDOM()),
            'project_id',         'proj_customer_support',
            'user_id',            NULL,
            'api_key_id',         'key_prod_001',
            'model',              'gpt-4o-2024-08-06',
            'batch',              FALSE
        ),
        OBJECT_CONSTRUCT_KEEP_NULL(
            'object',             'organization.usage.completions.result',
            'input_tokens',       UNIFORM(50000, 150000, RANDOM()),
            'output_tokens',      UNIFORM(20000, 70000, RANDOM()),
            'num_model_requests', UNIFORM(800, 2000, RANDOM()),
            'input_cached_tokens',UNIFORM(5000, 30000, RANDOM()),
            'project_id',         'proj_customer_support',
            'user_id',            NULL,
            'api_key_id',         'key_prod_001',
            'model',              'gpt-4o-mini-2024-07-18',
            'batch',              TRUE
        ),
        OBJECT_CONSTRUCT_KEEP_NULL(
            'object',             'organization.usage.completions.result',
            'input_tokens',       UNIFORM(20000, 80000, RANDOM()),
            'output_tokens',      UNIFORM(10000, 40000, RANDOM()),
            'num_model_requests', UNIFORM(200, 1200, RANDOM()),
            'input_cached_tokens',UNIFORM(0, 10000, RANDOM()),
            'project_id',         'proj_internal_tools',
            'user_id',            'user_eng_01',
            'api_key_id',         'key_dev_002',
            'model',              'gpt-4o-2024-08-06',
            'batch',              FALSE
        )
    )
) AS data
FROM (
    SELECT 1739836800 + (SEQ4() * 86400) AS start_ts
    FROM TABLE(GENERATOR(ROWCOUNT => 14))
) g;

COPY INTO @openai_raw_stage/usage_buckets/
FROM (SELECT data FROM _stg_usage)
FILE_FORMAT = (TYPE = 'JSON', COMPRESSION = NONE)
SINGLE = TRUE
OVERWRITE = TRUE;

DROP TABLE _stg_usage;

-- Verify staged files
SELECT * FROM DIRECTORY(@openai_raw_stage);

-------------------------------------------------------------------------------
-- 5. LOAD FROM STAGE → RAW TABLES
--    This is the customer workflow: COPY INTO from staged JSONL files.
--    METADATA$FILENAME captures the source file path automatically.
-------------------------------------------------------------------------------

COPY INTO RAW_CHAT_COMPLETIONS (source_file, raw)
FROM (
    SELECT METADATA$FILENAME, $1
    FROM @openai_raw_stage/chat_completions/
);

COPY INTO RAW_BATCH_OUTPUTS (source_file, raw)
FROM (
    SELECT METADATA$FILENAME, $1
    FROM @openai_raw_stage/batch_outputs/
);

COPY INTO RAW_USAGE_BUCKETS (source_file, raw)
FROM (
    SELECT METADATA$FILENAME, $1
    FROM @openai_raw_stage/usage_buckets/
);

-- Quick sanity check
SELECT 'RAW_CHAT_COMPLETIONS' AS tbl, COUNT(*) AS row_count FROM RAW_CHAT_COMPLETIONS
UNION ALL SELECT 'RAW_BATCH_OUTPUTS', COUNT(*) FROM RAW_BATCH_OUTPUTS
UNION ALL SELECT 'RAW_USAGE_BUCKETS', COUNT(*) FROM RAW_USAGE_BUCKETS;

-------------------------------------------------------------------------------
-- 6. APPROACH 1: Schema-on-Read (FLATTEN + Views)
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- 7. APPROACH 2: Medallion Architecture (Dynamic Tables)
-------------------------------------------------------------------------------

-- Silver: Typed completions
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

-- Silver: Parsed tool calls
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

-- Silver: Batch outcomes
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

-- Silver: Flattened usage
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

-- Gold: Daily cost estimation
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

-- Gold: Tool call analytics
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

-- Gold: Batch health summary
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

-------------------------------------------------------------------------------
-- 8. APPROACH 3: Cortex AI Enrichment - THE STAR OF THE SHOW
--    Native AI analysis of OpenAI outputs using Snowflake Cortex.
--    Classifies topics, scores sentiment, summarizes content.
-------------------------------------------------------------------------------

CREATE OR REPLACE DYNAMIC TABLE DT_ENRICHED_COMPLETIONS
  TARGET_LAG = '10 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - Cortex-enriched completions (Expires: 2026-03-28)'
AS
WITH classified AS (
    SELECT
        completion_id, model, created_at, finish_reason, content,
        content_length, is_refusal, has_tool_calls, is_structured_output,
        prompt_tokens, completion_tokens, total_tokens,
        SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            content,
            ['technical_explanation', 'data_analysis', 'code_generation',
             'summarization', 'general_knowledge', 'recommendation']
        ) AS topic_result,
        SNOWFLAKE.CORTEX.SENTIMENT(content) AS sentiment_score,
        CASE WHEN content_length > 200
             THEN SNOWFLAKE.CORTEX.SUMMARIZE(content)
             ELSE content
        END AS content_summary
    FROM DT_COMPLETIONS
    WHERE content IS NOT NULL AND is_refusal = FALSE
)
SELECT
    completion_id, model, created_at, finish_reason, content,
    content_length, is_refusal, has_tool_calls, is_structured_output,
    prompt_tokens, completion_tokens, total_tokens,
    topic_result:label::STRING AS topic_classification,
    topic_result:score::FLOAT AS topic_confidence,
    sentiment_score,
    content_summary
FROM classified;

-- DT_BATCH_ENRICHED: QA OpenAI's classifications with Cortex
CREATE OR REPLACE DYNAMIC TABLE DT_BATCH_ENRICHED
  TARGET_LAG = '10 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - Cortex QA of batch classifications (Expires: 2026-03-28)'
AS
WITH classified AS (
    SELECT
        batch_request_id, custom_id, outcome, model, content, content_parsed,
        refusal, total_tokens,
        content_parsed:category::STRING                     AS openai_category,
        content_parsed:priority::STRING                     AS openai_priority,
        content_parsed:sentiment::STRING                    AS openai_sentiment,
        content_parsed:suggested_routing::STRING            AS openai_routing,
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
    batch_request_id, custom_id, outcome, model, content, content_parsed,
    openai_category, openai_priority, openai_sentiment, openai_routing,
    cortex_result:label::STRING                             AS cortex_category,
    cortex_sentiment_score,
    IFF(openai_category = cortex_result:label::STRING,
        'AGREE', 'DISAGREE')                                AS classification_agreement,
    total_tokens
FROM classified;

-- DT_PII_SCAN: Detect PII in AI outputs using Cortex COMPLETE
-- MODEL: claude-opus-4-6 per customer request (recommended for cost: llama3.1-70b)
CREATE OR REPLACE DYNAMIC TABLE DT_PII_SCAN
  TARGET_LAG = '30 minutes'
  WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  COMMENT = 'DEMO: Approach 3 - PII detection in AI outputs (Expires: 2026-03-28)'
AS
WITH completion_texts AS (
    SELECT completion_id AS source_id, 'completion' AS source_type,
           content AS text_to_scan, created_at
    FROM DT_COMPLETIONS
    WHERE content IS NOT NULL AND is_refusal = FALSE
    UNION ALL
    SELECT completion_id AS source_id, 'tool_call_args' AS source_type,
           arguments_json AS text_to_scan, created_at
    FROM DT_TOOL_CALLS
    WHERE arguments_json IS NOT NULL
),
scanned AS (
    SELECT source_id, source_type, text_to_scan, created_at,
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-opus-4-6',
            'Analyze the following text and return ONLY a JSON object with these fields: '
            || '{"has_pii": true/false, "pii_types": ["list of types found"], '
            || '"risk_level": "none/low/medium/high"}. '
            || 'PII types to check: email, phone, SSN, credit card, address, name, date of birth. '
            || 'Text to analyze: ' || LEFT(text_to_scan, 2000)
        ) AS pii_analysis_raw
    FROM completion_texts
)
SELECT source_id, source_type, text_to_scan, created_at,
       pii_analysis_raw, TRY_PARSE_JSON(pii_analysis_raw) AS pii_analysis_parsed
FROM scanned;

-- V_ENRICHMENT_DASHBOARD: Aggregated view for Streamlit
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

-------------------------------------------------------------------------------
-- 9. STREAMLIT APP - Interactive Explorer
--    Deploys the Streamlit in Snowflake app for exploring all three approaches.
-------------------------------------------------------------------------------

CREATE OR REPLACE STAGE streamlit_stage
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'DEMO: Stage for Streamlit app files (Expires: 2026-03-28)';

-- Write the Streamlit app code to stage via stored procedure
CREATE OR REPLACE PROCEDURE _deploy_streamlit_app()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'main'
AS $$
def main(session):
    app_code = '''"""
OpenAI Data Engineering Explorer
Streamlit in Snowflake app - AI-first data engineering with Cortex.
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="OpenAI + Cortex AI Data Engineering", layout="wide")
st.title("AI-First Data Engineering: OpenAI + Snowflake Cortex")
st.caption("Transform complex API responses with native AI classification, sentiment, and summarization")

approach = st.sidebar.radio(
    "Select Approach",
    [
        "Cortex Enrichment",
        "Schema-on-Read (Views)",
        "Medallion (Dynamic Tables)",
        "Raw Data Explorer",
    ],
)

# ---------------------------------------------------------------------------
# Cortex Enrichment (Primary)
# ---------------------------------------------------------------------------
if approach == "Cortex Enrichment":
    st.header("Cortex AI Enrichment Pipeline")
    st.success("Native AI analysis - no external API calls needed!")
    st.markdown(
        "Snowflake Cortex classifies, scores sentiment, summarizes, and scans for PII -- "
        "all within Snowflake, no external API calls."
    )

    tab_enrich, tab_batch_qa, tab_pii, tab_dash = st.tabs(
        ["Enriched Completions", "Batch QA", "PII Scan", "Dashboard"]
    )

    with tab_enrich:
        try:
            df = session.sql("SELECT * FROM DT_ENRICHED_COMPLETIONS").to_pandas()
            st.dataframe(df, use_container_width=True)
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Responses", len(df))
            with col2:
                if "SENTIMENT_SCORE" in df.columns:
                    st.metric("Avg Sentiment", f"{df['SENTIMENT_SCORE'].mean():.2f}")
            with col3:
                if "TOPIC_CLASSIFICATION" in df.columns:
                    st.metric("Topics Found", df["TOPIC_CLASSIFICATION"].nunique())
        except Exception as e:
            st.error(f"DT_ENRICHED_COMPLETIONS not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_batch_qa:
        try:
            df = session.sql("SELECT * FROM DT_BATCH_ENRICHED").to_pandas()
            st.dataframe(df, use_container_width=True)
            if "CLASSIFICATION_AGREEMENT" in df.columns:
                agree = df["CLASSIFICATION_AGREEMENT"].value_counts()
                st.subheader("OpenAI vs Cortex Classification Agreement")
                st.bar_chart(agree)
        except Exception as e:
            st.error(f"DT_BATCH_ENRICHED not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_pii:
        try:
            df = session.sql("SELECT * FROM DT_PII_SCAN").to_pandas()
            st.dataframe(df, use_container_width=True)
        except Exception as e:
            st.error(f"DT_PII_SCAN not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_dash:
        try:
            df = session.sql("SELECT * FROM V_ENRICHMENT_DASHBOARD").to_pandas()
            st.dataframe(df, use_container_width=True)

            if not df.empty and "TOPIC_CLASSIFICATION" in df.columns:
                st.subheader("Responses by Topic")
                st.bar_chart(df.set_index("TOPIC_CLASSIFICATION")["RESPONSE_COUNT"])

                st.subheader("Avg Sentiment by Topic")
                st.bar_chart(df.set_index("TOPIC_CLASSIFICATION")["AVG_SENTIMENT"])
        except Exception as e:
            st.error(f"V_ENRICHMENT_DASHBOARD not ready. Error: {e}")


# ---------------------------------------------------------------------------
# Schema-on-Read
# ---------------------------------------------------------------------------
elif approach == "Schema-on-Read (Views)":
    st.header("Schema-on-Read with FLATTEN + Views")
    st.markdown(
        "Raw VARIANT stays intact. Views use `LATERAL FLATTEN` to extract "
        "and reshape on demand. Zero ETL lag, full schema evolution tolerance."
    )

    tab_comp, tab_tools, tab_struct, tab_batch, tab_usage = st.tabs(
        ["Completions", "Tool Calls", "Structured Outputs", "Batch Results", "Token Usage"]
    )

    with tab_comp:
        st.subheader("V_COMPLETIONS")
        df = session.sql("SELECT * FROM V_COMPLETIONS ORDER BY created_at DESC").to_pandas()
        st.dataframe(df, use_container_width=True)

        col1, col2 = st.columns(2)
        with col1:
            st.metric("Total Completions", len(df))
        with col2:
            st.metric("Unique Models", df["MODEL"].nunique() if "MODEL" in df.columns else 0)

        st.subheader("Token Distribution by Finish Reason")
        token_df = session.sql("""
            SELECT finish_reason,
                   COUNT(*) AS responses,
                   SUM(total_tokens) AS total_tokens,
                   ROUND(AVG(total_tokens), 0) AS avg_tokens
            FROM V_COMPLETIONS
            GROUP BY finish_reason
            ORDER BY total_tokens DESC
        """).to_pandas()
        if not token_df.empty:
            st.bar_chart(token_df.set_index("FINISH_REASON")["TOTAL_TOKENS"])

    with tab_tools:
        st.subheader("V_TOOL_CALLS")
        df = session.sql("SELECT * FROM V_TOOL_CALLS ORDER BY created_at DESC").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Function Call Frequency")
        freq_df = session.sql("""
            SELECT function_name, COUNT(*) AS call_count
            FROM V_TOOL_CALLS
            GROUP BY function_name
            ORDER BY call_count DESC
        """).to_pandas()
        if not freq_df.empty:
            st.bar_chart(freq_df.set_index("FUNCTION_NAME")["CALL_COUNT"])

    with tab_struct:
        st.subheader("V_STRUCTURED_OUTPUTS")
        st.markdown("Completions where `content` is valid JSON -- parsed for traversal.")
        df = session.sql("SELECT * FROM V_STRUCTURED_OUTPUTS").to_pandas()
        st.dataframe(df, use_container_width=True)

    with tab_batch:
        st.subheader("V_BATCH_RESULTS")
        df = session.sql("SELECT * FROM V_BATCH_RESULTS ORDER BY batch_request_id").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Batch Outcome Distribution")
        outcome_df = session.sql("""
            SELECT outcome, COUNT(*) AS cnt
            FROM V_BATCH_RESULTS
            GROUP BY outcome
        """).to_pandas()
        if not outcome_df.empty:
            st.bar_chart(outcome_df.set_index("OUTCOME")["CNT"])

    with tab_usage:
        st.subheader("V_TOKEN_USAGE")
        df = session.sql("SELECT * FROM V_TOKEN_USAGE ORDER BY bucket_start").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Daily Token Consumption")
        daily_df = session.sql("""
            SELECT bucket_start::DATE AS day,
                   SUM(input_tokens) AS input_tok,
                   SUM(output_tokens) AS output_tok
            FROM V_TOKEN_USAGE
            GROUP BY day
            ORDER BY day
        """).to_pandas()
        if not daily_df.empty:
            st.line_chart(daily_df.set_index("DAY"))


# ---------------------------------------------------------------------------
# Medallion Architecture
# ---------------------------------------------------------------------------
elif approach == "Medallion (Dynamic Tables)":
    st.header("Medallion Architecture with Dynamic Tables")
    st.markdown(
        "Declarative pipeline: Bronze (raw) to Silver (typed) to Gold (aggregated). "
        "Snowflake handles incremental refresh automatically via `TARGET_LAG`."
    )

    tab_silver, tab_gold = st.tabs(["Silver Layer", "Gold Layer"])

    with tab_silver:
        silver_obj = st.selectbox(
            "Silver Table",
            ["DT_COMPLETIONS", "DT_TOOL_CALLS", "DT_BATCH_OUTCOMES", "DT_USAGE_FLAT"],
        )
        df = session.sql(f"SELECT * FROM {silver_obj} LIMIT 200").to_pandas()
        st.dataframe(df, use_container_width=True)
        st.metric("Row Count", len(df))

    with tab_gold:
        gold_obj = st.selectbox(
            "Gold Table",
            ["DT_DAILY_TOKEN_SUMMARY", "DT_TOOL_CALL_ANALYTICS", "DT_BATCH_SUMMARY"],
        )
        df = session.sql(f"SELECT * FROM {gold_obj}").to_pandas()
        st.dataframe(df, use_container_width=True)

        if gold_obj == "DT_DAILY_TOKEN_SUMMARY" and not df.empty:
            st.subheader("Estimated Daily Cost by Model")
            cost_df = session.sql("""
                SELECT bucket_date,
                       model,
                       SUM(est_total_cost_usd) AS daily_cost
                FROM DT_DAILY_TOKEN_SUMMARY
                GROUP BY bucket_date, model
                ORDER BY bucket_date
            """).to_pandas()
            if not cost_df.empty:
                st.line_chart(
                    cost_df.pivot(
                        index="BUCKET_DATE", columns="MODEL", values="DAILY_COST"
                    )
                )

        elif gold_obj == "DT_TOOL_CALL_ANALYTICS" and not df.empty:
            st.subheader("Tool Invocation Count")
            st.bar_chart(df.set_index("FUNCTION_NAME")["INVOCATION_COUNT"])

        elif gold_obj == "DT_BATCH_SUMMARY" and not df.empty:
            st.subheader("Batch Outcome Breakdown")
            st.bar_chart(df.set_index("OUTCOME")["RECORD_COUNT"])


# ---------------------------------------------------------------------------
# Raw Data Explorer
# ---------------------------------------------------------------------------
else:
    st.header("Raw Data Explorer")
    st.markdown("Explore the raw VARIANT payloads before any transformation.")

    raw_table = st.selectbox(
        "Raw Table",
        ["RAW_CHAT_COMPLETIONS", "RAW_BATCH_OUTPUTS", "RAW_USAGE_BUCKETS"],
    )

    df = session.sql(f"SELECT * FROM {raw_table} LIMIT 50").to_pandas()
    st.dataframe(df, use_container_width=True)

    st.subheader("Single Record Deep Dive")
    if not df.empty:
        row_idx = st.slider("Record Index", 0, len(df) - 1, 0)
        st.json(df.iloc[row_idx]["RAW"])
'''
    
    # Write the app to the stage
    session.file.put_stream(
        input_stream=__import__('io').BytesIO(app_code.encode('utf-8')),
        stage_location='@streamlit_stage/app.py',
        auto_compress=False,
        overwrite=True
    )
    
    return 'Streamlit app.py written to @streamlit_stage'
$$;

CALL _deploy_streamlit_app();

-- Create the Streamlit app object
CREATE OR REPLACE STREAMLIT OPENAI_DATA_EXPLORER
  ROOT_LOCATION = '@streamlit_stage'
  MAIN_FILE = 'app.py'
  QUERY_WAREHOUSE = SFE_OPENAI_DATA_ENG_WH
  COMMENT = 'DEMO: OpenAI + Cortex AI Data Engineering Explorer (Expires: 2026-03-28)';

-- Clean up the helper procedure
DROP PROCEDURE IF EXISTS _deploy_streamlit_app();

-------------------------------------------------------------------------------
-- DONE
-------------------------------------------------------------------------------

SELECT 'Deployment complete!' AS status,
       CURRENT_TIMESTAMP() AS completed_at,
       'All 3 approaches active including Cortex AI Enrichment!' AS note,
       'Streamlit app: OPENAI_DATA_EXPLORER' AS streamlit_app;
