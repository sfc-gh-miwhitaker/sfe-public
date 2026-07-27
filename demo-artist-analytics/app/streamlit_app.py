"""
Artist Analytics — Landing Page / Dashboard Home
Streamlit-in-Snowflake basic tier for Jade Hollow's music analytics.
Expires: 2026-08-23
"""
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(
    page_title="Jade Hollow — Analytics",
    page_icon=":musical_note:",
    layout="wide",
)

SCHEMA = "SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


# ── Header ─────────────────────────────────────────────────────────────────────
st.title(":musical_note: Jade Hollow — Artist Analytics")
st.caption(
    "Basic tier dashboard: streams, social, income, and upcoming show momentum."
)

# ── Sidebar ────────────────────────────────────────────────────────────────────
window = st.sidebar.selectbox(
    "Time window",
    [7, 30, 60, 90],
    index=1,
    format_func=lambda d: f"Last {d} days",
)
st.sidebar.markdown("---")
st.sidebar.markdown(
    "**Pages**\n\n"
    "- Home (this page)\n"
    "- Streams\n"
    "- Social\n"
    "- Income\n\n"
    "---\n"
    "**Pro tier:** Add `ARTIST_ANALYTICS_AGENT` to Snowflake Intelligence "
    "(CoWork) to ask questions in plain English."
)

# ── KPI tiles ──────────────────────────────────────────────────────────────────
col1, col2, col3, col4 = st.columns(4)

streams_kpi = run_query(
    f"""
    SELECT SUM(streams) AS total_streams
    FROM {SCHEMA}.FACT_DAILY_STREAMS
    WHERE stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
total_streams = int(streams_kpi["TOTAL_STREAMS"].iloc[0]) if not streams_kpi.empty else 0

social_kpi = run_query(
    f"""
    SELECT SUM(impressions) AS total_impressions
    FROM {SCHEMA}.FACT_SOCIAL_METRICS
    WHERE metric_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
total_impressions = int(social_kpi["TOTAL_IMPRESSIONS"].iloc[0]) if not social_kpi.empty else 0

income_kpi = run_query(
    f"""
    SELECT ROUND(SUM(total_income), 2) AS total_income
    FROM {SCHEMA}.FACT_INCOME
    WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
total_income = float(income_kpi["TOTAL_INCOME"].iloc[0]) if not income_kpi.empty else 0.0

momentum_kpi = run_query(
    f"""
    SELECT AVG(momentum_score) AS avg_momentum
    FROM {SCHEMA}.V_SHOW_MOMENTUM
    WHERE momentum_score IS NOT NULL
    """
)
avg_momentum = (
    round(float(momentum_kpi["AVG_MOMENTUM"].iloc[0]), 1)
    if not momentum_kpi.empty and momentum_kpi["AVG_MOMENTUM"].iloc[0] is not None
    else None
)

col1.metric(f"Streams ({window}d)", f"{total_streams:,}")
col2.metric(f"Impressions ({window}d)", f"{total_impressions:,}")
col3.metric(f"Income ({window}d)", f"${total_income:,.2f}")
col4.metric(
    "Avg Momentum Score",
    f"{avg_momentum}" if avg_momentum is not None else "Pre-window",
    help="100 = flat vs baseline. >100 = fan engagement building. <100 = needs a push.",
)

st.markdown("---")

# ── Stream trend preview ───────────────────────────────────────────────────────
st.subheader("Daily Streams (all platforms)")
stream_trend = run_query(
    f"""
    SELECT stream_date, SUM(streams) AS streams
    FROM {SCHEMA}.FACT_DAILY_STREAMS
    WHERE stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    GROUP BY stream_date
    ORDER BY stream_date
    """
)
if not stream_trend.empty:
    st.line_chart(stream_trend, x="STREAM_DATE", y="STREAMS", height=200)

# ── Upcoming shows ─────────────────────────────────────────────────────────────
st.subheader("Upcoming Shows")
shows = run_query(
    f"""
    SELECT
        show_name,
        venue_city,
        show_date,
        days_until_show,
        COALESCE(momentum_score::VARCHAR, 'Pre-window') AS momentum_score,
        momentum_label
    FROM {SCHEMA}.V_SHOW_MOMENTUM
    ORDER BY show_date
    """
)
if not shows.empty:
    st.dataframe(
        shows.rename(columns={
            "SHOW_NAME": "Show", "VENUE_CITY": "City", "SHOW_DATE": "Date",
            "DAYS_UNTIL_SHOW": "Days Out", "MOMENTUM_SCORE": "Momentum",
            "MOMENTUM_LABEL": "Status",
        }),
        use_container_width=True,
    )
else:
    st.caption("No upcoming shows found.")

st.markdown("---")
st.caption(
    "Basic tier demo — expires 2026-08-23. "
    "Pair-programmed by SE Community + Cortex Code. "
    "No support provided; validate before production use."
)
