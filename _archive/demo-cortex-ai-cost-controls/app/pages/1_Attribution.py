"""Attribution — spend by cost center (tag-based) with a by-agent fallback."""
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Attribution", page_icon=":label:", layout="wide")
SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":label: Attribution — who is spending?")
st.caption(
    "Tags answer 'which team/project owns this spend?'. Apply a COST_CENTER tag to "
    "agents and users, then spend groups by cost center. Tags only attribute forward — "
    "spend before you tag is unattributed."
)

# ── Tag-based attribution (primary) ──────────────────────────────────────────
st.subheader("By cost center (COST_CENTER tag)")
attribution = run_query(
    f"""
    SELECT cost_center, agent_fqn, total_credits, request_count
    FROM {SCHEMA}.V_AGENT_ATTRIBUTION
    ORDER BY total_credits DESC
    """
)
if attribution.empty:
    st.info(
        "No COST_CENTER tags applied yet, so there is nothing to attribute. "
        "Apply tags with the SQL below, then revisit (tags attribute forward only)."
    )
    st.code(
        "ALTER AGENT <db>.<schema>.<agent>\n"
        f"  SET TAG {SCHEMA}.COST_CENTER = 'sales_team';\n\n"
        "ALTER USER <name>\n"
        f"  SET TAG {SCHEMA}.COST_CENTER = 'sales_team';",
        language="sql",
    )
else:
    by_cc = attribution.groupby("COST_CENTER", as_index=False)["TOTAL_CREDITS"].sum()
    st.bar_chart(by_cc, x="COST_CENTER", y="TOTAL_CREDITS", height=280)
    st.dataframe(attribution, use_container_width=True, hide_index=True)

st.markdown("---")

# ── By-agent fallback (always shown if agents exist) ─────────────────────────
st.subheader("By agent (last 30 days)")
agents = run_query(
    f"""
    SELECT agent_fqn, total_credits, request_count, distinct_users
    FROM {SCHEMA}.V_AGENT_SPEND_30D
    ORDER BY total_credits DESC
    """
)
if agents.empty:
    st.caption("No Cortex Agent activity in the last 30 days on this account.")
else:
    st.dataframe(agents, use_container_width=True, hide_index=True)

st.markdown("---")

# ── Per-user across all services ─────────────────────────────────────────────
st.subheader("By user (all services, last 30 days)")
users = run_query(
    f"""
    SELECT user_name, total_credits, event_rows
    FROM {SCHEMA}.V_AI_SPEND_BY_USER_30D
    ORDER BY total_credits DESC
    LIMIT 25
    """
)
if users.empty:
    st.caption("No per-user spend recorded yet.")
else:
    st.dataframe(users, use_container_width=True, hide_index=True)
