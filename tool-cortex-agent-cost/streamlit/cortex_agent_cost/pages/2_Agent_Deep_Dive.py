import streamlit as st
import plotly.express as px
from utils.data import (
    get_agent_list, get_agent_daily_trend, get_agent_token_breakdown,
    get_agent_parent_child, get_credit_cost,
)
from utils.formatting import format_credits, format_usd, format_tokens, format_latency
from utils.charts import daily_credits_area, COLORS

st.set_page_config(page_title="Agent Deep Dive", layout="wide")
st.title("Agent Deep Dive")

agents_df = get_agent_list()
if agents_df.empty:
    st.info("No agents found. Use Cortex Agent or Snowflake Intelligence first.")
    st.stop()

agent_options = agents_df["AGENT_NAME"].tolist()
selected_agent = st.selectbox("Select Agent", agent_options)

credit_cost = get_credit_cost()
days = st.selectbox("Time Period", [7, 14, 30, 60, 90], index=2,
                     format_func=lambda d: f"Last {d} days", key="agent_days")

agent_row = agents_df[agents_df["AGENT_NAME"] == selected_agent].iloc[0]

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Credits", format_credits(agent_row["TOTAL_CREDITS"]))
col2.metric("Est. Cost", format_usd(agent_row["TOTAL_CREDITS"] * credit_cost))
col3.metric("Requests", f"{int(agent_row['TOTAL_REQUESTS']):,}")
col4.metric("Source", agent_row["SERVICE_SOURCE"])

st.markdown("---")

trend_col, breakdown_col = st.columns(2)

with trend_col:
    st.subheader("Credit Trend")
    trend_df = get_agent_daily_trend(selected_agent, days)
    if not trend_df.empty:
        fig = daily_credits_area(trend_df, x="USAGE_DATE", y="DAILY_CREDITS")
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No trend data for this agent in the selected period.")

with breakdown_col:
    st.subheader("Token Breakdown by Model")
    token_df = get_agent_token_breakdown(selected_agent, days)
    if not token_df.empty:
        fig = px.bar(
            token_df, x="MODEL_NAME",
            y=["INPUT_TOKENS", "CACHE_READ_TOKENS", "OUTPUT_TOKENS"],
            barmode="stack",
            labels={"value": "Tokens", "variable": "Type", "MODEL_NAME": "Model"},
            color_discrete_map={
                "INPUT_TOKENS": COLORS["primary"],
                "CACHE_READ_TOKENS": COLORS["success"],
                "OUTPUT_TOKENS": COLORS["warning"],
            },
        )
        fig.update_layout(height=350, margin=dict(l=0, r=0, t=30, b=0),
                          legend=dict(orientation="h", yanchor="bottom", y=1.02,
                                      xanchor="right", x=1))
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No granular token data for this agent.")

st.markdown("---")
st.subheader("Parent vs Child Requests")
st.caption("Parent requests are top-level agent calls; child requests are sub-calls within orchestration.")

pc_df = get_agent_parent_child(selected_agent, days)
if not pc_df.empty:
    pc_display = pc_df.copy()
    pc_display["TOTAL_CREDITS"] = pc_display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.4f}")
    pc_display["AVG_LATENCY_MS"] = pc_display["AVG_LATENCY_MS"].apply(
        lambda v: format_latency(v) if v else "N/A"
    )
    pc_display.columns = ["Type", "Requests", "Credits", "Avg Latency"]
    st.dataframe(pc_display, hide_index=True, use_container_width=True)
else:
    st.info("No parent/child data for this agent.")
