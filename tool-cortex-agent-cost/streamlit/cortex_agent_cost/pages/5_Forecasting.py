import streamlit as st
import plotly.express as px
from utils.data import get_forecast_data, get_credit_cost
from utils.formatting import format_credits, format_usd
from utils.charts import daily_credits_area, COLORS

st.title("Forecasting")

credit_cost = get_credit_cost()

st.markdown(
    "Project future Cortex Agent costs based on historical daily credit totals. "
    "For ML-based forecasting, use Snowflake's `FORECAST` function on the "
    "`V_FORECAST_BASE` view."
)

forecast_df = get_forecast_data()
if forecast_df.empty:
    st.info("No forecast data available. Ensure agent usage exists in the account.")
    st.stop()

total = forecast_df["DAILY_CREDITS"].sum()
avg_daily = forecast_df["DAILY_CREDITS"].mean()
days_of_data = len(forecast_df)
avg_requests = forecast_df["DAILY_REQUESTS"].mean()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Days of Data", days_of_data)
col2.metric("Avg Daily Credits", format_credits(avg_daily))
col3.metric("Avg Daily Requests", f"{avg_requests:,.0f}")
col4.metric("Projected Monthly Cost", format_usd(avg_daily * 30 * credit_cost))

st.markdown("---")
st.subheader("Historical Daily Credits")

fig = daily_credits_area(forecast_df, x="USAGE_DATE", y="DAILY_CREDITS")
st.plotly_chart(fig, use_container_width=True)

st.markdown("---")
st.subheader("Scenario Planner")
st.markdown("Estimate future costs based on growth assumptions.")

growth = st.slider("Monthly Growth Rate (%)", -20, 100, 10) / 100
months = st.slider("Projection Months", 1, 12, 6)

current_monthly = avg_daily * 30
projections = []
for m in range(months):
    projected_credits = current_monthly * ((1 + growth) ** (m + 1))
    projections.append({
        "Month": m + 1,
        "Projected Credits": round(projected_credits, 2),
        "Projected Cost (USD)": round(projected_credits * credit_cost, 2),
    })

st.dataframe(projections, use_container_width=True, hide_index=True)

total_projected_cost = sum(p["Projected Cost (USD)"] for p in projections)
st.metric(f"Total {months}-Month Projected Cost", format_usd(total_projected_cost))

st.markdown("---")
st.subheader("Usage Trend")
st.caption("Daily requests and unique users alongside credit spend.")

col_req, col_usr = st.columns(2)
with col_req:
    fig_req = px.area(forecast_df, x="USAGE_DATE", y="DAILY_REQUESTS",
                      labels={"USAGE_DATE": "Date", "DAILY_REQUESTS": "Requests"})
    fig_req.update_traces(line_color=COLORS["warning"],
                          fillcolor="rgba(243,156,18,0.2)")
    fig_req.update_layout(height=250, margin=dict(l=0, r=0, t=30, b=0))
    st.plotly_chart(fig_req, use_container_width=True)

with col_usr:
    fig_usr = px.area(forecast_df, x="USAGE_DATE", y="DAILY_USERS",
                      labels={"USAGE_DATE": "Date", "DAILY_USERS": "Users"})
    fig_usr.update_traces(line_color=COLORS["success"],
                          fillcolor="rgba(46,204,113,0.2)")
    fig_usr.update_layout(height=250, margin=dict(l=0, r=0, t=30, b=0))
    st.plotly_chart(fig_usr, use_container_width=True)
