"""Runaway — in-flight AI Function query protection (interactive, simulate-only)."""
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Runaway", page_icon=":rotating_light:", layout="wide")
SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS"
session = get_active_session()


def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def get_config(key: str) -> str:
    df = run_query(f"SELECT config_value FROM {SCHEMA}.ENFORCEMENT_CONFIG WHERE config_key = '{key}'")
    return df.iloc[0]["CONFIG_VALUE"] if not df.empty else ""


st.title(":rotating_light: Runaway query protection")
st.caption(
    "A single AI_COMPLETE over a huge table can quietly burn credits. Use two layers: "
    "a time cap (STATEMENT_TIMEOUT, fires instantly) plus a cost cap (this page, fires with latency)."
)

st.subheader("Layer 1 — time-based (immediate)")
st.code(
    "ALTER WAREHOUSE <ai_wh> SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;  -- 30 min hard cap",
    language="sql",
)

st.markdown("---")
st.subheader("Layer 2 — cost-based (in-flight queries over threshold)")

default_threshold = float(get_config("RUNAWAY_CREDIT_THRESHOLD") or 10)
threshold = st.number_input("Credit threshold", min_value=0.0, value=default_threshold, step=1.0)

candidates = run_query(
    f"""
    SELECT query_id, start_time, function_name, model_name, user_name,
           credits_so_far, minutes_running
    FROM {SCHEMA}.V_RUNAWAY_CANDIDATES
    WHERE credits_so_far >= {float(threshold)}
    ORDER BY credits_so_far DESC
    """
)

simulate = get_config("SIMULATE_ONLY")
if candidates.empty:
    st.info(
        "No in-flight AI Function queries above the threshold right now. This is the normal state — "
        "the view only shows queries still running when ACCOUNT_USAGE reports them (10-60 min in). "
        "To exercise this page, run a large AI_COMPLETE while watching here."
    )
else:
    st.dataframe(candidates, use_container_width=True, hide_index=True)
    options = candidates["QUERY_ID"].tolist()
    qid = st.selectbox("Select a query to cancel", options)
    label = "Cancel query (SIMULATED)" if simulate == "TRUE" else "Cancel query (LIVE)"
    if st.button(label):
        result = session.sql(f"CALL {SCHEMA}.SP_CANCEL_RUNAWAY('{qid}')").collect()
        st.info(result[0][0] if result else "No result.")

st.markdown("---")
st.caption(
    "Honest scope: because the view lags 10-60 min, the cost cap only catches queries that run LONG "
    "AND exceed the threshold. The expensive-but-fast query finishes before it appears. The cost cap's "
    "real job is the slow-and-expensive query that sits just under your time cap."
)
