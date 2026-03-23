CREATE OR REPLACE VIEW V_MODEL_COST_SUMMARY
  COMMENT = 'TOOL: Per-model credit and token analysis from granular arrays (Expires: 2026-04-22)'
AS
SELECT
    model_name,
    service_type,
    COUNT(DISTINCT request_id)                    AS total_requests,
    SUM(credits)                                  AS total_credits,
    CASE WHEN COUNT(DISTINCT request_id) > 0
         THEN SUM(credits) / COUNT(DISTINCT request_id)
         ELSE 0
    END                                           AS avg_credits_per_request
FROM V_CREDIT_GRANULAR
GROUP BY model_name, service_type;
