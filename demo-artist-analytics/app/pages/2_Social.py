"""
Artist Analytics — Social Media Page
Daily impressions, engagement rates, and social platform breakdown.
"""
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="Social — Jade Hollow", layout="wide")

SCHEMA = "SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":bar_chart: Social Media Performance")

window = st.sidebar.selectbox(
    "Time window",
    [7, 30, 60, 90],
    index=1,
    format_func=lambda d: f"Last {d} days",
)

# ── KPIs ────────────────────────────────────────────────────────────────────────
kpi = run_query(
    f"""
    SELECT
        SUM(impressions)  AS total_impressions,
        SUM(engagements)  AS total_engagements,
        SUM(shares)       AS total_shares,
        ROUND(SUM(engagements) / NULLIF(SUM(impressions), 0) * 100, 2) AS engagement_rate_pct
    FROM {SCHEMA}.FACT_SOCIAL_METRICS
    WHERE metric_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
if not kpi.empty:
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Impressions", f"{int(kpi['TOTAL_IMPRESSIONS'].iloc[0]):,}")
    c2.metric("Engagements", f"{int(kpi['TOTAL_ENGAGEMENTS'].iloc[0]):,}")
    c3.metric("Shares", f"{int(kpi['TOTAL_SHARES'].iloc[0]):,}")
    c4.metric("Engagement Rate", f"{float(kpi['ENGAGEMENT_RATE_PCT'].iloc[0]):.1f}%")

st.markdown("---")

# ── Daily impressions trend ─────────────────────────────────────────────────────
st.subheader("Daily Impressions by Platform")
by_platform = run_query(
    f"""
    SELECT
        fsm.metric_date,
        dsp.platform_name,
        SUM(fsm.impressions) AS impressions
    FROM {SCHEMA}.FACT_SOCIAL_METRICS fsm
    JOIN {SCHEMA}.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
    WHERE fsm.metric_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    GROUP BY fsm.metric_date, dsp.platform_name
    ORDER BY fsm.metric_date, dsp.platform_name
    """
)
if not by_platform.empty:
    pivot = by_platform.pivot(
        index="METRIC_DATE", columns="PLATFORM_NAME", values="IMPRESSIONS"
    ).reset_index()
    st.line_chart(pivot, x="METRIC_DATE", height=260)

# ── Platform comparison ─────────────────────────────────────────────────────────
left, right = st.columns(2)
with left:
    st.subheader("Engagement Rate by Platform")
    er_data = run_query(
        f"""
        SELECT
            dsp.platform_name,
            ROUND(SUM(fsm.engagements) / NULLIF(SUM(fsm.impressions), 0) * 100, 2) AS engagement_rate_pct
        FROM {SCHEMA}.FACT_SOCIAL_METRICS fsm
        JOIN {SCHEMA}.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
        WHERE fsm.metric_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        GROUP BY dsp.platform_name
        ORDER BY engagement_rate_pct DESC
        """
    )
    if not er_data.empty:
        st.bar_chart(er_data, x="PLATFORM_NAME", y="ENGAGEMENT_RATE_PCT", height=260)

with right:
    st.subheader("Impressions by Platform")
    imp_data = run_query(
        f"""
        SELECT
            dsp.platform_name,
            SUM(fsm.impressions)  AS total_impressions,
            SUM(fsm.engagements)  AS total_engagements,
            SUM(fsm.shares)       AS total_shares
        FROM {SCHEMA}.FACT_SOCIAL_METRICS fsm
        JOIN {SCHEMA}.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
        WHERE fsm.metric_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        GROUP BY dsp.platform_name
        ORDER BY total_impressions DESC
        """
    )
    if not imp_data.empty:
        st.dataframe(
            imp_data.rename(columns={
                "PLATFORM_NAME": "Platform",
                "TOTAL_IMPRESSIONS": "Impressions",
                "TOTAL_ENGAGEMENTS": "Engagements",
                "TOTAL_SHARES": "Shares",
            }),
            use_container_width=True,
            hide_index=True,
        )

st.markdown("---")
st.caption(
    "Demo — expires 2026-08-23. Pair-programmed by SE Community + Cortex Code."
)
