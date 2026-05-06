"""
Data Quality Dashboard - Snowflake Native Data Quality Monitoring
Author: SE Community
Purpose: Real-time data quality visualization using DMFs and native Snowflake features
"""

from snowflake.snowpark.context import get_active_session
import pandas as pd
import streamlit as st

st.set_page_config(
    page_title="Data Quality Dashboard",
    page_icon="✓",
    layout="wide",
    initial_sidebar_state="expanded"
)

st.markdown("""
<style>
    .stMetric {
        background: linear-gradient(135deg, #1e3a5f 0%, #2d5a87 100%);
        padding: 1rem;
        border-radius: 0.75rem;
        border-left: 4px solid #4ecdc4;
    }
    .stMetric label { color: #a8d5e5; }
    .stMetric [data-testid="stMetricValue"] { color: #ffffff; font-weight: 600; }
    div[data-testid="stTabs"] button { font-weight: 500; }
    .block-container { padding-top: 2rem; }
</style>
""", unsafe_allow_html=True)

session = get_active_session()

st.title("Data Quality Dashboard")
st.caption("Real-time monitoring powered by Snowflake Data Metric Functions and Object Tagging")

tab_realtime, tab_trends, tab_datasets, tab_system, tab_tags = st.tabs([
    "Real-Time Quality",
    "Quality Trends",
    "Dataset Explorer",
    "System DMFs",
    "Tags & Governance"
])

FRIENDLY_COLS = {
    "ATHLETE_ID": "Athlete ID",
    "NGB_CODE": "NGB Code",
    "SPORT": "Sport",
    "METRIC_TYPE": "Metric Type",
    "METRIC_VALUE": "Metric Value",
    "DATA_SOURCE": "Data Source",
    "ENGAGEMENT_ID": "Engagement ID",
    "FAN_ID": "Fan ID",
    "CHANNEL": "Channel",
    "EVENT_TYPE": "Event Type",
    "SESSION_DURATION": "Session Duration",
    "CONVERSION_FLAG": "Conversion",
    "ISSUE": "Issue",
    "METRIC_DATE": "Date",
    "TABLE_NAME": "Table",
    "METRIC_NAME": "Metric",
    "RECORDS_EVALUATED": "Records Evaluated",
    "FAILURES_DETECTED": "Failures Detected",
    "AVG_QUALITY_SCORE": "Avg Quality Score",
    "TAG_NAME": "Tag",
    "TAG_VALUE": "Value",
    "OBJECT_NAME": "Object",
    "DOMAIN": "Domain",
    "COLUMN_NAME": "Column",
    "LEVEL": "Level",
}

def friendly(df):
    """Rename SCREAMING_CASE columns to Title Case for display."""
    return df.rename(columns={c: FRIENDLY_COLS.get(c, c.replace("_", " ").title()) for c in df.columns})

