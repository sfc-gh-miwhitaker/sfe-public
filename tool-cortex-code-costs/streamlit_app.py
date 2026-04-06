import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Cortex Code Costs", layout="wide")

session = get_active_session()

CLI_TABLE       = "SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY"
SNOWSIGHT_TABLE = "SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY"

with st.sidebar:
    st.header("Settings")
    data_source = st.radio(
        "Data Source",
        ["Combined (CLI + Snowsight)", "CLI only", "Snowsight only"],
        index=0,
        help="CLI = Cortex Code CLI (`snow` / terminal). Snowsight = Cortex Code inside the browser IDE.",
    )
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

if data_source == "CLI only":
    source_from = CLI_TABLE
    source_label = "CLI"
elif data_source == "Snowsight only":
    source_from = SNOWSIGHT_TABLE
    source_label = "Snowsight"
else:
    source_from = f"""(
        SELECT 'cli'       AS source, * FROM {CLI_TABLE}
        UNION ALL
        SELECT 'snowsight' AS source, * FROM {SNOWSIGHT_TABLE}
    ) t"""
    source_label = "CLI + Snowsight"

st.title("Cortex Code — Usage & Cost Dashboard")
st.caption(
    f"Source: `{source_label}` · ~1-2h latency"
    + (" · `CORTEX_CODE_CLI_USAGE_HISTORY` + `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY`"
       if data_source == "Combined (CLI + Snowsight)"
       else f" · `CORTEX_CODE_{source_label.upper()}_USAGE_HISTORY`")
)

tab_overview, tab_users, tab_models, tab_projections, tab_governance = st.tabs(
    ["Overview", "Users", "Models", "Projections", "Governance"]
)

@st.cache_data(ttl=3600)
def fetch(sql):
    return session.sql(sql).to_pandas()


with tab_overview:
    if data_source == "Combined (CLI + Snowsight)":
        st.subheader("Source Comparison")
        split = fetch(f"""
            SELECT
                source,
                COUNT(*)                                      AS requests,
                SUM(TOKENS)                                   AS tokens,
                ROUND(SUM(TOKEN_CREDITS), 4)                  AS credits,
                ROUND(SUM(TOKEN_CREDITS) * {ai_credit_price}, 2) AS cost_usd
            FROM {source_from}
            WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
            GROUP BY 1
            ORDER BY 1
        """)
        if not split.empty:
            cols = st.columns(len(split))
            for i, row in split.iterrows():
                cols[i].metric(
                    f"{row['SOURCE'].capitalize()} Cost",
                    f"${row['COST_USD']:,.2f}",
                    help=f"{row['REQUESTS']:,.0f} requests · {row['CREDITS']:,.2f} credits",
                )

    st.subheader("Daily Usage")
    daily = fetch(f"""
        SELECT
            USAGE_TIME::DATE                          AS usage_date,
            COUNT(*)                                  AS requests,
            SUM(TOKENS)                               AS tokens,
            ROUND(SUM(TOKEN_CREDITS), 4)              AS credits,
            ROUND(SUM(TOKEN_CREDITS) * {ai_credit_price}, 2) AS cost_usd
        FROM {source_from}
        WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
        GROUP BY 1
        ORDER BY 1
    """)

    if daily.empty:
        st.info("No Cortex Code usage found in this window.")
    else:
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Requests", f"{daily['REQUESTS'].sum():,.0f}")
        col2.metric("Total Tokens", f"{daily['TOKENS'].sum():,.0f}")
        col3.metric("Total Credits", f"{daily['CREDITS'].sum():,.2f}")
        col4.metric("Estimated Cost", f"${daily['COST_USD'].sum():,.2f}")

        st.line_chart(daily.set_index("USAGE_DATE")[["CREDITS", "COST_USD"]])
        st.dataframe(daily.sort_values("USAGE_DATE", ascending=False), use_container_width=True)

    st.subheader("Hourly Pattern (all time)")
    hourly = fetch(f"""
        SELECT
            HOUR(USAGE_TIME)             AS hour_of_day,
            COUNT(*)                     AS requests,
            SUM(TOKENS)                  AS tokens,
            ROUND(SUM(TOKEN_CREDITS), 4) AS credits
        FROM {source_from}
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
        FROM {source_from}
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

    if data_source == "Combined (CLI + Snowsight)":
        st.subheader("Users — CLI vs Snowsight breakdown")
        users_split = fetch(f"""
            SELECT
                source,
                USER_ID,
                COUNT(*)                                      AS requests,
                ROUND(SUM(TOKEN_CREDITS), 4)                  AS credits,
                ROUND(SUM(TOKEN_CREDITS) * {ai_credit_price}, 2) AS cost_usd
            FROM {source_from}
            WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
            GROUP BY 1, 2
            ORDER BY credits DESC
            LIMIT 50
        """)
        if not users_split.empty:
            st.dataframe(users_split, use_container_width=True)


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
        FROM {source_from},
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

    if data_source == "Combined (CLI + Snowsight)":
        st.subheader("Models — CLI vs Snowsight breakdown")
        models_split = fetch(f"""
            SELECT
                source,
                f.key                                                     AS model,
                ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)
                    + NVL(f.value:cache_write_input::FLOAT, 0)
                    + NVL(f.value:input::FLOAT, 0)
                    + NVL(f.value:output::FLOAT, 0)), 4)                 AS total_credits,
                ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)
                    + NVL(f.value:cache_write_input::FLOAT, 0)
                    + NVL(f.value:input::FLOAT, 0)
                    + NVL(f.value:output::FLOAT, 0)) * {ai_credit_price}, 2) AS cost_usd
            FROM {source_from},
                LATERAL FLATTEN(input => CREDITS_GRANULAR) f
            WHERE USAGE_TIME >= DATEADD('day', -{lookback_days}, CURRENT_TIMESTAMP)
            GROUP BY 1, 2
            ORDER BY total_credits DESC
        """)
        if not models_split.empty:
            st.dataframe(models_split, use_container_width=True)

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
            FROM {source_from}
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


with tab_governance:
    import pandas as pd

    st.subheader("Spend Controls & Best Practices")
    st.caption(
        "Snowflake-native levers for monitoring, alerting on, and restricting Cortex Code spend. "
        "All SQL below is copy-paste ready — no objects are created by this app."
    )

    st.subheader("Current Budget Status")
    try:
        budgets_df = session.sql("SHOW SNOWFLAKE.CORE.BUDGET INSTANCES IN ACCOUNT").to_pandas()
        if budgets_df.empty:
            st.info("No custom budgets configured. See setup guidance below.")
        else:
            st.dataframe(budgets_df, use_container_width=True)
    except Exception as e:
        st.warning(f"Could not query budgets (ACCOUNTADMIN or BUDGET_VIEWER required): {e}")

    st.divider()

    with st.expander("Option A — Account Budget (monitors all account credits)"):
        st.markdown(
            "The **account budget** tracks total credit consumption across your entire Snowflake account. "
            "It sends email alerts when projected spend is on track to exceed the monthly limit. "
            "There is exactly one account budget per account; it cannot be scoped to specific objects."
        )
        st.code("""
