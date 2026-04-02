import streamlit as st
import plotly.express as px
from utils.data import get_forecast_data, get_credit_cost
from utils.formatting import format_credits, format_usd

st.set_page_config(page_title="Forecasting", layout="wide")
st.title("Forecasting")

credit_cost = get_credit_cost()

st.markdown(
    "Forecasting uses historical daily credit totals to project future spend. "
    "For ML-based forecasting, use Snowflake's `FORECAST` function on the "
    "`V_CORTEX_COST_FORECAST` view."
)

forecast = get_forecast_data()
if len(forecast) == 0:
    st.info("No forecast data available. Ensure monitoring views are deployed.")
    st.stop()

total = forecast["DAILY_CREDITS"].sum()
avg_daily = forecast["DAILY_CREDITS"].mean()
days_of_data = len(forecast)

col1, col2, col3, col4 = st.columns(4)
col1.metric("Days of Data", days_of_data)
col2.metric("Total Credits", format_credits(total))
col3.metric("Avg Daily Credits", format_credits(avg_daily))
col4.metric("Projected Monthly", format_usd(avg_daily * 30 * credit_cost))

st.markdown("---")
st.subheader("Historical Daily Credits")
fig = px.area(
    forecast,
    x="USAGE_DATE",
    y="DAILY_CREDITS",
    labels={"USAGE_DATE": "Date", "DAILY_CREDITS": "Credits"},
)
fig.update_layout(height=400, margin=dict(l=0, r=0, t=30, b=0))
st.plotly_chart(fig, use_container_width=True)

st.markdown("---")
st.subheader("Scenario Planner")
st.markdown("Estimate future costs based on growth assumptions.")

growth = st.slider("Monthly Growth Rate (%)", -20, 100, 10) / 100
months = st.slider("Projection Months", 1, 12, 6)

current_monthly = avg_daily * 30
projections = []
for m in range(months):
    projected = current_monthly * ((1 + growth) ** (m + 1))
    projections.append({
        "Month": m + 1,
        "Projected Credits": round(projected, 2),
        "Projected Cost (USD)": round(projected * credit_cost, 2),
    })

st.dataframe(projections, use_container_width=True, hide_index=True)

total_projected_cost = sum(p["Projected Cost (USD)"] for p in projections)
st.metric(f"Total {months}-Month Projected Cost", format_usd(total_projected_cost))
