from snowflake.snowpark.context import get_active_session

SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AGENT_COST"


def get_session():
    return get_active_session()


def run_query(sql):
    return get_session().sql(sql).to_pandas()


def get_config():
    return run_query(f"""
        SELECT setting_name, setting_value, description
        FROM {SCHEMA}.AGENT_COST_CONFIG
        ORDER BY setting_name
    """)


def get_credit_cost():
    result = run_query(f"""
        SELECT setting_value
        FROM {SCHEMA}.AGENT_COST_CONFIG
        WHERE setting_name = 'CREDIT_COST_USD'
    """)
    if len(result) > 0:
        return float(result.iloc[0, 0])
    return 3.00


def get_lookback_days():
    result = run_query(f"""
        SELECT setting_value
        FROM {SCHEMA}.AGENT_COST_CONFIG
        WHERE setting_name = 'LOOKBACK_DAYS'
    """)
    if len(result) > 0:
        return int(result.iloc[0, 0])
    return 90


def get_daily_summary(days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT usage_date, service_source, agent_name, user_name,
               request_count, total_credits, total_tokens, avg_latency_ms,
               child_request_count
        FROM {SCHEMA}.V_DAILY_SUMMARY
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        ORDER BY usage_date DESC, total_credits DESC
    """)


def get_overview_kpis(days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            SUM(credits)                          AS total_credits,
            SUM(tokens)                           AS total_tokens,
            COUNT(DISTINCT request_id)            AS total_requests,
            COUNT(DISTINCT COALESCE(agent_name, '(none)')) AS unique_agents,
            COUNT(DISTINCT user_name)             AS unique_users,
            AVG(latency_ms)                       AS avg_latency_ms
        FROM {SCHEMA}.V_AGENT_COMBINED
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
    """)


def get_daily_credits(days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            usage_date,
            service_source,
            SUM(credits) AS daily_credits,
            COUNT(DISTINCT request_id) AS daily_requests
        FROM {SCHEMA}.V_AGENT_COMBINED
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
          AND usage_date < CURRENT_DATE()
        GROUP BY usage_date, service_source
        ORDER BY usage_date
    """)


def get_top_agents(days=None, limit=10):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            COALESCE(agent_name, '(no agent object)') AS agent_name,
            service_source,
            COUNT(DISTINCT request_id) AS total_requests,
            COUNT(DISTINCT user_name) AS unique_users,
            SUM(credits) AS total_credits,
            SUM(tokens) AS total_tokens,
            AVG(latency_ms) AS avg_latency_ms
        FROM {SCHEMA}.V_AGENT_COMBINED
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        GROUP BY COALESCE(agent_name, '(no agent object)'), service_source
        ORDER BY total_credits DESC
        LIMIT {limit}
    """)


def get_agent_list():
    return run_query(f"""
        SELECT DISTINCT
            agent_name,
            service_source,
            agent_database_name,
            agent_schema_name,
            total_credits,
            total_requests
        FROM {SCHEMA}.V_AGENT_COST_SUMMARY
        ORDER BY total_credits DESC
    """)


def get_agent_daily_trend(agent_name, days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            usage_date,
            SUM(credits) AS daily_credits,
            SUM(tokens) AS daily_tokens,
            COUNT(DISTINCT request_id) AS daily_requests,
            COUNT(DISTINCT user_name) AS daily_users,
            AVG(latency_ms) AS avg_latency_ms
        FROM {SCHEMA}.V_AGENT_COMBINED
        WHERE COALESCE(agent_name, '(no agent object)') = '{agent_name}'
          AND usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
          AND usage_date < CURRENT_DATE()
        GROUP BY usage_date
        ORDER BY usage_date
    """)


def get_agent_token_breakdown(agent_name, days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            service_type,
            model_name,
            SUM(input_tokens) AS input_tokens,
            SUM(cache_read_tokens) AS cache_read_tokens,
            SUM(output_tokens) AS output_tokens,
            SUM(total_tokens) AS total_tokens,
            COUNT(DISTINCT request_id) AS request_count
        FROM {SCHEMA}.V_TOKEN_GRANULAR
        WHERE COALESCE(agent_name, '(no agent object)') = '{agent_name}'
          AND usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        GROUP BY service_type, model_name
        ORDER BY total_tokens DESC
    """)


def get_agent_parent_child(agent_name, days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            CASE WHEN parent_request_id IS NULL THEN 'Parent' ELSE 'Child' END AS request_type,
            COUNT(DISTINCT request_id) AS request_count,
            SUM(credits) AS total_credits,
            AVG(latency_ms) AS avg_latency_ms
        FROM {SCHEMA}.V_AGENT_COMBINED
        WHERE COALESCE(agent_name, '(no agent object)') = '{agent_name}'
          AND usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        GROUP BY CASE WHEN parent_request_id IS NULL THEN 'Parent' ELSE 'Child' END
    """)


def get_model_cost_summary():
    return run_query(f"""
        SELECT model_name, service_type,
               total_requests, total_credits, avg_credits_per_request
        FROM {SCHEMA}.V_MODEL_COST_SUMMARY
        ORDER BY total_credits DESC
    """)


def get_model_daily_credits(days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            usage_date,
            model_name,
            SUM(credits) AS daily_credits
        FROM {SCHEMA}.V_CREDIT_GRANULAR
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
          AND usage_date < CURRENT_DATE()
        GROUP BY usage_date, model_name
        ORDER BY usage_date
    """)


def get_service_type_breakdown(days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            service_type,
            SUM(credits) AS total_credits,
            COUNT(DISTINCT request_id) AS total_requests
        FROM {SCHEMA}.V_CREDIT_GRANULAR
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        GROUP BY service_type
        ORDER BY total_credits DESC
    """)


def get_cache_efficiency():
    return run_query(f"""
        SELECT model_name, service_type,
               total_requests, total_input_tokens, total_cache_read_tokens,
               total_output_tokens, total_all_tokens, cache_hit_pct
        FROM {SCHEMA}.V_CACHE_EFFICIENCY
        ORDER BY cache_hit_pct DESC
    """)


def get_user_spend(days=None, limit=50):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT
            user_name,
            COUNT(DISTINCT agent_name) AS agents_used,
            SUM(total_requests) AS total_requests,
            SUM(total_credits) AS total_credits,
            SUM(total_tokens) AS total_tokens,
            MIN(first_use) AS first_use,
            MAX(last_use) AS last_use
        FROM {SCHEMA}.V_USER_AGENT_SPEND
        WHERE first_use >= DATEADD('day', -{days}, CURRENT_DATE())
           OR last_use >= DATEADD('day', -{days}, CURRENT_DATE())
        GROUP BY user_name
        ORDER BY total_credits DESC
        LIMIT {limit}
    """)


def get_user_agent_detail(user_name, days=None):
    if days is None:
        days = get_lookback_days()
    return run_query(f"""
        SELECT agent_name, service_source,
               total_requests, active_days, total_credits, total_tokens,
               first_use, last_use
        FROM {SCHEMA}.V_USER_AGENT_SPEND
        WHERE user_name = '{user_name}'
          AND (first_use >= DATEADD('day', -{days}, CURRENT_DATE())
               OR last_use >= DATEADD('day', -{days}, CURRENT_DATE()))
        ORDER BY total_credits DESC
    """)


def get_forecast_data():
    return run_query(f"""
        SELECT usage_date, daily_credits, daily_tokens,
               daily_requests, daily_users, daily_agents
        FROM {SCHEMA}.V_FORECAST_BASE
        ORDER BY usage_date
    """)
