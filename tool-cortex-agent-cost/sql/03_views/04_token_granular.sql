CREATE OR REPLACE VIEW V_TOKEN_GRANULAR
  COMMENT = 'TOOL: Per-model token breakdown via LATERAL FLATTEN on TOKENS_GRANULAR (Expires: 2026-04-22)'
AS
SELECT
    c.usage_date,
    c.user_name,
    c.request_id,
    c.agent_name,
    c.service_source,
    g.value:"request_id"::VARCHAR                 AS sub_request_id,
    svc.key                                       AS service_type,
    mdl.key                                       AS model_name,
    mdl.value:"input"::INT                        AS input_tokens,
    mdl.value:"cache_read_input"::INT             AS cache_read_tokens,
    mdl.value:"output"::INT                       AS output_tokens,
    COALESCE(mdl.value:"input"::INT, 0)
      + COALESCE(mdl.value:"cache_read_input"::INT, 0)
      + COALESCE(mdl.value:"output"::INT, 0)      AS total_tokens
FROM V_AGENT_COMBINED                              c,
    LATERAL FLATTEN(input => c.tokens_granular)    g,
    LATERAL FLATTEN(input => g.value, MODE => 'OBJECT') svc,
    LATERAL FLATTEN(input => svc.value, MODE => 'OBJECT') mdl
WHERE svc.key != 'start_time'
  AND svc.key != 'request_id';
