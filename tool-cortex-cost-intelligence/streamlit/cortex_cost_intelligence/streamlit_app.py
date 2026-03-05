import streamlit as st

st.set_page_config(
    page_title="Cortex Cost Intelligence",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.sidebar.title("Cortex Cost Intelligence")
st.sidebar.markdown("---")

PAGES = {
    "Executive Summary": "pages/1_Executive_Summary.py",
    "Service Explorer": "pages/2_Service_Explorer.py",
    "User Attribution": "pages/3_User_Attribution.py",
    "Cost Controls": "pages/4_Cost_Controls.py",
    "Forecasting": "pages/5_Forecasting.py",
    "AI Advisor": "pages/6_AI_Advisor.py",
}

st.title("Cortex Cost Intelligence")
st.markdown(
    "Natural-language cost governance for every Snowflake Cortex AI service. "
    "Use the sidebar to navigate between pages."
)

col1, col2, col3 = st.columns(3)
with col1:
    st.info("**Executive Summary** — KPIs, sparklines, and active alerts")
    st.info("**Service Explorer** — Deep-dive cost analysis by service")
with col2:
    st.info("**User Attribution** — Per-user spend leaderboard")
    st.info("**Cost Controls** — Budget status and governance tools")
with col3:
    st.info("**Forecasting** — ML-based spend projections")
    st.info("**AI Advisor** — Natural language cost Q&A via Cortex Agent")
