"""
Artist Analytics — Income Page
Daily income breakdown: streaming royalties, merch, sync licensing.
"""
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="Income — Jade Hollow", layout="wide")

SCHEMA = "SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":money_with_wings: Income")

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
        ROUND(SUM(stream_royalties), 2) AS royalties,
        ROUND(SUM(merch_estimate), 2)   AS merch,
        ROUND(SUM(sync_licensing), 2)   AS sync,
        ROUND(SUM(total_income), 2)     AS total
    FROM {SCHEMA}.FACT_INCOME
    WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    """
)
if not kpi.empty:
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Streaming Royalties", f"${float(kpi['ROYALTIES'].iloc[0]):,.2f}")
    c2.metric("Merch", f"${float(kpi['MERCH'].iloc[0]):,.2f}")
    c3.metric("Sync Licensing", f"${float(kpi['SYNC'].iloc[0]):,.2f}")
    c4.metric("Total Income", f"${float(kpi['TOTAL'].iloc[0]):,.2f}")

st.markdown("---")

# ── Daily income trend (stacked) ────────────────────────────────────────────────
st.subheader("Daily Income Breakdown")
daily = run_query(
    f"""
    SELECT
        income_date,
        stream_royalties,
        merch_estimate,
        sync_licensing
    FROM {SCHEMA}.FACT_INCOME
    WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
    ORDER BY income_date
    """
)
if not daily.empty:
    st.area_chart(
        daily.rename(columns={
            "INCOME_DATE": "Date",
            "STREAM_ROYALTIES": "Royalties",
            "MERCH_ESTIMATE": "Merch",
            "SYNC_LICENSING": "Sync",
        }).set_index("Date"),
        height=280,
    )

# ── 30-day rolling income + income mix ─────────────────────────────────────────
left, right = st.columns(2)
with left:
    st.subheader("30-Day Rolling Total Income")
    rolling = run_query(
        f"""
        SELECT income_date, rolling_30d_income
        FROM {SCHEMA}.V_INCOME_KPI
        WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        ORDER BY income_date
        """
    )
    if not rolling.empty:
        st.line_chart(
            rolling,
            x="INCOME_DATE",
            y="ROLLING_30D_INCOME",
            height=260,
        )

with right:
    st.subheader("Income Mix")
    mix = run_query(
        f"""
        SELECT
            'Streaming Royalties' AS source, ROUND(SUM(stream_royalties), 2) AS amount
        FROM {SCHEMA}.FACT_INCOME
        WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        UNION ALL
        SELECT 'Merch', ROUND(SUM(merch_estimate), 2)
        FROM {SCHEMA}.FACT_INCOME
        WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        UNION ALL
        SELECT 'Sync Licensing', ROUND(SUM(sync_licensing), 2)
        FROM {SCHEMA}.FACT_INCOME
        WHERE income_date >= DATEADD('day', -{int(window)}, CURRENT_DATE())
        ORDER BY amount DESC
        """
    )
    if not mix.empty:
        st.dataframe(
            mix.rename(columns={"SOURCE": "Income Source", "AMOUNT": "Total ($)"}),
            use_container_width=True,
            hide_index=True,
        )

st.markdown("---")
st.caption(
    "Demo — expires 2026-08-23. Pair-programmed by SE Community + Cortex Code."
)
