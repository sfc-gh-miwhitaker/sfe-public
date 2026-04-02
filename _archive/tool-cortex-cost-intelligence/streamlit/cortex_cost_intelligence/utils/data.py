from snowflake.snowpark.context import get_active_session

SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE"


def get_session():
    return get_active_session()


def run_query(sql: str):
    return get_session().sql(sql).to_pandas()


def get_daily_summary(days: int = 30):
    return run_query(f"""
        SELECT usage_date, service_type, daily_unique_users, total_operations,
               total_credits, credits_per_user, credits_per_operation
        FROM {SCHEMA}.V_CORTEX_DAILY_SUMMARY
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        ORDER BY usage_date DESC, total_credits DESC
    """)


def get_kpis(days: int = 30):
    return run_query(f"""
        SELECT
            SUM(total_credits) AS total_credits,
            SUM(total_operations) AS total_operations,
            COUNT(DISTINCT service_type) AS active_services
        FROM {SCHEMA}.V_CORTEX_DAILY_SUMMARY
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
    """)


def get_anomalies():
    return run_query(f"""
        SELECT * FROM {SCHEMA}.V_COST_ANOMALIES_CURRENT
        ORDER BY alert_severity, wow_growth_pct DESC
    """)


def get_user_attribution(days: int = 30):
    return run_query(f"""
        SELECT user_name, service_type, model_name,
               SUM(credits_used) AS total_credits,
               SUM(operations) AS total_operations
        FROM {SCHEMA}.V_USER_SPEND_ATTRIBUTION
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
          AND user_name IS NOT NULL
        GROUP BY user_name, service_type, model_name
        ORDER BY total_credits DESC
    """)


def get_model_efficiency():
    return run_query(f"""
        SELECT * FROM {SCHEMA}.V_MODEL_EFFICIENCY
        ORDER BY function_name NULLS LAST, avg_credits_per_request ASC
    """)


def get_cost_export(days: int = 30):
    return run_query(f"""
        SELECT * FROM {SCHEMA}.V_CORTEX_COST_EXPORT
        WHERE usage_date >= DATEADD('day', -{days}, CURRENT_DATE())
        ORDER BY usage_date DESC
    """)


def get_forecast_data():
    return run_query(f"""
        SELECT * FROM {SCHEMA}.V_CORTEX_COST_FORECAST
        ORDER BY usage_date
    """)


def get_user_budgets():
    return run_query(f"""
        SELECT * FROM {SCHEMA}.CORTEX_USER_BUDGETS
        ORDER BY user_name
    """)


def get_config():
    return run_query(f"""
        SELECT setting_name, setting_value, description
        FROM {SCHEMA}.CORTEX_USAGE_CONFIG
        ORDER BY setting_name
    """)


def get_credit_cost():
    result = run_query(f"""
        SELECT setting_value
        FROM {SCHEMA}.CORTEX_USAGE_CONFIG
        WHERE setting_name = 'CREDIT_COST_USD'
    """)
    if len(result) > 0:
        return float(result.iloc[0, 0])
    return 3.00