-- Run as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- 1. Activate
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();

-- 2. Set monthly credit limit (alert-only; does not block usage)
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(1000);

-- 3. Add email recipients (addresses must be verified in Snowsight first)
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_EMAIL_NOTIFICATIONS(
    'finops@company.com, admin@company.com'
);

-- 4. Check projected spend
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_HISTORY(
    TIME_LOWER_BOUND => DATEADD('day', -30, CURRENT_TIMESTAMP),
    TIME_UPPER_BOUND => CURRENT_TIMESTAMP
);

-- To deactivate (clears history):
-- CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!DEACTIVATE();
        """, language="sql")
        st.info(
            "The account budget does NOT support ADD_RESOURCE or tag methods. "
            "Use a custom budget (Option B) to track specific objects."
        )

    with st.expander("Option B — Custom Budget scoped to Cortex Code"):
        st.markdown(
            "A **custom budget** monitors credits for a specific set of objects or tags you define. "
            "Up to 100 custom budgets per account. Tag-based attribution is recommended — it "
            "automatically includes new objects tagged later and backfills data to the 1st of the month."
        )
        st.code("""
-- Run as ACCOUNTADMIN once to set up the schema and privileges
USE ROLE ACCOUNTADMIN;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.BUDGETS
    COMMENT = 'Custom budget objects';
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE SYSADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO ROLE SYSADMIN;
GRANT CREATE SNOWFLAKE.CORE.BUDGET ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO ROLE SYSADMIN;

-- Run as SYSADMIN to create and configure the budget
USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS;

CREATE SNOWFLAKE.CORE.BUDGET cortex_code_budget()
    COMMENT = 'Monthly AI credit limit for Cortex Code usage';

-- Set monthly spending limit (credits; alert-only)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!SET_SPENDING_LIMIT(500);

-- Add email notifications
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!SET_EMAIL_NOTIFICATIONS(
    'finops@company.com'
);

-- (Optional) Low-latency refresh: check spend every ~1 hour instead of 6
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!SET_REFRESH_TIER('TIER_1H');

-- Verify
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!GET_SPENDING_LIMIT();
        """, language="sql")
        st.caption(
            "Spending limits are for alerting only. They do not block usage on their own. "
            "Add a custom action (see below) to automate a response at a threshold."
        )

    with st.expander("Automated Actions — respond at spend thresholds"):
        st.markdown(
            "**Custom actions** call a stored procedure when spending actually reaches or is projected "
            "to reach a percentage of the monthly limit. Two common patterns:"
        )
        st.markdown("**Pattern A — Email alert at 70% projected spend**")
        st.code("""
