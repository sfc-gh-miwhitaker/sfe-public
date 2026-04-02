import streamlit as st
import plotly.express as px
from utils.data import get_session, get_daily_summary, get_model_summary, get_totals

st.set_page_config(page_title="Cortex REST API Cost", layout="wide")
st.title("Cortex REST API Cost")
st.caption(
    "Direct REST API usage from "
    "SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY "
    "| Pricing: Service Consumption Table Tables 6(b)/6(c)"
)

session = get_session()

lookback = st.selectbox("Lookback", [7, 30, 90], index=1, format_func=lambda d: f"{d} days")

totals = get_totals(session, lookback)

if totals is not None and totals["TOTAL_REQUESTS"] > 0:
    col1, col2, col3 = st.columns(3)
    col1.metric("Total Requests", f"{int(totals['TOTAL_REQUESTS']):,}")
    col2.metric("Total Tokens", f"{int(totals['TOTAL_TOKENS']):,}")
    col3.metric("Total Cost", f"${totals['TOTAL_COST_USD']:,.2f}")

    st.divider()

    daily = get_daily_summary(session, lookback)
    if len(daily) > 0:
        fig = px.bar(
            daily,
            x="USAGE_DATE",
            y="TOTAL_COST_USD",
            labels={"USAGE_DATE": "Date", "TOTAL_COST_USD": "Cost (USD)"},
            title="Daily API Cost",
        )
        fig.update_layout(xaxis_tickformat="%b %d", yaxis_tickprefix="$")
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    models = get_model_summary(session, lookback)
    if len(models) > 0:
        st.subheader("Cost by Model")
        display = models.rename(columns={
            "MODEL_NAME": "Model",
            "REQUEST_COUNT": "Requests",
            "TOTAL_INPUT_TOKENS": "Input Tokens",
            "TOTAL_OUTPUT_TOKENS": "Output Tokens",
            "TOTAL_TOKENS": "Total Tokens",
            "TOTAL_COST_USD": "Cost (USD)",
            "PCT_OF_TOTAL_COST": "% of Total",
        })
        st.dataframe(display, hide_index=True, use_container_width=True)
else:
    st.info(
        f"No REST API usage found in the last {lookback} days. "
        "Make some Cortex REST API calls and check back."
    )
