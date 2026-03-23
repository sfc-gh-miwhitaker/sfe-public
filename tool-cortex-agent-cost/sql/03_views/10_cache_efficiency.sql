CREATE OR REPLACE VIEW V_CACHE_EFFICIENCY
  COMMENT = 'TOOL: Cache read token ratio by model — measures prompt caching effectiveness (Expires: 2026-04-22)'
AS
SELECT
    model_name,
    service_type,
    COUNT(DISTINCT request_id)                    AS total_requests,
    SUM(input_tokens)                             AS total_input_tokens,
    SUM(cache_read_tokens)                        AS total_cache_read_tokens,
    SUM(output_tokens)                            AS total_output_tokens,
    SUM(total_tokens)                             AS total_all_tokens,
    CASE WHEN SUM(input_tokens) + SUM(COALESCE(cache_read_tokens, 0)) > 0
         THEN ROUND(
             SUM(COALESCE(cache_read_tokens, 0))::FLOAT
             / (SUM(input_tokens) + SUM(COALESCE(cache_read_tokens, 0)))
             * 100, 2)
         ELSE 0
    END                                           AS cache_hit_pct
FROM V_TOKEN_GRANULAR
GROUP BY model_name, service_type;