USE ROLE SYSADMIN;

CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_alert_70pct()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    CALL SYSTEM$SEND_EMAIL(
        'my_email_integration',           -- replace with your email integration name
        'finops@company.com',
        'Cortex Code spend at 70% of monthly budget',
        'Cortex Code AI credit spend is projected to exceed the monthly limit. Review usage in Snowsight.'
    );
    RETURN 'Alert sent';
END;
$$;

-- Grant APPLICATION SNOWFLAKE access to execute the procedure
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO APPLICATION SNOWFLAKE;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_alert_70pct() TO APPLICATION SNOWFLAKE;

-- Attach to budget
USE ROLE SYSADMIN;
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!ADD_CUSTOM_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_alert_70pct()', 'SESSION', 'USAGE'),
    ARRAY_CONSTRUCT(),
    'PROJECTED',   -- fires when forecast crosses threshold
    70             -- % of spending limit
);
        """, language="sql")
        st.markdown("**Pattern B — Suspend warehouse at 95% actual spend**")
        st.code("""
USE ROLE SYSADMIN;

CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_suspend_95pct()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SUSPEND;  -- replace with your warehouse name
    RETURN 'Warehouse suspended — Cortex Code spend reached 95% of monthly budget';
END;
$$;

USE ROLE ACCOUNTADMIN;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_suspend_95pct() TO APPLICATION SNOWFLAKE;

USE ROLE SYSADMIN;
CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!ADD_CUSTOM_ACTION(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_suspend_95pct()', 'SESSION', 'USAGE'),
    ARRAY_CONSTRUCT(),
    'ACTUAL',      -- fires when actual spend crosses threshold
    95
);

-- View all configured actions:
-- CALL SNOWFLAKE_EXAMPLE.BUDGETS.cortex_code_budget!GET_CUSTOM_ACTIONS();
        """, language="sql")

    with st.expander("Model Selection — cost vs capability guide"):
        st.markdown(
            "Steering your team toward the lowest-cost model that meets the quality bar is the "
            "highest-leverage cost control available. Use the **Models** tab to see your current "
            "per-model credit breakdown."
        )
        guide = pd.DataFrame([
            {"Model": "claude-4-sonnet",   "Cost Tier": "Low",    "Input (credits/1M)": 1.50,  "Best For": "Everyday coding, completions, chat"},
            {"Model": "openai-gpt-5.2",    "Cost Tier": "Low",    "Input (credits/1M)": 0.97,  "Best For": "Fast completions, low-token tasks"},
            {"Model": "openai-gpt-5.4",    "Cost Tier": "Medium", "Input (credits/1M)": 1.38,  "Best For": "GPT-native integrations"},
            {"Model": "claude-sonnet-4-5", "Cost Tier": "Medium", "Input (credits/1M)": 1.65,  "Best For": "Balanced quality / cost"},
            {"Model": "claude-sonnet-4-6", "Cost Tier": "Medium", "Input (credits/1M)": 1.65,  "Best For": "Balanced quality / cost"},
            {"Model": "claude-opus-4-5",   "Cost Tier": "High",   "Input (credits/1M)": 2.75,  "Best For": "Complex architecture, large refactors"},
            {"Model": "claude-opus-4-6",   "Cost Tier": "High",   "Input (credits/1M)": 2.75,  "Best For": "Complex architecture, large refactors"},
        ])
        st.dataframe(guide, use_container_width=True, hide_index=True)
        st.markdown(
            "**Tips:**\n"
            "- Default model in `config.toml` (`model = \"claude-4-sonnet\"`) keeps casual sessions on the lowest-cost tier.\n"
            "- Opus-class models cost 1.8× more than Sonnet — reserve for tasks that genuinely need it.\n"
            "- Cache read tokens (returned context) are billed at ~10% of input rates; long sessions with stable context benefit most from caching."
        )

    with st.expander("RBAC — control who can use Cortex Code"):
        st.markdown(
            "Cortex Code access is controlled via the `SNOWFLAKE.CORTEX_USER` database role. "
            "Revoking this role from a Snowflake role is the fastest way to block a user or group."
        )
        st.code("""
-- Grant Cortex Code access to a role
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <developer_role>;

-- Revoke access
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE <developer_role>;

-- Inspect current grants
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;

-- Network policy: restrict Cortex API calls to approved IP ranges
-- (useful for limiting contractor / offshore access)
CREATE NETWORK POLICY cortex_access_policy
    ALLOWED_IP_LIST = ('203.0.113.0/24', '198.51.100.0/24')  -- replace with your CIDRs
    COMMENT = 'Restrict Cortex Code API to approved networks';

-- Attach to a specific user
ALTER USER <username> SET NETWORK_POLICY = cortex_access_policy;
        """, language="sql")
        st.caption(
            "Network policies restrict all Snowflake API traffic for the user, not just Cortex Code. "
            "Test in a non-production environment before applying broadly."
        )
