"""
Data Quality Dashboard - Snowflake Native Data Quality Monitoring
Author: SE Community
Purpose: Real-time data quality visualization using DMFs and native Snowflake features
"""

from snowflake.snowpark.context import get_active_session
import pandas as pd
import streamlit as st

# Page configuration
st.set_page_config(
    page_title="Data Quality Dashboard",
    page_icon="✓",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom styling for a modern, clean look
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
    .quality-pass { color: #4ecdc4; font-weight: bold; }
    .quality-fail { color: #ff6b6b; font-weight: bold; }
    div[data-testid="stTabs"] button { font-weight: 500; }
    .block-container { padding-top: 2rem; }
</style>
""", unsafe_allow_html=True)

session = get_active_session()

# Header
st.title("Data Quality Dashboard")
st.caption("Real-time data quality monitoring using Snowflake Data Metric Functions")

# Tabs for different views
tab_realtime, tab_trends, tab_datasets, tab_system = st.tabs([
    "⚡ Real-Time Quality",
    "📈 Quality Trends",
    "📊 Dataset Explorer",
    "🔧 System Metrics"
])

# =============================================================================
# TAB 1: Real-Time Quality Checks (THE KEY DEMO FEATURE)
# =============================================================================
with tab_realtime:
    st.header("Live Quality Scores")
    st.markdown("Call Data Metric Functions directly for **instant** quality results.")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("🏃 Athlete Performance")

        # Call DMF directly for real-time result
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

        # Get record counts
        athlete_counts = session.sql("""
            SELECT
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE) AS raw_count,
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_ATHLETE_PERFORMANCE) AS clean_count
        """).collect()[0]

        raw_count = int(athlete_counts["RAW_COUNT"])
        clean_count = int(athlete_counts["CLEAN_COUNT"])
        filtered_out = raw_count - clean_count

        # Display metrics
        m1, m2, m3 = st.columns(3)
        m1.metric("Validity Score", f"{athlete_validity:.1f}%")
        m2.metric("Total Records", f"{raw_count:,}")
        m3.metric("Filtered Out", f"{filtered_out:,}", delta=f"-{filtered_out}" if filtered_out > 0 else None, delta_color="inverse")

        # Quality status indicator
        if athlete_validity >= 90:
            st.success(f"✓ PASSING - Validity {athlete_validity:.1f}% meets 90% threshold")
        else:
            st.error(f"✗ FAILING - Validity {athlete_validity:.1f}% below 90% threshold")

        # Show sample bad records
        with st.expander("View Quality Issues"):
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
                st.dataframe(bad_records, use_container_width=True, hide_index=True)
            else:
                st.info("No quality issues found!")

    with col2:
        st.subheader("👥 Fan Engagement")

        # Call DMF directly for real-time result
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

        # Get record counts
        fan_counts = session.sql("""
            SELECT
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT) AS raw_count,
                (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_FAN_ENGAGEMENT) AS clean_count
        """).collect()[0]

        fan_raw = int(fan_counts["RAW_COUNT"])
        fan_clean = int(fan_counts["CLEAN_COUNT"])
        fan_filtered = fan_raw - fan_clean

        # Display metrics
        m1, m2, m3 = st.columns(3)
        m1.metric("Validity Score", f"{fan_validity:.1f}%")
        m2.metric("Total Records", f"{fan_raw:,}")
        m3.metric("Filtered Out", f"{fan_filtered:,}", delta=f"-{fan_filtered}" if fan_filtered > 0 else None, delta_color="inverse")

        # Quality status indicator
        if fan_validity >= 90:
            st.success(f"✓ PASSING - Validity {fan_validity:.1f}% meets 90% threshold")
        else:
            st.error(f"✗ FAILING - Validity {fan_validity:.1f}% below 90% threshold")

        # Show sample bad records
        with st.expander("View Quality Issues"):
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
                st.dataframe(bad_fan, use_container_width=True, hide_index=True)
            else:
                st.info("No quality issues found!")

    # Refresh button
    st.markdown("---")
    if st.button("🔄 Refresh Quality Scores", type="primary"):
        st.rerun()

# =============================================================================
# TAB 2: Quality Trends (Historical Data from Task)
# =============================================================================
with tab_trends:
    st.header("Quality Score Trends")
    st.markdown("Historical quality metrics captured by the scheduled task (runs every 5 minutes).")

    # Get trend data
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

        # Summary cards
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

        # Trend charts
        st.subheader("Quality Score Over Time")
        for table in trend_df["TABLE_NAME"].unique():
            table_df = trend_df[trend_df["TABLE_NAME"] == table].sort_values("METRIC_DATE")
            if not table_df.empty:
                chart_df = table_df.set_index("METRIC_DATE")[["AVG_QUALITY_SCORE"]]
                chart_df.columns = [table]
                st.line_chart(chart_df)

        # Detailed metrics table
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
            st.dataframe(metrics_df, use_container_width=True, hide_index=True)

# =============================================================================
# TAB 3: Dataset Explorer (Raw vs Clean comparison)
# =============================================================================
with tab_datasets:
    st.header("Dataset Explorer")
    st.markdown("Compare raw data with quality-filtered 'golden' views.")

    dataset = st.radio(
        "Select Dataset",
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
        st.subheader("📦 Raw Data")
        raw_df = session.sql(f"SELECT {key_cols} FROM {raw_table} LIMIT 100").to_pandas()
        st.caption(f"Showing first 100 of {session.sql(f'SELECT COUNT(*) AS c FROM {raw_table}').collect()[0]['C']:,} records")
        st.dataframe(raw_df, use_container_width=True, hide_index=True)

    with col2:
        st.subheader("✨ Clean Data (Golden View)")
        clean_df = session.sql(f"SELECT {key_cols} FROM {clean_view} LIMIT 100").to_pandas()
        st.caption(f"Showing first 100 of {session.sql(f'SELECT COUNT(*) AS c FROM {clean_view}').collect()[0]['C']:,} records")
        st.dataframe(clean_df, use_container_width=True, hide_index=True)

    # Aggregation preview
    st.subheader("📊 Clean Data Aggregation")
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

    st.dataframe(agg_df, use_container_width=True, hide_index=True)

# =============================================================================
# TAB 4: System DMF Calls
# =============================================================================
with tab_system:
    st.header("System Data Metric Functions")
    st.markdown("Snowflake built-in DMFs provide instant insights without custom code.")

    dataset = st.selectbox(
        "Analyze Table",
        ["RAW_ATHLETE_PERFORMANCE", "RAW_FAN_ENGAGEMENT"]
    )

    if dataset == "RAW_ATHLETE_PERFORMANCE":
        target_col = "metric_value"
        id_col = "athlete_id"
        table_path = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE"
    else:
        target_col = "session_duration"
        id_col = "engagement_id"
        table_path = "SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT"

    col1, col2, col3, col4 = st.columns(4)

    # NULL_COUNT
    with col1:
        null_count = session.sql(f"""
            SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT {target_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("NULL Count", f"{int(null_count):,}" if null_count else "0")

    # NULL_PERCENT
    with col2:
        null_pct = session.sql(f"""
            SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT {target_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("NULL %", f"{float(null_pct):.2f}%" if null_pct else "0%")

    # DUPLICATE_COUNT
    with col3:
        dup_count = session.sql(f"""
            SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT {id_col} FROM {table_path}) AS val
        """).collect()[0]["VAL"]
        st.metric("Duplicate IDs", f"{int(dup_count):,}" if dup_count else "0")

    # Row count
    with col4:
        row_count = session.sql(f"SELECT COUNT(*) AS val FROM {table_path}").collect()[0]["VAL"]
        st.metric("Total Rows", f"{int(row_count):,}")

    st.markdown("---")
    st.subheader("📋 DMF Reference")

    st.code(f"""
-- NULL_COUNT: Count of NULL values in a column
SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT {target_col} FROM {table_path});

-- NULL_PERCENT: Percentage of NULL values
SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT {target_col} FROM {table_path});

-- DUPLICATE_COUNT: Count of duplicate values
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT {id_col} FROM {table_path});

-- Custom DMF: Call your own quality checks
SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT(
    SELECT metric_value FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
);
""", language="sql")

# Footer
st.markdown("---")
st.caption("Data Quality Dashboard | Powered by Snowflake Data Metric Functions | Author: SE Community")
