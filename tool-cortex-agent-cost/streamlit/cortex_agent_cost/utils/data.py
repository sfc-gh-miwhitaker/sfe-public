from snowflake.snowpark.context import get_active_session


def get_session():
    return get_active_session()


def get_daily_summary(session, lookback_days: int):
    return session.sql(f"""
        SELECT
            USAGE_DATE,
            REQUEST_COUNT,
            TOTAL_INPUT_TOKENS,
            TOTAL_OUTPUT_TOKENS,
            TOTAL_TOKENS,
            TOTAL_COST_USD
        FROM V_DAILY_COST_SUMMARY
        WHERE USAGE_DATE >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
        ORDER BY USAGE_DATE
    """).to_pandas()


def get_model_summary(session, lookback_days: int):
    return session.sql(f"""
        SELECT
            MODEL_NAME,
            COUNT(DISTINCT REQUEST_ID)  AS REQUEST_COUNT,
            SUM(INPUT_TOKENS)           AS TOTAL_INPUT_TOKENS,
            SUM(OUTPUT_TOKENS)          AS TOTAL_OUTPUT_TOKENS,
            SUM(TOKENS)                 AS TOTAL_TOKENS,
            SUM(TOTAL_COST_USD)         AS TOTAL_COST_USD,
            ROUND(
                SUM(TOTAL_COST_USD)
                / NULLIF(SUM(SUM(TOTAL_COST_USD)) OVER (), 0) * 100,
                2
            ) AS PCT_OF_TOTAL_COST
        FROM V_API_USAGE_COSTED
        WHERE START_TIME::DATE >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
        GROUP BY MODEL_NAME
        ORDER BY TOTAL_COST_USD DESC
    """).to_pandas()


def get_totals(session, lookback_days: int):
    row = session.sql(f"""
        SELECT
            COUNT(DISTINCT REQUEST_ID) AS TOTAL_REQUESTS,
            COALESCE(SUM(TOKENS), 0)   AS TOTAL_TOKENS,
            COALESCE(SUM(TOTAL_COST_USD), 0) AS TOTAL_COST_USD
        FROM V_API_USAGE_COSTED
        WHERE START_TIME::DATE >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
    """).to_pandas()
    return row.iloc[0] if len(row) > 0 else None