# =============================================================================
# TAB 1: Real-Time Quality Checks
# =============================================================================
with tab_realtime:
    st.header("Live Quality Scores")
    st.markdown("Call Data Metric Functions directly for **instant** quality results.")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Athlete Performance")

        athlete_dmf_query = """
        SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT(
            SELECT metric_value FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
        ) AS validity_pct
        """
        try:
            athlete_validity = session.sql(athlete_dmf_query).collect()[0]["VALIDITY_PCT"]
            athlete_validity = float(athlete_validity) if athlete_validity else 0.0
        except Exception:
            athlete_validity = 0.0

        athlete_counts = session.sql("""
            SELECT
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE) AS raw_count,
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_ATHLETE_PERFORMANCE) AS clean_count
        """).collect()[0]

        raw_count = int(athlete_counts["RAW_COUNT"])
        clean_count = int(athlete_counts["CLEAN_COUNT"])
        filtered_out = raw_count - clean_count

        m1, m2, m3 = st.columns(3)
        m1.metric("Validity Score", f"{athlete_validity:.1f}%")
        m2.metric("Total Records", f"{raw_count:,}")
        m3.metric("Filtered Out", f"{filtered_out:,}", delta=f"-{filtered_out}" if filtered_out > 0 else None, delta_color="inverse")

        if athlete_validity >= 90:
            st.success(f"Passing — validity {athlete_validity:.1f}% meets the 90% threshold")
        else:
            st.error(f"Failing — validity {athlete_validity:.1f}% is below the 90% threshold")

        with st.expander("View quality issues"):
            bad_records = session.sql("""
                SELECT athlete_id, sport, metric_type, metric_value,
                    CASE
                        WHEN metric_value IS NULL THEN 'NULL value'
                        WHEN metric_value < 0 THEN 'Below zero'
                        WHEN metric_value > 100 THEN 'Above 100'
                    END AS issue
                FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
                WHERE metric_value IS NULL OR metric_value < 0 OR metric_value > 100
                LIMIT 10
            """).to_pandas()
            if not bad_records.empty:
                st.dataframe(friendly(bad_records), use_container_width=True, hide_index=True)
            else:
                st.info("No quality issues found.")

    with col2:
        st.subheader("Fan Engagement")

        fan_dmf_query = """
        SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_SESSION_DURATION_VALID_PCT(
            SELECT session_duration FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
        ) AS validity_pct
        """
        try:
            fan_validity = session.sql(fan_dmf_query).collect()[0]["VALIDITY_PCT"]
            fan_validity = float(fan_validity) if fan_validity else 0.0
        except Exception:
            fan_validity = 0.0

        fan_counts = session.sql("""
            SELECT
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT) AS raw_count,
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_FAN_ENGAGEMENT) AS clean_count
        """).collect()[0]

        fan_raw = int(fan_counts["RAW_COUNT"])
        fan_clean = int(fan_counts["CLEAN_COUNT"])
        fan_filtered = fan_raw - fan_clean

        m1, m2, m3 = st.columns(3)
        m1.metric("Validity Score", f"{fan_validity:.1f}%")
        m2.metric("Total Records", f"{fan_raw:,}")
        m3.metric("Filtered Out", f"{fan_filtered:,}", delta=f"-{fan_filtered}" if fan_filtered > 0 else None, delta_color="inverse")

        if fan_validity >= 90:
            st.success(f"Passing — validity {fan_validity:.1f}% meets the 90% threshold")
        else:
            st.error(f"Failing — validity {fan_validity:.1f}% is below the 90% threshold")

        with st.expander("View quality issues"):
            bad_fan = session.sql("""
                SELECT engagement_id, channel, event_type, session_duration,
                    CASE
                        WHEN session_duration IS NULL THEN 'NULL value'
                        WHEN session_duration < 0 THEN 'Below zero'
                        WHEN session_duration > 14400 THEN 'Above 4 hours'
                    END AS issue
                FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
                WHERE session_duration IS NULL OR session_duration < 0 OR session_duration > 14400
                LIMIT 10
            """).to_pandas()
            if not bad_fan.empty:
                st.dataframe(friendly(bad_fan), use_container_width=True, hide_index=True)
            else:
                st.info("No quality issues found.")

    st.markdown("---")
    if st.button("Refresh Quality Scores", type="primary"):
        st.rerun()

