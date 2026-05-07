import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Cortex AI Functions — Cost Governance", layout="wide")

session = get_active_session()

USAGE_VIEW = "SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY"
USERS_VIEW = "SNOWFLAKE.ACCOUNT_USAGE.USERS"

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
    lookback_days = st.selectbox("Lookback window", [30, 60, 90, 180, 365], index=0)
    time_grain = st.radio(
        "Time granularity",
        ["Day", "Week", "Month", "Year"],
        index=0,
        help="Aggregate usage data by this time period.",
    )
    st.divider()
    st.caption(
        f"Estimated cost = credits x ${ai_credit_price:.2f}\n\n"
        "Source: `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`\n\n"
        "Latency: up to 60 min"
    )

GRAIN_SQL = {
    "Day": "DATE_TRUNC('day', h.START_TIME)",
    "Week": "DATE_TRUNC('week', h.START_TIME)",
    "Month": "DATE_TRUNC('month', h.START_TIME)",
    "Year": "DATE_TRUNC('year', h.START_TIME)",
}
grain_expr = GRAIN_SQL[time_grain]

st.title("Cortex AI Functions — Cost Governance")
st.caption(
    f"Granularity: **{time_grain}** · Lookback: **{lookback_days} days** · "
    f"`CORTEX_AI_FUNCTIONS_USAGE_HISTORY`"
)

tab_overview, tab_users, tab_functions, tab_controls = st.tabs(
    ["Overview", "Users", "Functions & Models", "Cost Controls"]
)


@st.cache_data(ttl=3600)
def fetch(sql):
    return session.sql(sql).to_pandas()


with tab_overview:
    st.subheader("Summary KPIs")
    kpi = fetch(f"""
        SELECT
            COUNT(DISTINCT QUERY_ID)                                   AS total_queries,
            ROUND(SUM(CREDITS), 4)                                     AS total_credits,
            ROUND(SUM(CREDITS) * {ai_credit_price}, 2)                 AS total_cost_usd,
            COUNT(DISTINCT USER_ID)                                    AS unique_users,
            COUNT(DISTINCT FUNCTION_NAME)                              AS unique_functions
        FROM {USAGE_VIEW}
        WHERE START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
    """)
    if not kpi.empty:
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Queries", f"{kpi['TOTAL_QUERIES'].iloc[0]:,.0f}")
        c2.metric("Credits", f"{kpi['TOTAL_CREDITS'].iloc[0]:,.2f}")
        c3.metric("Est. Cost", f"${kpi['TOTAL_COST_USD'].iloc[0]:,.2f}")
        c4.metric("Users", f"{kpi['UNIQUE_USERS'].iloc[0]:,.0f}")
        c5.metric("Functions", f"{kpi['UNIQUE_FUNCTIONS'].iloc[0]:,.0f}")

    st.subheader(f"Credit Consumption by {time_grain}")
    trend = fetch(f"""
        SELECT
            {grain_expr}                                               AS period,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd
        FROM {USAGE_VIEW} h
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
        GROUP BY 1
        ORDER BY 1
    """)
    if trend.empty:
        st.info("No Cortex AI Functions usage found in this window.")
    else:
        st.line_chart(trend.set_index("PERIOD")[["CREDITS", "COST_USD"]])
        st.dataframe(trend.sort_values("PERIOD", ascending=False), use_container_width=True)


with tab_users:
    st.subheader(f"Usage by User — per {time_grain}")
    user_trend = fetch(f"""
        SELECT
            {grain_expr}                                               AS period,
            u.NAME                                                     AS user_name,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd
        FROM {USAGE_VIEW} h
        JOIN {USERS_VIEW} u ON h.USER_ID = u.USER_ID
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
        GROUP BY 1, 2
        ORDER BY 1 DESC, credits DESC
    """)
    if user_trend.empty:
        st.info("No usage data found.")
    else:
        st.dataframe(user_trend, use_container_width=True)

    st.subheader(f"Top Users — last {lookback_days} days")
    top_users = fetch(f"""
        SELECT
            u.NAME                                                     AS user_name,
            u.EMAIL,
            u.DEFAULT_ROLE,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd,
            MIN(h.START_TIME)                                          AS first_seen,
            MAX(h.START_TIME)                                          AS last_seen
        FROM {USAGE_VIEW} h
        JOIN {USERS_VIEW} u ON h.USER_ID = u.USER_ID
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
        GROUP BY 1, 2, 3
        ORDER BY credits DESC
        LIMIT 25
    """)
    if not top_users.empty:
        st.bar_chart(top_users.set_index("USER_NAME")["COST_USD"])
        st.dataframe(top_users, use_container_width=True)


