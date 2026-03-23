import streamlit as st
from utils.data import get_overview_kpis, get_daily_credits, get_top_agents, get_credit_cost
from utils.formatting import format_credits, format_usd, format_tokens, format_latency
from utils.charts import daily_credits_area, SERVICE_COLORS

st.title("Overview")

credit_cost = get_credit_cost()

days = st.selectbox("Time Period", [7, 14, 30, 60, 90], index=2, format_func=lambda d: f"Last {d} days")

kpis = get_overview_kpis(days)
if kpis.empty:
    st.info("No agent usage data found. Ensure Cortex Agent or Snowflake Intelligence has been used in this account.")
    st.stop()

row = kpis.iloc[0]
col1, col2, col3, col4, col5, col6 = st.columns(6)
col1.metric("Total Credits", format_credits(row["TOTAL_CREDITS"]))
col2.metric("Est. Cost", format_usd(row["TOTAL_CREDITS"] * credit_cost))
col3.metric("Requests", f"{int(row['TOTAL_REQUESTS']):,}")
col4.metric("Agents", int(row["UNIQUE_AGENTS"]))
col5.metric("Users", int(row["UNIQUE_USERS"]))
col6.metric("Avg Latency", format_latency(row["AVG_LATENCY_MS"]))

st.markdown("---")
st.subheader("Daily Credits by Source")

daily_df = get_daily_credits(days)
if not daily_df.empty:
    fig = daily_credits_area(
        daily_df, x="USAGE_DATE", y="DAILY_CREDITS",
        color="SERVICE_SOURCE", color_map=SERVICE_COLORS
    )
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("No daily credit data available yet.")

st.markdown("---")
st.subheader("Top Agents by Cost")

top_agents = get_top_agents(days)
if not top_agents.empty:
    display = top_agents.copy()
    display["TOTAL_CREDITS"] = display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.2f}")
    display["TOTAL_TOKENS"] = display["TOTAL_TOKENS"].apply(lambda v: f"{v:,.0f}")
    display["AVG_LATENCY_MS"] = display["AVG_LATENCY_MS"].apply(
        lambda v: format_latency(v) if v else "N/A"
    )
    display.columns = [
        "Agent", "Source", "Requests", "Users",
        "Credits", "Tokens", "Avg Latency"
    ]
    st.dataframe(display, hide_index=True, use_container_width=True)
else:
    st.info("No agent data available.")