# =============================================================================
# TAB 2: Quality Trends
# =============================================================================
with tab_trends:
    st.header("Quality Score Trends")
    st.markdown("Historical quality metrics captured by the scheduled task (runs every 5 minutes).")

    trend_df = session.sql("""
        SELECT
            metric_date,
            table_name,
            avg_quality_score,
            failures_detected
        FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_QUALITY_SCORE_TREND
        ORDER BY metric_date DESC, table_name
    """).to_pandas()

    if trend_df.empty:
        st.warning("No trend data available yet. The task runs every 5 minutes, or you can manually trigger it.")
        st.code("EXECUTE TASK SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task;", language="sql")
    else:
        trend_df["METRIC_DATE"] = pd.to_datetime(trend_df["METRIC_DATE"])

        col1, col2, col3 = st.columns(3)
        with col1:
            latest_avg = trend_df.groupby("METRIC_DATE")["AVG_QUALITY_SCORE"].mean().iloc[-1] if len(trend_df) > 0 else 0
            st.metric("Latest Avg Score", f"{latest_avg:.1f}%")
        with col2:
            total_failures = trend_df["FAILURES_DETECTED"].sum()
            st.metric("Total Failures Tracked", f"{int(total_failures):,}")
        with col3:
            days_tracked = trend_df["METRIC_DATE"].nunique()
            st.metric("Days Tracked", days_tracked)

        st.subheader("Quality Score Over Time")
        for table in trend_df["TABLE_NAME"].unique():
            table_df = trend_df[trend_df["TABLE_NAME"] == table].sort_values("METRIC_DATE")
            if not table_df.empty:
                chart_df = table_df.set_index("METRIC_DATE")[["AVG_QUALITY_SCORE"]]
                chart_df.columns = [table.replace("_", " ").title()]
                st.line_chart(chart_df)

        st.subheader("Metric History")
        metrics_df = session.sql("""
            SELECT
                metric_date,
                table_name,
                metric_name,
                metric_value,
                records_evaluated,
                failures_detected
            FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_DATA_QUALITY_METRICS
            ORDER BY metric_date DESC, table_name, metric_name
            LIMIT 50
        """).to_pandas()

        if not metrics_df.empty:
            st.dataframe(friendly(metrics_df), use_container_width=True, hide_index=True)

# =============================================================================
# TAB 3: Dataset Explorer
# =============================================================================
with tab_datasets:
    st.header("Dataset Explorer")
    st.markdown("Compare raw data with quality-filtered golden views.")

    dataset = st.radio(
        "Select dataset",
        ["Athlete Performance", "Fan Engagement"],
        horizontal=True
    )

    if dataset == "Athlete Performance":
        raw_table = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE"
        clean_view = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_ATHLETE_PERFORMANCE"
        key_cols = "athlete_id, ngb_code, sport, metric_value"
    else:
        raw_table = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT"
        clean_view = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_FAN_ENGAGEMENT"
        key_cols = "engagement_id, fan_id, channel, session_duration"

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Raw Data")
        raw_df = session.sql(f"SELECT {key_cols} FROM {raw_table} LIMIT 100").to_pandas()
        st.caption(f"Showing first 100 of {session.sql(f'SELECT COUNT(*) AS c FROM {raw_table}').collect()[0]['C']:,} records")
        st.dataframe(friendly(raw_df), use_container_width=True, hide_index=True)

    with col2:
        st.subheader("Clean Data (Golden View)")
        clean_df = session.sql(f"SELECT {key_cols} FROM {clean_view} LIMIT 100").to_pandas()
        st.caption(f"Showing first 100 of {session.sql(f'SELECT COUNT(*) AS c FROM {clean_view}').collect()[0]['C']:,} records")
        st.dataframe(friendly(clean_df), use_container_width=True, hide_index=True)

    st.subheader("Clean Data Aggregation")
    if dataset == "Athlete Performance":
        agg_df = session.sql("""
            SELECT
                sport,
                COUNT(*) AS athletes,
                ROUND(AVG(metric_value), 1) AS avg_score,
                ROUND(MIN(metric_value), 1) AS min_score,
                ROUND(MAX(metric_value), 1) AS max_score
            FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_ATHLETE_PERFORMANCE
            GROUP BY sport
            ORDER BY avg_score DESC
        """).to_pandas()
    else:
        agg_df = session.sql("""
            SELECT
                channel,
                COUNT(*) AS engagements,
                ROUND(AVG(session_duration), 0) AS avg_duration_sec,
                SUM(CASE WHEN conversion_flag THEN 1 ELSE 0 END) AS conversions
            FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_FAN_ENGAGEMENT
            GROUP BY channel
            ORDER BY engagements DESC
        """).to_pandas()

    st.dataframe(friendly(agg_df), use_container_width=True, hide_index=True)