with tab_functions:
    st.subheader(f"Usage by Function — per {time_grain}")
    func_trend = fetch(f"""
        SELECT
            {grain_expr}                                               AS period,
            h.FUNCTION_NAME,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd
        FROM {USAGE_VIEW} h
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
        GROUP BY 1, 2
        ORDER BY 1 DESC, credits DESC
    """)
    if func_trend.empty:
        st.info("No usage data found.")
    else:
        st.dataframe(func_trend, use_container_width=True)

    st.subheader(f"Usage by Model — last {lookback_days} days")
    models = fetch(f"""
        SELECT
            h.MODEL_NAME,
            h.FUNCTION_NAME,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd,
            ROUND(AVG(h.CREDITS), 6)                                   AS avg_credits_per_query
        FROM {USAGE_VIEW} h
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
          AND h.MODEL_NAME IS NOT NULL
          AND h.MODEL_NAME != ''
        GROUP BY 1, 2
        ORDER BY credits DESC
    """)
    if models.empty:
        st.info("No model usage data found.")
    else:
        st.bar_chart(models.set_index("MODEL_NAME")["COST_USD"])
        st.dataframe(models, use_container_width=True)

    st.subheader(f"Cost by Function (total) — last {lookback_days} days")
    func_totals = fetch(f"""
        SELECT
            h.FUNCTION_NAME,
            COUNT(DISTINCT h.QUERY_ID)                                 AS queries,
            ROUND(SUM(h.CREDITS), 4)                                   AS credits,
            ROUND(SUM(h.CREDITS) * {ai_credit_price}, 2)               AS cost_usd
        FROM {USAGE_VIEW} h
        WHERE h.START_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP())
        GROUP BY 1
        ORDER BY credits DESC
    """)
    if not func_totals.empty:
        st.bar_chart(func_totals.set_index("FUNCTION_NAME")["COST_USD"])
        st.dataframe(func_totals, use_container_width=True)


with tab_controls:
    st.subheader("Cost Control Reference")
    st.caption(
        "Copy-paste SQL for governance setup. These queries do not create objects — "
        "run them in a Snowsight worksheet or use the notebook's governance cells."
    )

    with st.expander("Account-Level Monthly Spending Alert"):
        st.markdown(
            "Monitor total monthly AI Function credit consumption. "
            "Sends email when spending exceeds a threshold."
        )
        st.code("""
-- 1. Create notification integration (ACCOUNTADMIN)
CREATE OR REPLACE NOTIFICATION INTEGRATION SFE_AI_COST_ALERTS
    TYPE               = EMAIL
    ENABLED            = TRUE
    ALLOWED_RECIPIENTS = ('admin@company.com');  -- EDIT

-- 2. Create alert (adjust 1000 credit threshold)
CREATE OR REPLACE ALERT AI_FUNCTIONS_MONTHLY_SPEND_ALERT
    WAREHOUSE = SFE_AI_SPEND_CONTROLS_WH
    SCHEDULE  = 'USING CRON 0 * * * * UTC'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
        WHERE START_TIME >= DATE_TRUNC('month', CURRENT_TIMESTAMP())
        HAVING SUM(CREDITS) > 1000
    ))
    THEN
        CALL SEND_MONTHLY_SPEND_ALERT(1000);

ALTER ALERT AI_FUNCTIONS_MONTHLY_SPEND_ALERT RESUME;
        """, language="sql")

    with st.expander("Per-User Monthly Spending Limits"):
        st.markdown(
            "Grant each user a monthly credit budget. An hourly task revokes access "
            "when the budget is exceeded; a monthly task restores it on the 1st."
        )
        st.code("""
-- Revoke public access (required for enforcement)
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- Grant access with limit
CALL GRANT_AI_FUNCTIONS_ACCESS('ALICE', 1000);
CALL GRANT_AI_FUNCTIONS_ACCESS('BOB', 2000);

-- Check current status
SELECT USER_NAME, MONTHLY_CREDIT_LIMIT, IS_ACTIVE, REVOKED_AT
FROM AI_FUNCTIONS_ACCESS_CONTROL
ORDER BY USER_NAME;
        """, language="sql")

    with st.expander("Runaway Query Detection"):
        st.markdown(
            "Cancel in-flight AI queries exceeding a credit threshold. "
            "Credits consumed before cancellation are still charged."
        )
        st.code("""
-- Manual check (50 credit threshold)
CALL MONITOR_AND_CANCEL_RUNAWAY_QUERIES(50);

-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
    TASK_NAME => 'MONITOR_RUNAWAY_AI_QUERIES'
))
ORDER BY SCHEDULED_TIME DESC;
        """, language="sql")

    with st.expander("Best Practices"):
        st.markdown("""
- **Start with monitoring:** Establish baseline patterns before enabling automated controls.
- **Set conservative initial limits:** Begin low and adjust upward based on actual usage.
- **Use query tags:** Encourage `QUERY_TAG` session parameters for cost attribution by team.
- **Test alerts:** Set the threshold to 0 to trigger immediately, then reset.
- **Account for latency:** The ACCOUNT_USAGE view has up to 60 min latency.
- **Long-running exemptions:** Create `AI_FUNCTIONS_USER_LONG_RUNNING_ROLE` and exclude from runaway detection.

Source: [Managing Cortex AI Function costs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-func-cost-management)
        """)
