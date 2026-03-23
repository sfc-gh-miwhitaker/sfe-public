CREATE OR REPLACE VIEW V_CREDIT_GRANULAR
  COMMENT = 'TOOL: Per-model credit breakdown via LATERAL FLATTEN on CREDITS_GRANULAR (Expires: 2026-04-22)'
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
    mdl.value::FLOAT                              AS credits
FROM V_AGENT_COMBINED                              c,
    LATERAL FLATTEN(input => c.credits_granular)   g,
    LATERAL FLATTEN(input => g.value, MODE => 'OBJECT') svc,
    LATERAL FLATTEN(input => svc.value, MODE => 'OBJECT') mdl
WHERE svc.key != 'start_time'
  AND svc.key != 'request_id';
