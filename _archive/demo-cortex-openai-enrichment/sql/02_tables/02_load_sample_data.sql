/*==============================================================================
SAMPLE DATA - OpenAI Data Engineering
Uses GENERATOR + OBJECT_CONSTRUCT for escape-safe JSON generation.
Generates → stages → loads, matching the real customer workflow.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

-------------------------------------------------------------------------------
-- GENERATE CHAT COMPLETIONS → STAGE
-------------------------------------------------------------------------------

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


-------------------------------------------------------------------------------
-- GENERATE BATCH API OUTPUTS → STAGE
-------------------------------------------------------------------------------

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


-------------------------------------------------------------------------------
-- GENERATE USAGE API BUCKETS → STAGE (14 days, 3 results per bucket)
-------------------------------------------------------------------------------

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


-------------------------------------------------------------------------------
-- LOAD FROM STAGE → RAW TABLES
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

SELECT 'RAW_CHAT_COMPLETIONS' AS tbl, COUNT(*) AS row_count FROM RAW_CHAT_COMPLETIONS
UNION ALL SELECT 'RAW_BATCH_OUTPUTS', COUNT(*) FROM RAW_BATCH_OUTPUTS
UNION ALL SELECT 'RAW_USAGE_BUCKETS', COUNT(*) FROM RAW_USAGE_BUCKETS;
