USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_REST_API_COST;

CREATE OR REPLACE TABLE CORTEX_API_PRICING (
    MODEL_NAME               VARCHAR      NOT NULL,
    REGION_CATEGORY          VARCHAR      NOT NULL DEFAULT 'DEFAULT',
    INPUT_USD_PER_MTOK       NUMBER(10,4) NOT NULL,
    OUTPUT_USD_PER_MTOK      NUMBER(10,4) NOT NULL,
    CACHE_WRITE_USD_PER_MTOK NUMBER(10,4),
    CACHE_READ_USD_PER_MTOK  NUMBER(10,4),
    EFFECTIVE_DATE           DATE         NOT NULL DEFAULT '2026-03-20'::DATE,
    SOURCE_TABLE             VARCHAR,
    PRIMARY KEY (MODEL_NAME, REGION_CATEGORY)
)
COMMENT = 'TOOL: Cortex REST API pricing rates from Service Consumption Table (Expires: 2026-04-22)';

-- ==========================================================================
-- Table 6(b): REST API with Prompt Caching ($ per 1M tokens)
-- DEFAULT = Regional rate (used as fallback); GLOBAL where available
-- Effective: March 20, 2026
-- ==========================================================================

INSERT INTO CORTEX_API_PRICING
    (MODEL_NAME, REGION_CATEGORY, INPUT_USD_PER_MTOK, OUTPUT_USD_PER_MTOK, CACHE_WRITE_USD_PER_MTOK, CACHE_READ_USD_PER_MTOK, SOURCE_TABLE)
VALUES
    -- Claude models (AWS)
    ('claude-3-7-sonnet',              'DEFAULT',  3.00,  15.00,  3.75,  0.30, '6b'),
    ('claude-4-opus',                  'DEFAULT', 15.00,  75.00, 18.75,  1.50, '6b'),
    ('claude-4-sonnet',                'DEFAULT',  3.00,  15.00,  3.75,  0.30, '6b'),
    ('claude-sonnet-4-5',              'DEFAULT',  3.30,  16.50,  4.13,  0.33, '6b'),
    ('claude-sonnet-4-5',              'GLOBAL',   3.00,  15.00,  3.75,  0.30, '6b'),
    ('claude-sonnet-4-5-long-context', 'DEFAULT',  6.60,  24.75,  8.25,  0.66, '6b'),
    ('claude-sonnet-4-5-long-context', 'GLOBAL',   6.00,  22.50,  7.50,  0.60, '6b'),
    ('claude-sonnet-4-6',              'DEFAULT',  3.30,  16.50,  4.13,  0.33, '6b'),
    ('claude-sonnet-4-6',              'GLOBAL',   3.00,  15.00,  3.75,  0.30, '6b'),
    ('claude-haiku-4-5',               'DEFAULT',  1.10,   5.50,  1.38,  0.11, '6b'),
    ('claude-haiku-4-5',               'GLOBAL',   1.00,   5.00,  1.25,  0.10, '6b'),
    ('claude-opus-4-5',                'DEFAULT',  5.50,  27.50,  6.88,  0.55, '6b'),
    ('claude-opus-4-5',                'GLOBAL',   5.00,  25.00,  6.25,  0.50, '6b'),
    ('claude-opus-4-6',                'DEFAULT',  5.50,  27.50,  6.88,  0.55, '6b'),
    ('claude-opus-4-6',                'GLOBAL',   5.00,  25.00,  6.25,  0.50, '6b'),

    -- OpenAI models (Azure)
    ('openai-gpt-4.1',   'DEFAULT',  2.20,   8.80,  NULL, 0.55, '6b'),
    ('openai-gpt-4.1',   'GLOBAL',   2.00,   8.00,  NULL, 0.50, '6b'),
    ('openai-gpt-5',     'DEFAULT',  1.38,  11.00,  NULL, 0.14, '6b'),
    ('openai-gpt-5',     'GLOBAL',   1.25,  10.00,  NULL, 0.13, '6b'),
    ('openai-gpt-5-mini','DEFAULT',  0.28,   2.20,  NULL, 0.03, '6b'),
    ('openai-gpt-5-nano','DEFAULT',  0.06,   0.44,  NULL, 0.01, '6b'),
    ('openai-gpt-5.1',   'DEFAULT',  1.38,  11.00,  NULL, 0.14, '6b'),
    ('openai-gpt-5.1',   'GLOBAL',   1.25,  10.00,  NULL, 0.13, '6b'),
    ('openai-gpt-5.2',   'DEFAULT',  1.93,  15.40,  NULL, 0.19, '6b'),
    ('openai-gpt-5.2',   'GLOBAL',   1.75,  14.00,  NULL, 0.18, '6b'),
    ('openai-o4-mini',   'DEFAULT',  1.10,   4.40,  NULL, 0.28, '6b');

-- ==========================================================================
-- Table 6(c): REST API without Prompt Caching ($ per 1M tokens)
-- No regional split -- single DEFAULT rate per model
-- ==========================================================================

INSERT INTO CORTEX_API_PRICING
    (MODEL_NAME, REGION_CATEGORY, INPUT_USD_PER_MTOK, OUTPUT_USD_PER_MTOK, CACHE_WRITE_USD_PER_MTOK, CACHE_READ_USD_PER_MTOK, SOURCE_TABLE)
VALUES
    ('claude-3-5-sonnet',         'DEFAULT',  3.00, 15.00, NULL, NULL, '6c'),
    ('deepseek-r1',               'DEFAULT',  1.35,  5.40, NULL, NULL, '6c'),
    ('llama3.1-405b',             'DEFAULT',  2.40,  2.40, NULL, NULL, '6c'),
    ('llama3.1-70b',              'DEFAULT',  0.72,  0.72, NULL, NULL, '6c'),
    ('llama3.1-8b',               'DEFAULT',  0.22,  0.22, NULL, NULL, '6c'),
    ('llama3.2-1b',               'DEFAULT',  0.10,  0.10, NULL, NULL, '6c'),
    ('llama3.2-3b',               'DEFAULT',  0.15,  0.15, NULL, NULL, '6c'),
    ('llama3.3-70b',              'DEFAULT',  0.72,  0.72, NULL, NULL, '6c'),
    ('llama4-maverick',           'DEFAULT',  0.24,  0.97, NULL, NULL, '6c'),
    ('mistral-large',             'DEFAULT',  4.00, 12.00, NULL, NULL, '6c'),
    ('mistral-large2',            'DEFAULT',  2.00,  6.00, NULL, NULL, '6c'),
    ('mistral-7b',                'DEFAULT',  0.15,  0.20, NULL, NULL, '6c'),
    ('openai-gpt-oss-120b',      'DEFAULT',  0.15,  0.60, NULL, NULL, '6c'),
    ('snowflake-llama-3.3-70b',  'DEFAULT',  0.72,  0.72, NULL, NULL, '6c');
