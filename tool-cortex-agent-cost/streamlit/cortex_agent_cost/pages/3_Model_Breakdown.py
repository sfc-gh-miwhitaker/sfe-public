import streamlit as st
from utils.data import (
    get_model_cost_summary, get_model_daily_credits,
    get_service_type_breakdown, get_cache_efficiency, get_credit_cost,
)
from utils.formatting import format_credits, format_usd, format_pct
from utils.charts import credits_bar, donut_chart, COLORS

st.set_page_config(page_title="Model Breakdown", layout="wide")
st.title("Model Breakdown")
st.caption("Per-model cost and token analysis from flattened TOKENS_GRANULAR and CREDITS_GRANULAR arrays.")

credit_cost = get_credit_cost()
days = st.selectbox("Time Period", [7, 14, 30, 60, 90], index=2,
                     format_func=lambda d: f"Last {d} days", key="model_days")

model_df = get_model_cost_summary()
if model_df.empty:
    st.info("No granular model data found. Agent usage with TOKENS_GRANULAR is required.")
    st.stop()

st.markdown("---")
st.subheader("Credits by Model")

model_daily = get_model_daily_credits(days)
if not model_daily.empty:
    top_models = model_daily.groupby("MODEL_NAME")["DAILY_CREDITS"].sum().nlargest(8).index.tolist()
    chart_df = model_daily[model_daily["MODEL_NAME"].isin(top_models)]
    fig = credits_bar(chart_df, x="USAGE_DATE", y="DAILY_CREDITS",
                      color="MODEL_NAME", barmode="stack")
    st.plotly_chart(fig, use_container_width=True)

st.markdown("---")
col_svc, col_cache = st.columns(2)

with col_svc:
    st.subheader("Service Type Breakdown")
    svc_df = get_service_type_breakdown(days)
    if not svc_df.empty:
        fig = donut_chart(svc_df, values="TOTAL_CREDITS", names="SERVICE_TYPE")
        st.plotly_chart(fig, use_container_width=True)

        svc_display = svc_df.copy()
        svc_display["TOTAL_CREDITS"] = svc_display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.4f}")
        svc_display.columns = ["Service Type", "Credits", "Requests"]
        st.dataframe(svc_display, hide_index=True, use_container_width=True)
    else:
        st.info("No service type data available.")

with col_cache:
    st.subheader("Cache Efficiency")
    st.caption("Higher cache hit % = more prompt caching reuse = lower cost per request.")
    cache_df = get_cache_efficiency()
    if not cache_df.empty:
        cache_display = cache_df.copy()
        cache_display["CACHE_HIT_PCT"] = cache_display["CACHE_HIT_PCT"].apply(format_pct)
        cache_display["TOTAL_INPUT_TOKENS"] = cache_display["TOTAL_INPUT_TOKENS"].apply(lambda v: f"{v:,.0f}")
        cache_display["TOTAL_CACHE_READ_TOKENS"] = cache_display["TOTAL_CACHE_READ_TOKENS"].apply(lambda v: f"{v:,.0f}" if v else "0")
        cache_display["TOTAL_OUTPUT_TOKENS"] = cache_display["TOTAL_OUTPUT_TOKENS"].apply(lambda v: f"{v:,.0f}")
        cache_display = cache_display[["MODEL_NAME", "SERVICE_TYPE", "TOTAL_REQUESTS",
                                        "CACHE_HIT_PCT", "TOTAL_INPUT_TOKENS",
                                        "TOTAL_CACHE_READ_TOKENS", "TOTAL_OUTPUT_TOKENS"]]
        cache_display.columns = ["Model", "Service", "Requests", "Cache Hit %",
                                  "Input Tokens", "Cache Read", "Output Tokens"]
        st.dataframe(cache_display, hide_index=True, use_container_width=True)
    else:
        st.info("No cache efficiency data available.")

st.markdown("---")
st.subheader("Model Cost Detail")

model_display = model_df.copy()
model_display["EST_COST_USD"] = model_display["TOTAL_CREDITS"] * credit_cost
model_display["TOTAL_CREDITS"] = model_display["TOTAL_CREDITS"].apply(lambda v: f"{v:,.4f}")
model_display["AVG_CREDITS_PER_REQUEST"] = model_display["AVG_CREDITS_PER_REQUEST"].apply(lambda v: f"{v:,.6f}")
model_display["EST_COST_USD"] = model_display["EST_COST_USD"].apply(format_usd)
model_display.columns = ["Model", "Service Type", "Requests", "Credits",
                          "Avg Credits/Req", "Est. Cost"]
st.dataframe(model_display, hide_index=True, use_container_width=True)
