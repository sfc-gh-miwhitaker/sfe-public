import streamlit as st
from utils.data import get_user_budgets, get_config, get_anomalies
from utils.formatting import format_credits

st.set_page_config(page_title="Cost Controls", layout="wide")
st.title("Cost Controls")

tab1, tab2, tab3 = st.tabs(["Budget Status", "Anomalies", "Configuration"])

with tab1:
    st.subheader("Per-User Budget Status")
    st.markdown(
        "Budget enforcement is managed by the governance module. "
        "Use `CALL PROC_GRANT_AI_ACCESS('USER', limit)` to add users."
    )
    try:
        budgets = get_user_budgets()
        if len(budgets) > 0:
            st.dataframe(budgets, use_container_width=True, hide_index=True)
        else:
            st.info(
                "No user budgets configured. Enable governance module and use "
                "`CALL PROC_GRANT_AI_ACCESS('USERNAME', 100)` to add budgets."
            )
    except Exception:
        st.warning("Governance module not deployed. Run `sql/05_governance/user_budgets.sql` to enable.")

with tab2:
    st.subheader("Active Anomalies (Medium+)")
    anomalies = get_anomalies()
    if len(anomalies) > 0:
        for _, row in anomalies.iterrows():
            severity = row.get("ALERT_SEVERITY", "UNKNOWN")
            color = "red" if severity == "HIGH" else "orange"
            st.markdown(
                f":{color}[**{severity}**] {row['SERVICE_TYPE']} — "
                f"{format_credits(row['WEEKLY_CREDITS'])} credits "
                f"({row.get('WOW_GROWTH_PCT', 0):.0%} WoW)"
            )
    else:
        st.success("No active anomalies.")

with tab3:
    st.subheader("Runtime Configuration")
    config = get_config()
    if len(config) > 0:
        st.dataframe(config, use_container_width=True, hide_index=True)

    st.markdown("---")
    st.subheader("Governance SQL Quick Reference")
    st.code(
        "-- Grant AI access with budget\n"
        "CALL PROC_GRANT_AI_ACCESS('ALICE', 500);\n\n"
        "-- Revoke AI access\n"
        "CALL PROC_REVOKE_AI_ACCESS('ALICE', 'Over budget');\n\n"
        "-- Check all budgets\n"
        "CALL PROC_CHECK_USER_BUDGETS();\n\n"
        "-- Manually run runaway detection\n"
        "CALL PROC_MONITOR_AND_CANCEL_RUNAWAY_QUERIES(50);",
        language="sql",
    )
