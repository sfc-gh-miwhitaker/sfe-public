import streamlit as st
from utils.data import get_daily_summary, get_kpis, get_anomalies, get_credit_cost
from utils.formatting import format_credits, format_usd, format_number
from utils.charts import daily_credits_chart, sparkline

st.set_page_config(page_title="Executive Summary", layout="wide")
st.title("Executive Summary")

days = st.sidebar.slider("Lookback (days)", 7, 90, 30)
credit_cost = get_credit_cost()

kpis = get_kpis(days)
if len(kpis) > 0:
    total_credits = kpis.iloc[0]["TOTAL_CREDITS"] or 0
    total_ops = kpis.iloc[0]["TOTAL_OPERATIONS"] or 0
    active_svc = kpis.iloc[0]["ACTIVE_SERVICES"] or 0
else:
    total_credits = total_ops = active_svc = 0

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Credits", format_credits(total_credits))
col2.metric("Est. Cost (USD)", format_usd(total_credits * credit_cost))
col3.metric("Total Operations", format_number(total_ops))
col4.metric("Active Services", format_number(active_svc))

st.markdown("---")

daily = get_daily_summary(days)
if len(daily) > 0:
    st.subheader("Daily Credit Consumption by Service")
    st.plotly_chart(daily_credits_chart(daily), use_container_width=True)

    st.subheader("Daily Sparklines by Service")
    services = daily["SERVICE_TYPE"].unique()
    cols = st.columns(min(len(services), 4))
    for i, svc in enumerate(services[:8]):
        svc_data = daily[daily["SERVICE_TYPE"] == svc].sort_values("USAGE_DATE")
        with cols[i % len(cols)]:
            st.caption(svc)
            if len(svc_data) > 1:
                st.plotly_chart(sparkline(svc_data["TOTAL_CREDITS"].tolist()), use_container_width=True)
            st.metric("Credits", format_credits(svc_data["TOTAL_CREDITS"].sum()))
else:
    st.info("No usage data found for the selected period.")

st.markdown("---")
st.subheader("Active Anomalies")
anomalies = get_anomalies()
if len(anomalies) > 0:
    st.dataframe(anomalies, use_container_width=True)
else:
    st.success("No active cost anomalies detected.")
