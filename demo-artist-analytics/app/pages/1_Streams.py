"""
Artist Analytics — Streams Page
Daily streaming counts and trends by platform.
"""
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="Streams — Jade Hollow", layout="wide")

SCHEMA = "SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":headphones: Streaming Performance")

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
        SUM(fds.streams)                                              AS total_streams,
        SUM(fds.saves)                                                AS total_saves,
        SUM(fds.listeners)                                            AS total_listeners,
        ROUND(SUM(fds.streams * dp.royalty_rate), 2)                 AS est_royalties
    FROM {SCHEMA}.FACT_DAILY_STREAMS fds
    JOIN {SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
    WHERE fds.stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
if not kpi.empty:
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Streams", f"{int(kpi['TOTAL_STREAMS'].iloc[0]):,}")
    c2.metric("Saves", f"{int(kpi['TOTAL_SAVES'].iloc[0]):,}")
    c3.metric("Listeners", f"{int(kpi['TOTAL_LISTENERS'].iloc[0]):,}")
    c4.metric("Est. Royalties", f"${float(kpi['EST_ROYALTIES'].iloc[0]):,.2f}")

st.markdown("---")

# ── Daily streams by platform ───────────────────────────────────────────────────
st.subheader("Daily Streams by Platform")
by_platform = run_query(
    f"""
    SELECT
        fds.stream_date,
        dp.platform_name,
        fds.streams
    FROM {SCHEMA}.FACT_DAILY_STREAMS fds
    JOIN {SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
    WHERE fds.stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    ORDER BY fds.stream_date, dp.platform_name
    """
)
if not by_platform.empty:
    pivot = by_platform.pivot(
        index="STREAM_DATE", columns="PLATFORM_NAME", values="STREAMS"
    ).reset_index()
    st.line_chart(pivot, x="STREAM_DATE", height=280)

# ── Platform totals ─────────────────────────────────────────────────────────────
left, right = st.columns(2)
with left:
    st.subheader("Total Streams by Platform")
    totals = run_query(
        f"""
        SELECT dp.platform_name, SUM(fds.streams) AS total_streams
        FROM {SCHEMA}.FACT_DAILY_STREAMS fds
        JOIN {SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
        WHERE fds.stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        GROUP BY dp.platform_name
        ORDER BY total_streams DESC
        """
    )
    if not totals.empty:
        st.bar_chart(totals, x="PLATFORM_NAME", y="TOTAL_STREAMS", height=260)

with right:
    st.subheader("Streams vs Listeners (7-day avg)")
    ratio = run_query(
        f"""
        SELECT
            dp.platform_name,
            AVG(fds.streams)   AS avg_streams,
            AVG(fds.listeners) AS avg_listeners
        FROM {SCHEMA}.FACT_DAILY_STREAMS fds
        JOIN {SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
        WHERE fds.stream_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        GROUP BY dp.platform_name
        ORDER BY avg_streams DESC
        """
    )
    if not ratio.empty:
        st.dataframe(
            ratio.rename(columns={
                "PLATFORM_NAME": "Platform",
                "AVG_STREAMS": "Avg Daily Streams",
                "AVG_LISTENERS": "Avg Daily Listeners",
            }),
            use_container_width=True,
            hide_index=True,
        )

st.markdown("---")
st.caption(
    "Demo — expires 2026-08-23. Pair-programmed by SE Community + Cortex Code."
)
