import streamlit as st
from utils.data import get_user_spend, get_user_agent_detail, get_credit_cost
from utils.formatting import format_credits, format_usd
from utils.charts import horizontal_bar, COLORS

st.set_page_config(page_title="User Attribution", layout="wide")
st.title("User Attribution")
st.caption("Per-user spend leaderboard with drill-down to agent-level detail.")

credit_cost = get_credit_cost()
days = st.selectbox("Time Period", [7, 14, 30, 60, 90], index=2,
                     format_func=lambda d: f"Last {d} days", key="user_days")

users_df = get_user_spend(days)
if users_df.empty:
    st.info("No user spend data found for the selected period.")
    st.stop()

col1, col2, col3 = st.columns(3)
col1.metric("Total Users", len(users_df))
col2.metric("Total Credits", format_credits(users_df["TOTAL_CREDITS"].sum()))
col3.metric("Est. Cost", format_usd(users_df["TOTAL_CREDITS"].sum() * credit_cost))

st.markdown("---")
st.subheader("Top Users by Credit Spend")

top_n = min(15, len(users_df))
chart_df = users_df.head(top_n).copy()
fig = horizontal_bar(chart_df, x="TOTAL_CREDITS", y="USER_NAME")
st.plotly_chart(fig, use_container_width=True)

st.markdown("---")
st.subheader("User Spend Table")

display = users_df.copy()
display["TOTAL_CREDITS"] = display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.2f}")
display["TOTAL_TOKENS"] = display["TOTAL_TOKENS"].apply(lambda v: f"{v:,.0f}")
display["FIRST_USE"] = display["FIRST_USE"].apply(lambda v: str(v)[:10] if v else "-")
display["LAST_USE"] = display["LAST_USE"].apply(lambda v: str(v)[:10] if v else "-")
display.columns = ["User", "Agents Used", "Requests", "Credits", "Tokens",
                    "First Use", "Last Use"]
st.dataframe(display, hide_index=True, use_container_width=True)

st.markdown("---")
st.subheader("User Drill-Down")

selected_user = st.selectbox("Select User", users_df["USER_NAME"].tolist())
if selected_user:
    detail_df = get_user_agent_detail(selected_user, days)
    if not detail_df.empty:
        detail_display = detail_df.copy()
        detail_display["TOTAL_CREDITS"] = detail_display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.4f}")
        detail_display["TOTAL_TOKENS"] = detail_display["TOTAL_TOKENS"].apply(lambda v: f"{v:,.0f}")
        detail_display["FIRST_USE"] = detail_display["FIRST_USE"].apply(lambda v: str(v)[:10] if v else "-")
        detail_display["LAST_USE"] = detail_display["LAST_USE"].apply(lambda v: str(v)[:10] if v else "-")
        detail_display.columns = ["Agent", "Source", "Requests", "Active Days",
                                   "Credits", "Tokens", "First Use", "Last Use"]
        st.dataframe(detail_display, hide_index=True, use_container_width=True)
    else:
        st.info("No agent detail for this user.")
