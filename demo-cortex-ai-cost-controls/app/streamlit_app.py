"""
Cortex AI Cost Controls — Overview / Spend
Streamlit-in-Snowflake dashboard. Reads LIVE SNOWFLAKE.ACCOUNT_USAGE views via
the curated APP views in SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.

Companion to the guide-cortex-ai-cost-controls narrative.
Expires: 2026-07-24
"""
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Cortex AI Cost Controls", page_icon=":bar_chart:", layout="wide")

SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":bar_chart: Cortex AI — Cost Monitoring & Controls")
st.caption(
    "Live view of Cortex AI spend from SNOWFLAKE.ACCOUNT_USAGE. "
    "These views carry ~45-60 minute latency — you are looking at the recent past, not this instant."
)

# ── Sidebar: time window ─────────────────────────────────────────────────────
window = st.sidebar.selectbox("Time window", [7, 30, 90], index=1, format_func=lambda d: f"Last {d} days")
st.sidebar.markdown("---")
st.sidebar.markdown(
    "**Pages**\n\n"
    "- Overview (this page)\n"
    "- Attribution — spend by cost center\n"
    "- Limits — per-user caps (interactive)\n"
    "- Runaway — in-flight query protection\n"
    "- Anomaly — spikes & budget"
)

# ── Headline metrics ─────────────────────────────────────────────────────────
summary = run_query(
    f"""
    SELECT service, SUM(credits) AS total_credits, COUNT(*) AS event_rows,
           COUNT(DISTINCT user_name) AS distinct_users
    FROM {SCHEMA}.V_AI_USAGE_UNIFIED
    WHERE usage_day >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    GROUP BY service
    ORDER BY total_credits DESC
    """
)

total_credits = float(summary["TOTAL_CREDITS"].fillna(0).sum()) if not summary.empty else 0.0
active_services = int((summary["TOTAL_CREDITS"].fillna(0) > 0).sum()) if not summary.empty else 0
top_service = summary.iloc[0]["SERVICE"] if not summary.empty and total_credits > 0 else "—"

c1, c2, c3 = st.columns(3)
c1.metric(f"Total AI credits ({window}d)", f"{total_credits:,.2f}")
c2.metric("Active services", active_services)
c3.metric("Top service", top_service)

if total_credits == 0:
    st.info(
        "No Cortex AI spend in this window yet. Run **sql/99_optional/01_seed_real_usage.sql** "
        "to generate a little real activity (appears after ~1 hour of ACCOUNT_USAGE latency)."
    )

st.markdown("---")

# ── Daily AI_SERVICES trend (billed rollup) ──────────────────────────────────
st.subheader("Daily AI_SERVICES spend (billed)")
daily = run_query(
    f"""
    SELECT usage_day, credits_used
    FROM {SCHEMA}.V_AI_SPEND_DAILY
    WHERE usage_day >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    ORDER BY usage_day
    """
)
if daily.empty:
    st.caption("No METERING_DAILY_HISTORY rows for AI_SERVICES in this window.")
else:
    st.line_chart(daily, x="USAGE_DAY", y="CREDITS_USED", height=260)

# ── Spend by service + top users ─────────────────────────────────────────────
left, right = st.columns(2)
with left:
    st.subheader("Credits by service")
    if summary.empty or total_credits == 0:
        st.caption("Nothing to chart yet.")
    else:
        st.bar_chart(summary, x="SERVICE", y="TOTAL_CREDITS", height=300)

with right:
    st.subheader("Top users")
    users = run_query(
        f"""
        SELECT COALESCE(user_name, '(unattributed)') AS user_name,
               SUM(credits) AS total_credits, COUNT(*) AS event_rows
        FROM {SCHEMA}.V_AI_USAGE_UNIFIED
        WHERE usage_day >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        GROUP BY 1
        ORDER BY total_credits DESC
        LIMIT 15
        """
    )
    if users.empty:
        st.caption("No per-user attribution yet.")
    else:
        st.dataframe(users, use_container_width=True, hide_index=True)

st.markdown("---")
st.caption(
    "Demo — expires 2026-07-24. Pair-programmed by SE Community + Cortex Code. "
    "No support provided; validate before production use."
)