# =============================================================================
# TAB 4: System DMFs
# =============================================================================
with tab_system:
    st.header("System Data Metric Functions")
    st.markdown("Built-in Snowflake DMFs provide instant insights without custom code.")

    dataset = st.selectbox(
        "Analyze table",
        ["Athlete Performance", "Fan Engagement"]
    )

    if dataset == "Athlete Performance":
        target_col = "metric_value"
        id_col = "athlete_id"
        table_path = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE"
    else:
        target_col = "session_duration"
        id_col = "engagement_id"
        table_path = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT"

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        null_count = session.sql(f"""
            SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT {target_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("Null Count", f"{int(null_count):,}" if null_count else "0")

    with col2:
        null_pct = session.sql(f"""
            SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT {target_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("Null %", f"{float(null_pct):.2f}%" if null_pct else "0%")

    with col3:
        dup_count = session.sql(f"""
            SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT {id_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("Duplicate IDs", f"{int(dup_count):,}" if dup_count else "0")

    with col4:
        row_count = session.sql(f"SELECT COUNT(*) AS val FROM {table_path}").collect()[0]["VAL"]
        st.metric("Total Rows", f"{int(row_count):,}")

    st.markdown("---")
    with st.expander("SQL Reference"):
        st.code(f"""
-- Null count for a column
SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT {target_col} FROM {table_path});

-- Null percentage
SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT {target_col} FROM {table_path});

-- Duplicate count
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT {id_col} FROM {table_path});

-- Custom DMF
SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT(
    SELECT metric_value FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
);
""", language="sql")

# =============================================================================
# TAB 5: Tags & Governance
# =============================================================================
with tab_tags:
    st.header("Tags & Governance")
    st.markdown("Object tags classify data assets by **domain**, **sensitivity**, and **quality tier**.")

    try:
        tag_df = session.sql("""
            SELECT TAG_NAME, TAG_VALUE, OBJECT_NAME, DOMAIN, COLUMN_NAME, LEVEL
            FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_TAG_GOVERNANCE_SUMMARY
            ORDER BY TAG_NAME, OBJECT_NAME, COLUMN_NAME
        """).to_pandas()
    except Exception:
        tag_df = pd.DataFrame()

    if tag_df.empty:
        st.warning("No tag data available. Ensure the tagging script has been deployed.")
    else:
        col1, col2, col3 = st.columns(3)

        domain_counts = tag_df[tag_df["TAG_NAME"] == "DATA_DOMAIN"]["TAG_VALUE"].value_counts()
        sensitivity_counts = tag_df[tag_df["TAG_NAME"] == "DATA_SENSITIVITY"]["TAG_VALUE"].value_counts()
        tier_counts = tag_df[tag_df["TAG_NAME"] == "DATA_QUALITY_TIER"]["TAG_VALUE"].value_counts()

        with col1:
            st.subheader("Data Domain")
            for val, cnt in domain_counts.items():
                st.metric(val.title(), cnt)

        with col2:
            st.subheader("Sensitivity")
            for val, cnt in sensitivity_counts.items():
                st.metric(val.title(), cnt)

        with col3:
            st.subheader("Quality Tier")
            for val, cnt in tier_counts.items():
                st.metric(val.title(), cnt)

        st.markdown("---")

        st.subheader("All Tag Assignments")
        display_df = tag_df.copy()
        display_df["COLUMN_NAME"] = display_df["COLUMN_NAME"].fillna("—")
        st.dataframe(friendly(display_df), use_container_width=True, hide_index=True)

        st.markdown("---")
        st.subheader("Tag-Based Masking")
        st.markdown(
            "Columns tagged `DATA_SENSITIVITY = 'CONFIDENTIAL'` are automatically masked "
            "for non-admin roles via a **tag-based masking policy**. No per-column policy assignment needed."
        )

        confidential_cols = tag_df[
            (tag_df["TAG_NAME"] == "DATA_SENSITIVITY") & (tag_df["TAG_VALUE"] == "CONFIDENTIAL")
        ][["OBJECT_NAME", "COLUMN_NAME"]].reset_index(drop=True)

        if not confidential_cols.empty:
            st.dataframe(friendly(confidential_cols), use_container_width=True, hide_index=True)
        else:
            st.info("No confidential columns found.")

st.markdown("---")
st.caption("Data Quality Dashboard | Powered by Snowflake Data Metric Functions & Object Tagging")
