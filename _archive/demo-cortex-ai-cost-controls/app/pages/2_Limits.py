"""Limits — per-user AI Function caps (interactive, simulate-only)."""
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Limits", page_icon=":lock:", layout="wide")
SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS"
session = get_active_session()


def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def get_config(key: str) -> str:
    df = run_query(f"SELECT config_value FROM {SCHEMA}.ENFORCEMENT_CONFIG WHERE config_key = '{key}'")
    return df.iloc[0]["CONFIG_VALUE"] if not df.empty else ""


st.title(":lock: Limits — per-user enforcement")

simulate = get_config("SIMULATE_ONLY")
if simulate == "TRUE":
    st.success("SIMULATE-ONLY mode. Enforcement is previewed and logged — no grants are changed.")
else:
    st.error("LIVE ENFORCEMENT mode (SIMULATE_ONLY = FALSE). Running enforcement will revoke roles.")

# ── CoCo native limits (informational) ───────────────────────────────────────
st.subheader("Cortex Code (CoCo) — native limits")
st.caption("CoCo is the only Cortex service with built-in per-user credit limits. One statement each.")
st.code(
    "ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;\n"
    "ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;\n"
    "ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;\n"
    "-- Override per user:\n"
    "ALTER USER power_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;",
    language="sql",
)

st.markdown("---")

# ── DIY AI Function limits (interactive) ─────────────────────────────────────
st.subheader("AI Functions — DIY per-user limits")
st.caption(
    "AI Functions have no native per-user cap. This limits table + procedure + (suspended) task "
    "implement it. Edit a user's daily credit limit below; status compares today's observed spend."
)

status = run_query(
    f"""
    SELECT user_name, daily_credit_limit, enabled, credits_today, calls_today, status, would_action
    FROM {SCHEMA}.V_LIMIT_STATUS
    ORDER BY credits_today DESC, user_name
    """
)
st.dataframe(status, use_container_width=True, hide_index=True)

# Add / update a limit
with st.form("set_limit"):
    st.markdown("**Set or update a user limit**")
    col1, col2, col3 = st.columns([2, 1, 1])
    u = col1.text_input("User name", value="ALICE")
    lim = col2.number_input("Daily credit limit", min_value=0.0, value=5.0, step=1.0)
    enabled = col3.checkbox("Enabled", value=True)
    submitted = st.form_submit_button("Save limit")
    if submitted and u.strip():
        session.sql(
            f"""
            MERGE INTO {SCHEMA}.AI_FUNCTION_USER_LIMITS t
            USING (SELECT '{u.strip().upper()}' AS user_name, {float(lim)} AS lim, {bool(enabled)} AS en) s
            ON UPPER(t.user_name) = UPPER(s.user_name)
            WHEN MATCHED THEN UPDATE SET daily_credit_limit = s.lim, enabled = s.en, updated_at = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN INSERT (user_name, daily_credit_limit, enabled, updated_at)
                VALUES (s.user_name, s.lim, s.en, CURRENT_TIMESTAMP())
            """
        ).collect()
        st.success(f"Saved limit for {u.strip().upper()}.")
        st.rerun()

# Run enforcement (simulate)
if st.button("Run enforcement now (logs over-limit users)"):
    result = session.sql(f"CALL {SCHEMA}.SP_ENFORCE_AI_FUNCTION_LIMITS()").collect()
    st.info(result[0][0] if result else "No result.")

st.markdown("**Recent enforcement audit**")
audit = run_query(
    f"""
    SELECT event_at, action, target_user, detail, simulated
    FROM {SCHEMA}.ENFORCEMENT_AUDIT
    ORDER BY event_at DESC
    LIMIT 20
    """
)
if audit.empty:
    st.caption("No enforcement runs logged yet.")
else:
    st.dataframe(audit, use_container_width=True, hide_index=True)

st.caption(
    "The scheduled task TASK_ENFORCE_AI_FUNCTION_LIMITS ships SUSPENDED. Activating it consumes "
    "compute on its schedule; ACCOUNT_USAGE latency (45-60 min) makes this a safety net, not real-time."
)
