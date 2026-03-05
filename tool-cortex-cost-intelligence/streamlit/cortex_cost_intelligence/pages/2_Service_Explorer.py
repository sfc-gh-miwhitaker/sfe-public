import streamlit as st
from utils.data import get_daily_summary, get_model_efficiency, get_credit_cost
from utils.formatting import format_credits, format_usd
from utils.charts import daily_credits_chart, service_pie_chart

st.set_page_config(page_title="Service Explorer", layout="wide")
st.title("Service Explorer")

days = st.sidebar.slider("Lookback (days)", 7, 90, 30)
credit_cost = get_credit_cost()

daily = get_daily_summary(days)
if len(daily) == 0:
    st.info("No usage data found.")
    st.stop()

services = sorted(daily["SERVICE_TYPE"].unique())
selected = st.sidebar.multiselect("Filter Services", services, default=services)
filtered = daily[daily["SERVICE_TYPE"].isin(selected)]

col1, col2 = st.columns([2, 1])
with col1:
    st.subheader("Daily Credits by Service")
    st.plotly_chart(daily_credits_chart(filtered), use_container_width=True)

with col2:
    st.subheader("Credit Distribution")
    svc_totals = filtered.groupby("SERVICE_TYPE")["TOTAL_CREDITS"].sum().reset_index()
    st.plotly_chart(service_pie_chart(svc_totals), use_container_width=True)

st.markdown("---")
st.subheader("Service Summary Table")
summary = (
    filtered.groupby("SERVICE_TYPE")
    .agg({"TOTAL_CREDITS": "sum", "TOTAL_OPERATIONS": "sum", "DAILY_UNIQUE_USERS": "max"})
    .reset_index()
    .sort_values("TOTAL_CREDITS", ascending=False)
)
summary["EST_COST_USD"] = summary["TOTAL_CREDITS"] * credit_cost
st.dataframe(summary, use_container_width=True, hide_index=True)

st.markdown("---")
st.subheader("Model Efficiency Comparison")
efficiency = get_model_efficiency()
if len(efficiency) > 0:
    st.dataframe(efficiency, use_container_width=True, hide_index=True)
else:
    st.info("No model efficiency data available.")
