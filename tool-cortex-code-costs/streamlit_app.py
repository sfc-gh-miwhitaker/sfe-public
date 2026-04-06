import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Cortex Code Costs", layout="wide")

session = get_active_session()

st.title("Cortex Code CLI — Usage & Cost Dashboard")
st.caption("Source: `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` · ~1-2h latency")

with st.sidebar:
    st.header("Settings")
    ai_credit_price = st.number_input(
        "AI Credit price ($/credit)",
        min_value=1.80,
        max_value=2.20,
        value=2.00,
        step=0.01,
        help="On-demand global: $2.00. Adjust to your Capacity contracted rate.",
        format="%.2f",
    )
    lookback_days = st.selectbox("Lookback window", [30, 60, 90, 180], index=0)
    st.caption(f"Estimated cost = credits × ${ai_credit_price:.2f}")

tab_overview, tab_users, tab_models, tab_projections = st.tabs(
    ["Overview", "Users", "Models", "Projections"]
)

@st.cache_data(ttl=3600)
def fetch(sql):
    return session.sql(sql).to_pandas()


with tab_overview:
    st.subheader("Daily Usage")
    daily = fetch(f"""
        SELECT
            USAGE_TIME::DATE                          AS usage_date,
            COUNT(*)                                  AS requests,
            SUM(TOKENS)                               AS tokens,
            ROUND(SUM(TOKEN_CREDITS), 4)              AS credits,
            ROUND(SUM(TOKEN_CREDITS) * {ai_credit_price}, 2) AS cost_usd
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
        GROUP BY 1
        ORDER BY 1
    """)

    if daily.empty:
        st.info("No Cortex Code CLI usage found in this window.")
    else:
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Requests", f"{daily['REQUESTS'].sum():,.0f}")
        col2.metric("Total Tokens", f"{daily['TOKENS'].sum():,.0f}")
        col3.metric("Total Credits", f"{daily['CREDITS'].sum():,.2f}")
        col4.metric("Estimated Cost", f"${daily['COST_USD'].sum():,.2f}")

        st.line_chart(daily.set_index("USAGE_DATE")[["CREDITS", "COST_USD"]])
        st.dataframe(daily.sort_values("USAGE_DATE", ascending=False), use_container_width=True)

    st.subheader("Hourly Pattern (all time)")
    hourly = fetch("""
        SELECT
            HOUR(USAGE_TIME)             AS hour_of_day,
            COUNT(*)                     AS requests,
            SUM(TOKENS)                  AS tokens,
            ROUND(SUM(TOKEN_CREDITS), 4) AS credits
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        GROUP BY 1
        ORDER BY 1
    """)
    if not hourly.empty:
        st.bar_chart(hourly.set_index("HOUR_OF_DAY")["REQUESTS"])


with tab_users:
    st.subheader(f"Top Users — last {lookback_days} days")
    users = fetch(f"""
        SELECT
            USER_ID,
            COUNT(*)                                      AS requests,
            SUM(TOKENS)                                   AS tokens,
            ROUND(SUM(TOKEN_CREDITS), 4)                  AS credits,
            ROUND(SUM(TOKEN_CREDITS) * {ai_credit_price}, 2) AS cost_usd,
            MIN(USAGE_TIME)                               AS first_seen,
            MAX(USAGE_TIME)                               AS last_seen
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
        GROUP BY 1
        ORDER BY credits DESC
        LIMIT 25
    """)
    if users.empty:
        st.info("No usage data found.")
    else:
        st.bar_chart(users.set_index("USER_ID")["COST_USD"])
        st.dataframe(users, use_container_width=True)


