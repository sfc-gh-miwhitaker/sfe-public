import streamlit as st

st.set_page_config(
    page_title="Cortex Agent Cost",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.sidebar.title("Cortex Agent Cost")
st.sidebar.markdown("---")
st.sidebar.caption(
    "⏱️ ACCOUNT_USAGE views lag up to 45 minutes. "
    "Recent activity may not appear immediately."
)

st.title("Cortex Agent Cost")
st.markdown(
    "Granular cost reporting and forecasting for **Cortex Agent** and "
    "**Snowflake Intelligence** usage. Breaks down `TOKENS_GRANULAR` and "
    "`CREDITS_GRANULAR` arrays to show per-model, per-service-type costs "
    "within agent orchestration calls."
)

st.markdown("---")

col1, col2, col3 = st.columns(3)
with col1:
    st.info("**Overview** — KPIs, daily credit trend, top agents by cost")
    st.info("**Agent Deep Dive** — Per-agent credit and token analysis")
with col2:
    st.info("**Model Breakdown** — Per-model cost, cache efficiency, service types")
    st.info("**User Attribution** — Per-user spend leaderboard and drill-down")
with col3:
    st.info("**Forecasting** — Historical trends and scenario-based cost projections")

st.markdown("---")
st.caption("Use the sidebar to navigate between pages.")
