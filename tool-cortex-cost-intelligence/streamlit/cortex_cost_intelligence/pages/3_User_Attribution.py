import streamlit as st
from utils.data import get_user_attribution, get_credit_cost
from utils.formatting import format_credits, format_usd
from utils.charts import user_bar_chart

st.set_page_config(page_title="User Attribution", layout="wide")
st.title("User Attribution")

days = st.sidebar.slider("Lookback (days)", 7, 90, 30)
credit_cost = get_credit_cost()

users = get_user_attribution(days)
if len(users) == 0:
    st.info("No user attribution data found.")
    st.stop()

user_totals = (
    users.groupby("USER_NAME")["TOTAL_CREDITS"]
    .sum()
    .reset_index()
    .sort_values("TOTAL_CREDITS", ascending=False)
)
user_totals["EST_COST_USD"] = user_totals["TOTAL_CREDITS"] * credit_cost

col1, col2, col3 = st.columns(3)
col1.metric("Unique Users", len(user_totals))
col2.metric("Total Credits", format_credits(user_totals["TOTAL_CREDITS"].sum()))
col3.metric("Est. Cost", format_usd(user_totals["TOTAL_CREDITS"].sum() * credit_cost))

st.markdown("---")
st.subheader("Top Users by Credit Consumption")
st.plotly_chart(user_bar_chart(users), use_container_width=True)

st.markdown("---")
st.subheader("User Leaderboard")
st.dataframe(user_totals.head(25), use_container_width=True, hide_index=True)

st.markdown("---")
st.subheader("Detailed Breakdown")
selected_user = st.selectbox("Select User", user_totals["USER_NAME"].tolist())
if selected_user:
    detail = users[users["USER_NAME"] == selected_user]
    st.dataframe(detail, use_container_width=True, hide_index=True)