with tab_models:
    st.subheader(f"Usage by Model — last {lookback_days} days")
    models_df = fetch(f"""
        SELECT
            f.key                                                     AS model,
            COUNT(*)                                                  AS requests,
            ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 4)   AS cache_read_credits,
            ROUND(SUM(NVL(f.value:cache_write_input::FLOAT, 0)), 4)  AS cache_write_credits,
            ROUND(SUM(NVL(f.value:input::FLOAT, 0)), 4)              AS input_credits,
            ROUND(SUM(NVL(f.value:output::FLOAT, 0)), 4)             AS output_credits,
            ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)
                + NVL(f.value:cache_write_input::FLOAT, 0)
                + NVL(f.value:input::FLOAT, 0)
                + NVL(f.value:output::FLOAT, 0)), 4)                 AS total_credits,
            ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)
                + NVL(f.value:cache_write_input::FLOAT, 0)
                + NVL(f.value:input::FLOAT, 0)
                + NVL(f.value:output::FLOAT, 0)) * {ai_credit_price}, 2) AS cost_usd
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY,
            LATERAL FLATTEN(input => CREDITS_GRANULAR) f
        WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
        GROUP BY 1
        ORDER BY total_credits DESC
    """)
    if models_df.empty:
        st.info("No model usage data found.")
    else:
        st.bar_chart(models_df.set_index("MODEL")["COST_USD"])
        st.dataframe(models_df, use_container_width=True)

    st.subheader("Cortex Code Model Pricing Reference")
    st.caption("Source: Snowflake Service Consumption Table, Table 6(e) — Cortex Code (April 1, 2026)")
    import pandas as pd
    pricing = pd.DataFrame([
        {"Model": "claude-4-sonnet",   "Input": 1.50, "Output": 7.50,  "Cache Write": 1.88, "Cache Read": 0.15},
        {"Model": "claude-opus-4-5",   "Input": 2.75, "Output": 13.75, "Cache Write": 3.44, "Cache Read": 0.28},
        {"Model": "claude-opus-4-6",   "Input": 2.75, "Output": 13.75, "Cache Write": 3.44, "Cache Read": 0.28},
        {"Model": "claude-sonnet-4-5", "Input": 1.65, "Output": 8.25,  "Cache Write": 2.07, "Cache Read": 0.17},
        {"Model": "claude-sonnet-4-6", "Input": 1.65, "Output": 8.25,  "Cache Write": 2.07, "Cache Read": 0.17},
        {"Model": "openai-gpt-5.2",    "Input": 0.97, "Output": 7.70,  "Cache Write": None, "Cache Read": 0.10},
        {"Model": "openai-gpt-5.4",    "Input": 1.38, "Output": 8.25,  "Cache Write": None, "Cache Read": 0.14},
    ])
    pricing.rename(columns={
        "Input": "Input (AI Credits/1M)",
        "Output": "Output (AI Credits/1M)",
        "Cache Write": "Cache Write (AI Credits/1M)",
        "Cache Read": "Cache Read (AI Credits/1M)",
    }, inplace=True)
    st.dataframe(pricing, use_container_width=True, hide_index=True)


with tab_projections:
    st.subheader("Cost Projections")
    st.caption("Based on the 22 busiest working days on record (proxy for a peak working month).")

    proj = fetch(f"""
        WITH daily_costs AS (
            SELECT
                USAGE_TIME::DATE        AS usage_date,
                SUM(TOKEN_CREDITS)      AS daily_credits
            FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
            GROUP BY 1
            ORDER BY daily_credits DESC
            LIMIT 22
        ),
        stats AS (
            SELECT
                MIN(daily_credits)  AS min_daily,
                AVG(daily_credits)  AS mean_daily,
                MAX(daily_credits)  AS max_daily
            FROM daily_costs
        )
        SELECT 'Per Day'    AS period, 1    AS sort_key, ROUND(min_daily, 2) AS min_credits, ROUND(mean_daily, 2) AS mean_credits, ROUND(max_daily, 2) AS max_credits,
            ROUND(min_daily * {ai_credit_price}, 2) AS min_usd, ROUND(mean_daily * {ai_credit_price}, 2) AS mean_usd, ROUND(max_daily * {ai_credit_price}, 2) AS max_usd FROM stats
        UNION ALL
        SELECT 'Per Week',  2, ROUND(min_daily*5,2),   ROUND(mean_daily*5,2),   ROUND(max_daily*5,2),
            ROUND(min_daily*5*{ai_credit_price},2), ROUND(mean_daily*5*{ai_credit_price},2), ROUND(max_daily*5*{ai_credit_price},2) FROM stats
        UNION ALL
        SELECT 'Per Month', 3, ROUND(min_daily*22,2),  ROUND(mean_daily*22,2),  ROUND(max_daily*22,2),
            ROUND(min_daily*22*{ai_credit_price},2), ROUND(mean_daily*22*{ai_credit_price},2), ROUND(max_daily*22*{ai_credit_price},2) FROM stats
        UNION ALL
        SELECT 'Per Year',  4, ROUND(min_daily*260,2), ROUND(mean_daily*260,2), ROUND(max_daily*260,2),
            ROUND(min_daily*260*{ai_credit_price},2), ROUND(mean_daily*260*{ai_credit_price},2), ROUND(max_daily*260*{ai_credit_price},2) FROM stats
        ORDER BY sort_key
    """)

    if proj.empty:
        st.info("No usage data found for projections.")
    else:
        proj_display = proj.drop(columns=["SORT_KEY"])
        st.dataframe(proj_display, use_container_width=True, hide_index=True)

        st.subheader("Mean Cost Projection")
        import pandas as pd
        chart_data = pd.DataFrame({
            "Period": proj_display["PERIOD"],
            "Mean Cost (USD)": proj_display["MEAN_USD"],
        }).set_index("Period")
        st.bar_chart(chart_data)
