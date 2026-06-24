"""Anomaly — spend spikes vs trailing average, plus budget context."""
import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Anomaly", page_icon=":warning:", layout="wide")
SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS"
session = get_active_session()


@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


st.title(":warning: Anomaly detection & budget")
st.caption(
    "Snowsight (Admin → Cost Management) ships automatic anomaly detection. This page reproduces "
    "the core idea in SQL: flag any day whose AI_SERVICES spend exceeds 2x the trailing 7-day average."
)

# ── Spike detection over the billed daily series ─────────────────────────────
daily = run_query(
    f"""
    SELECT usage_day, credits_used
    FROM {SCHEMA}.V_AI_SPEND_DAILY
    WHERE usage_day >= DATEADD('day', -90, CURRENT_DATE())
    ORDER BY usage_day
    """
)

st.subheader("Daily AI spend vs 2x trailing 7-day average")
if daily.empty:
    st.info("No AI_SERVICES daily spend recorded yet.")
else:
    daily = daily.sort_values("USAGE_DAY").reset_index(drop=True)
    daily["TRAILING_7D_AVG"] = daily["CREDITS_USED"].rolling(7, min_periods=3).mean().shift(1)
    daily["THRESHOLD_2X"] = daily["TRAILING_7D_AVG"] * 2
    daily["ANOMALY"] = daily["CREDITS_USED"] > daily["THRESHOLD_2X"]
    st.line_chart(daily, x="USAGE_DAY", y=["CREDITS_USED", "THRESHOLD_2X"], height=280)

    anomalies = daily[daily["ANOMALY"]][["USAGE_DAY", "CREDITS_USED", "TRAILING_7D_AVG", "THRESHOLD_2X"]]
    if anomalies.empty:
        st.success("No anomalous spend days detected in the last 90 days.")
    else:
        st.warning(f"{len(anomalies)} anomalous day(s) detected:")
        st.dataframe(anomalies, use_container_width=True, hide_index=True)

st.markdown("---")

# ── Account budget context (built-in account root budget) ────────────────────
st.subheader("Account budget")
try:
    hist = session.sql(
        "SELECT * FROM TABLE(SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_HISTORY()) "
        "ORDER BY 1 DESC LIMIT 14"
    ).to_pandas()
    if hist.empty:
        st.caption("Account budget has no spending history yet.")
    else:
        st.dataframe(hist, use_container_width=True, hide_index=True)
except Exception as exc:  # noqa: BLE001 — budget read is best-effort
    st.caption(f"Account budget history unavailable from this role: {exc}")

st.markdown("**Programmatic alert pattern** (deploy as a scheduled alert):")
st.code(
    "CREATE OR REPLACE ALERT ai_spend_anomaly_alert\n"
    "  WAREHOUSE = '<your_warehouse>'\n"
    "  SCHEDULE = 'USING CRON 0 8 * * * America/Los_Angeles'\n"
    "  IF (EXISTS (\n"
    "    SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY\n"
    "    WHERE service_type = 'AI_SERVICES' AND usage_date = CURRENT_DATE() - 1\n"
    "      AND credits_used > (SELECT AVG(credits_used) * 2\n"
    "        FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY\n"
    "        WHERE service_type = 'AI_SERVICES'\n"
    "          AND usage_date >= DATEADD('day', -8, CURRENT_DATE())\n"
    "          AND usage_date < CURRENT_DATE() - 1)))\n"
    "  THEN CALL SYSTEM$SEND_EMAIL('ai_cost_alerts', 'admin@yourcompany.com',\n"
    "    'AI Spend Anomaly', 'Yesterday exceeded 2x the 7-day average.');",
    language="sql",
)
