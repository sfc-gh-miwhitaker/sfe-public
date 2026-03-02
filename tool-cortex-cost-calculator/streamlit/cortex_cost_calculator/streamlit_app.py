import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from snowflake.snowpark.context import get_active_session
import plotly.graph_objects as go
import plotly.express as px

# Get Snowflake session
session = get_active_session()

st.set_page_config(
    page_title="Cortex Cost Calculator",
    page_icon="C",
    layout="wide"
)

# ============================================================================
# Constants for POC-to-Production scaling and benchmarks
# ============================================================================

POC_TO_PROD_MULTIPLIERS = {
    "Light POC (5-10 users, exploratory)": {"user_mult": 20, "usage_mult": 1.5, "description": "POC users testing lightly → Production with broader adoption"},
    "Standard POC (10-25 users, regular use)": {"user_mult": 10, "usage_mult": 1.2, "description": "Active POC testing → Production steady-state"},
    "Heavy POC (25+ users, production-like)": {"user_mult": 4, "usage_mult": 1.0, "description": "Production-like POC → Full production rollout"},
    "Custom": {"user_mult": 1, "usage_mult": 1, "description": "Define your own scaling factors"}
}

# Industry benchmarks (credits per user per month by service)
USAGE_BENCHMARKS = {
    "Cortex Analyst": {"low": 1.0, "typical": 3.0, "high": 8.0, "unit": "credits/user/month"},
    "Cortex Functions": {"low": 0.5, "typical": 2.0, "high": 10.0, "unit": "credits/user/month"},
    "Cortex Search": {"low": 0.1, "typical": 0.5, "high": 2.0, "unit": "credits/user/month"},
    "Document AI": {"low": 0.2, "typical": 1.0, "high": 5.0, "unit": "credits/user/month"},
}

# Data maturity thresholds
DATA_MATURITY_THRESHOLDS = {
    "minimum": 3,      # Minimum days for any projection
    "developing": 7,   # Starting to be useful
    "reliable": 14,    # Projections becoming reliable
    "confident": 30,   # High confidence in projections
}

# ============================================================================
# Utility Functions
# ============================================================================

@st.cache_data(ttl=300, max_entries=10)  # Cache for 5 minutes
def fetch_data_from_views(lookback_days=30):
    """Fetch data from historical snapshot table (with fallback to live view)"""
    # Try snapshot table first (faster)
    snapshot_query = f"""
    SELECT
        date,
        service_type,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation,
        avg_daily_cost_per_user,
        projected_monthly_cost_per_user,
        projected_monthly_total_credits,
        credits_7d_ago,
        credits_wow_growth_pct
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_USAGE_HISTORY
    WHERE date >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
    ORDER BY date DESC
    """

    try:
        df = session.sql(snapshot_query).to_pandas()
        if not df.empty:
            st.success(f"Loaded {len(df)} rows from snapshot table (optimized for speed)")
            return df
        else:
            st.info("Snapshot table is empty. Falling back to live views...")
    except Exception as e:
        error_msg = str(e).lower()
        if "does not exist" in error_msg or "invalid identifier" in error_msg:
            st.warning(
                "Snapshot table not found. Using live views (may be slower). "
                "To create snapshots, run: `EXECUTE TASK SNOWFLAKE_EXAMPLE.CORTEX_USAGE.TASK_DAILY_CORTEX_SNAPSHOT`"
            )
        elif "insufficient privileges" in error_msg or "access denied" in error_msg:
            st.error(
                "Permission denied accessing snapshot table. Please ensure you have SELECT privileges on "
                "SNOWFLAKE_EXAMPLE.CORTEX_USAGE."
            )
            st.info("**Troubleshooting:** Run `GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE TO ROLE <YOUR_ROLE>;`")
            return pd.DataFrame()
        else:
            st.warning(f"Error accessing snapshot table: {str(e)[:100]}. Falling back to live views...")

    # Fallback to live view if snapshot is empty or doesn't exist
    live_query = f"""
    SELECT
        date,
        service_type,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation,
        ROUND(credits_per_user, 4) AS avg_daily_cost_per_user,
        ROUND(credits_per_user * 30, 2) AS projected_monthly_cost_per_user,
        ROUND(total_credits * 30, 2) AS projected_monthly_total_credits,
        NULL AS credits_7d_ago,
        NULL AS credits_wow_growth_pct
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
    WHERE date >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
    ORDER BY date DESC
    """

    try:
        df = session.sql(live_query).to_pandas()
        if df.empty:
            st.warning("No data found in the specified lookback period. This may be because:")
            st.info(
                f"""
                - No Cortex usage in the last {lookback_days} days
                - ACCOUNT_USAGE data is still being populated (wait 3 hours after usage)
                - Insufficient privileges on SNOWFLAKE.ACCOUNT_USAGE views

                **To verify access:** Run `SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY WHERE SERVICE_TYPE = 'AI_SERVICES'`
                """
            )
        else:
            st.info(f"Loaded {len(df)} rows from live views")
        return df
    except Exception as e:
        error_msg = str(e).lower()
        if "insufficient privileges" in error_msg or "access denied" in error_msg:
            st.error("Permission denied accessing monitoring views.")
            st.info("""
            **Required privileges:**
            1. `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;`
            2. `GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE TO ROLE <YOUR_ROLE>;`

            **Or switch to ACCOUNTADMIN:** `USE ROLE ACCOUNTADMIN;`
            """)
        elif "does not exist" in error_msg:
            st.error("Monitoring views not found. Please deploy monitoring infrastructure first.")
            st.info("**Deploy views:** Run `sql/01_deployment/deploy_cortex_monitoring.sql`")
        else:
            st.error(f"Error fetching data: {str(e)}")
            st.info("**Check:** Warehouse is running, views exist, and you have proper permissions")
        return pd.DataFrame()

@st.cache_data(ttl=300, max_entries=50)  # Cache for 5 minutes, bounded to 50 entries
def fetch_user_spend_attribution(lookback_days=30):
    """Fetch user-level spend attribution (Analyst + Functions + Document Processing)."""
    query = f"""
    SELECT
        usage_date,
        user_name,
        service_type,
        feature_name,
        model_name,
        credits_used,
        operations,
        credits_per_operation
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_USER_SPEND_ATTRIBUTION
    WHERE usage_date >= DATEADD('day', -{lookback_days}, CURRENT_DATE())
    ORDER BY usage_date DESC, credits_used DESC
    """
    try:
        df = session.sql(query).to_pandas()
        if df.empty:
            st.info("No user attribution data found. This view requires query-level tracking.")
        return df
    except Exception as e:
        error_msg = str(e).lower()
        if "does not exist" in error_msg:
            st.warning("User attribution view not found. Deploy the latest monitoring views.")
        else:
            st.error(f"Error fetching user attribution: {str(e)[:100]}")
        return pd.DataFrame()

@st.cache_data(ttl=300, max_entries=10)  # Cache for 5 minutes, bounded to 10 entries
def fetch_ml_forecast_12m():
    """Fetch 12-month daily forecast from the ML-backed view (may be empty if model unavailable)."""
    query = """
    SELECT
        service_type,
        forecast_date,
        forecast_credits,
        lower_bound_credits,
        upper_bound_credits
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_USAGE_FORECAST_12M
    ORDER BY forecast_date
    """
    try:
        df = session.sql(query).to_pandas()
        if df.empty:
            st.info("ML forecast model not available. Using manual projection methods instead.")
            st.caption("**To enable ML forecasting:** Ensure you have privileges to create SNOWFLAKE.ML.FORECAST models")
        return df
    except Exception as e:
        error_msg = str(e).lower()
        if "does not exist" in error_msg:
            st.info("Forecast view not found. Using manual projections.")
        else:
            st.warning(f"ML forecast unavailable: {str(e)[:100]}")
        return pd.DataFrame()

def calculate_30day_totals(df):
    """Calculate rolling 30-day totals for cost estimation"""
    if df.empty:
        return pd.DataFrame()

    # Sort by date ascending for rolling calculations
    df_sorted = df.sort_values('DATE')

    # Calculate 30-day rolling totals by service type
    df_sorted['credits_30d_total'] = df_sorted.groupby('SERVICE_TYPE')['TOTAL_CREDITS'].transform(
        lambda x: x.rolling(window=30, min_periods=1).sum()
    )

    df_sorted['operations_30d_total'] = df_sorted.groupby('SERVICE_TYPE')['TOTAL_OPERATIONS'].transform(
        lambda x: x.rolling(window=30, min_periods=1).sum()
    )

    df_sorted['users_30d_avg'] = df_sorted.groupby('SERVICE_TYPE')['DAILY_UNIQUE_USERS'].transform(
        lambda x: x.rolling(window=30, min_periods=1).mean()
    )

    # Calculate 30-day average cost per user
    df_sorted['cost_per_user_30d'] = df_sorted['credits_30d_total'] / df_sorted['users_30d_avg']
    df_sorted['cost_per_user_30d'] = df_sorted['cost_per_user_30d'].fillna(0)

    return df_sorted.sort_values('DATE', ascending=False)

def calculate_growth_projection(df, growth_rate, projection_months=12, credit_cost=3.00):
    """Calculate cost projections based on growth rate"""
    baseline = df.groupby('SERVICE_TYPE').agg({
        'TOTAL_CREDITS': 'sum',
        'DAILY_UNIQUE_USERS': 'mean'
    }).reset_index()

    projections = []
    for month in range(1, projection_months + 1):
        for _, service in baseline.iterrows():
            growth_factor = (1 + growth_rate) ** month
            projected_credits = service['TOTAL_CREDITS'] * growth_factor
            projected_users = service['DAILY_UNIQUE_USERS'] * growth_factor
            projected_cost = projected_credits * credit_cost

            projections.append({
                'month': month,
                'service_type': service['SERVICE_TYPE'],
                'projected_credits': projected_credits,
                'projected_users': projected_users,
                'projected_cost_usd': projected_cost,
                'cost_per_user_usd': projected_cost / projected_users if projected_users > 0 else 0,
                'growth_rate': growth_rate
            })

    return pd.DataFrame(projections)

def format_currency(value):
    """Format value as currency"""
    return f"${value:,.2f}"

def format_number(value):
    """Format value as number with commas"""
    return f"{value:,.0f}"

def assess_data_maturity(df):
    """
    Assess data maturity and return readiness metrics.
    Returns dict with maturity level, days of data, confidence score, and recommendations.
    """
    if df is None or df.empty:
        return {
            "level": "none",
            "days": 0,
            "confidence_score": 0,
            "confidence_label": "No Data",
            "color": "red",
            "message": "No usage data available. Deploy monitoring and wait for data collection.",
            "ready_for_projection": False,
            "recommendations": ["Deploy monitoring views", "Wait for initial data collection (3+ days)"]
        }

    days_of_data = len(df['DATE'].unique())

    # Check for data gaps (missing days)
    if days_of_data > 1:
        date_range = (df['DATE'].max() - df['DATE'].min()).days + 1
        data_completeness = days_of_data / date_range if date_range > 0 else 0
    else:
        data_completeness = 1.0

    # Calculate confidence score (0-100)
    day_score = min(days_of_data / DATA_MATURITY_THRESHOLDS["confident"], 1.0) * 60
    completeness_score = data_completeness * 40
    confidence_score = int(day_score + completeness_score)

    # Determine maturity level
    if days_of_data < DATA_MATURITY_THRESHOLDS["minimum"]:
        return {
            "level": "insufficient",
            "days": days_of_data,
            "confidence_score": confidence_score,
            "confidence_label": "Insufficient",
            "color": "red",
            "message": f"Only {days_of_data} day(s) of data. Need at least {DATA_MATURITY_THRESHOLDS['minimum']} days for basic projections.",
            "ready_for_projection": False,
            "recommendations": [
                f"Wait {DATA_MATURITY_THRESHOLDS['minimum'] - days_of_data} more days for minimum data",
                "Use published Snowflake rates for initial estimates"
            ]
        }
    elif days_of_data < DATA_MATURITY_THRESHOLDS["developing"]:
        return {
            "level": "developing",
            "days": days_of_data,
            "confidence_score": confidence_score,
            "confidence_label": "Developing",
            "color": "orange",
            "message": f"{days_of_data} days of data. Projections are rough estimates.",
            "ready_for_projection": True,
            "recommendations": [
                f"Wait for {DATA_MATURITY_THRESHOLDS['reliable']} days for more reliable projections",
                "Use wider variance ranges (+/- 25%)",
                "Cross-check with published Snowflake rates"
            ]
        }
    elif days_of_data < DATA_MATURITY_THRESHOLDS["reliable"]:
        return {
            "level": "developing",
            "days": days_of_data,
            "confidence_score": confidence_score,
            "confidence_label": "Improving",
            "color": "yellow",
            "message": f"{days_of_data} days of data. Projections improving in reliability.",
            "ready_for_projection": True,
            "recommendations": [
                f"Wait for {DATA_MATURITY_THRESHOLDS['reliable']} days for reliable projections",
                "Consider +/- 15-20% variance ranges"
            ]
        }
    elif days_of_data < DATA_MATURITY_THRESHOLDS["confident"]:
        return {
            "level": "reliable",
            "days": days_of_data,
            "confidence_score": confidence_score,
            "confidence_label": "Reliable",
            "color": "lightgreen",
            "message": f"{days_of_data} days of data. Projections are statistically meaningful.",
            "ready_for_projection": True,
            "recommendations": [
                "Projections are suitable for budget planning",
                "Standard variance range (+/- 10%) is appropriate"
            ]
        }
    else:
        return {
            "level": "confident",
            "days": days_of_data,
            "confidence_score": confidence_score,
            "confidence_label": "High Confidence",
            "color": "green",
            "message": f"{days_of_data} days of data. High confidence in projections.",
            "ready_for_projection": True,
            "recommendations": [
                "Data is mature for accurate forecasting",
                "Consider tighter variance ranges if usage is stable"
            ]
        }

def calculate_confidence_interval(base_value, confidence_score, custom_variance=None):
    """
    Calculate confidence intervals based on data maturity.
    Returns (lower_bound, upper_bound, variance_pct)
    """
    if custom_variance is not None:
        variance_pct = custom_variance
    else:
        # Higher confidence = tighter intervals
        # confidence_score 0-100 maps to variance 30%-5%
        variance_pct = max(0.05, 0.30 - (confidence_score / 100) * 0.25)

    lower = base_value * (1 - variance_pct)
    upper = base_value * (1 + variance_pct)

    return lower, upper, variance_pct

def calculate_poc_to_prod_projection(current_monthly_cost, current_users, multiplier_key, custom_user_mult=None, custom_usage_mult=None):
    """
    Calculate POC to Production cost projection.
    """
    if multiplier_key == "Custom":
        user_mult = custom_user_mult or 1
        usage_mult = custom_usage_mult or 1
    else:
        user_mult = POC_TO_PROD_MULTIPLIERS[multiplier_key]["user_mult"]
        usage_mult = POC_TO_PROD_MULTIPLIERS[multiplier_key]["usage_mult"]

    projected_users = current_users * user_mult
    projected_monthly_cost = current_monthly_cost * user_mult * usage_mult

    return {
        "current_users": current_users,
        "projected_users": projected_users,
        "user_multiplier": user_mult,
        "usage_multiplier": usage_mult,
        "current_monthly_cost": current_monthly_cost,
        "projected_monthly_cost": projected_monthly_cost,
        "projected_annual_cost": projected_monthly_cost * 12,
        "cost_per_user": projected_monthly_cost / projected_users if projected_users > 0 else 0
    }

def generate_proposal_text(df, credit_cost, maturity, projections, assumptions):
    """
    Generate a formatted text summary for proposals/stakeholder communication.
    """
    lines = []
    lines.append("=" * 60)
    lines.append("CORTEX COST ESTIMATE - EXECUTIVE SUMMARY")
    lines.append("=" * 60)
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append(f"Data Confidence: {maturity['confidence_label']} ({maturity['confidence_score']}%)")
    lines.append("")

    lines.append("CURRENT STATE (Based on observed usage)")
    lines.append("-" * 40)
    lines.append(f"  Analysis Period: {maturity['days']} days")
    lines.append(f"  Monthly Run Rate: {format_currency(projections['current_monthly'])}")
    lines.append(f"  Avg Daily Users: {projections['avg_users']:.0f}")
    lines.append("")

    lines.append("PROJECTED COSTS")
    lines.append("-" * 40)
    lines.append(f"  Monthly Estimate: {format_currency(projections['projected_monthly'])}")
    lines.append(f"  Annual Estimate: {format_currency(projections['projected_annual'])}")
    lines.append(f"  Confidence Range: {format_currency(projections['lower_bound'])} - {format_currency(projections['upper_bound'])}")
    lines.append("")

    lines.append("ASSUMPTIONS")
    lines.append("-" * 40)
    for assumption in assumptions:
        lines.append(f"  - {assumption}")
    lines.append("")

    lines.append("COST BREAKDOWN BY SERVICE")
    lines.append("-" * 40)
    if 'service_breakdown' in projections:
        for service, cost in projections['service_breakdown'].items():
            pct = (cost / projections['projected_monthly'] * 100) if projections['projected_monthly'] > 0 else 0
            lines.append(f"  {service}: {format_currency(cost)} ({pct:.1f}%)")
    lines.append("")

    lines.append("=" * 60)
    lines.append("Note: Estimates based on POC/trial usage patterns.")
    lines.append("Actual production costs may vary based on adoption and usage intensity.")
    lines.append("=" * 60)

    return "\n".join(lines)

# ============================================================================
# Main Application
# ============================================================================

def load_data_from_csv(uploaded_file):
    """Load and validate data from uploaded CSV file"""
    try:
        df = pd.read_csv(uploaded_file)

        # Expected columns from sql/02_utilities/export_metrics.sql (Option 1/2)
        required_cols = ['DATE', 'SERVICE_TYPE', 'DAILY_UNIQUE_USERS', 'TOTAL_OPERATIONS', 'TOTAL_CREDITS']
        missing_cols = [col for col in required_cols if col not in df.columns]

        if missing_cols:
            st.error(f"CSV missing required columns: {', '.join(missing_cols)}")
            st.info(f"**Expected columns:** {', '.join(required_cols)}")
            st.info("**Source query:** Use `sql/02_utilities/export_metrics.sql` to generate the correct CSV format")
            return None

        # Standardize column names (handle case variations)
        df.columns = df.columns.str.upper()

        # Validate row count
        if len(df) == 0:
            st.error("CSV file is empty. No data rows found.")
            return None

        if len(df) > 100000:
            st.warning(f"Large file detected ({len(df):,} rows). Processing may be slow. Consider filtering the date range.")

        # Convert and validate date column
        try:
            df['DATE'] = pd.to_datetime(df['DATE'])
        except Exception as date_err:
            st.error(f"Invalid date format in DATE column: {str(date_err)}")
            st.info("**Expected format:** YYYY-MM-DD (e.g., 2025-01-05)")
            return None

        # Validate date range
        min_date = df['DATE'].min()
        max_date = df['DATE'].max()
        date_range_days = (max_date - min_date).days

        if date_range_days < 0:
            st.error("Invalid date range: end date is before start date")
            return None

        if date_range_days > 730:  # 2 years
            st.warning(f"Date range spans {date_range_days} days (> 2 years). This may impact performance.")

        # Validate TOTAL_CREDITS column
        if not pd.api.types.is_numeric_dtype(df['TOTAL_CREDITS']):
            st.error("TOTAL_CREDITS column must contain numeric values")
            return None

        # Check for negative credits
        negative_credits = df[df['TOTAL_CREDITS'] < 0]
        if len(negative_credits) > 0:
            st.error(f"Found {len(negative_credits)} rows with negative credits. Credits must be >= 0")
            st.dataframe(negative_credits.head())
            return None

        # Check for null credits
        null_credits = df[df['TOTAL_CREDITS'].isna()]
        if len(null_credits) > 0:
            st.warning(f"Found {len(null_credits)} rows with NULL credits. These will be excluded from calculations.")
            df = df[df['TOTAL_CREDITS'].notna()]

        # Validate SERVICE_TYPE values
        known_services = [
            'Cortex Analyst',
            'Cortex Search',
            'Cortex Functions',
            'Cortex Document Processing',
            'Cortex Fine-tuning',
            'Cortex REST API',
        ]
        unknown_services = set(df['SERVICE_TYPE'].unique()) - set(known_services)
        if unknown_services:
            st.info(f"Found unknown service types: {', '.join(unknown_services)}. These will be included in analysis.")

        # Success message
        st.success(
            f"CSV loaded successfully: {len(df):,} rows from {min_date.strftime('%Y-%m-%d')} to "
            f"{max_date.strftime('%Y-%m-%d')} ({date_range_days} days)"
        )

        return df

    except pd.errors.EmptyDataError:
        st.error("CSV file is empty or corrupted")
        return None
    except pd.errors.ParserError as parse_err:
        st.error(f"CSV parsing error: {str(parse_err)}")
        st.info("**Check:** Ensure file is valid CSV format with proper delimiters")
        return None
    except Exception as e:
        st.error(f"Error loading CSV: {str(e)}")
        st.info("**Troubleshooting:** Verify file format matches export query output")
        return None

def create_credit_summary(df, credit_cost=3.00):
    """Create credit estimate summary for sales team"""
    summary = df.groupby('SERVICE_TYPE').agg({
        'TOTAL_CREDITS': 'sum',
        'DAILY_UNIQUE_USERS': 'mean',
        'DATE': ['min', 'max']
    }).reset_index()

    summary.columns = ['Service', 'Total Credits', 'Avg Daily Users', 'Start Date', 'End Date']
    summary['Days of Data'] = (summary['End Date'] - summary['Start Date']).dt.days + 1
    summary['Avg Credits/Day'] = summary['Total Credits'] / summary['Days of Data']
    summary['Est. Credits/Month'] = summary['Avg Credits/Day'] * 30
    summary['Est. Cost/Month'] = summary['Est. Credits/Month'] * credit_cost

    return summary[['Service', 'Total Credits', 'Avg Credits/Day', 'Est. Credits/Month', 'Est. Cost/Month']]

def main():
    st.title("Cortex Cost Calculator")
    st.markdown("""
    **Get confident in your Cortex cost projections.** Pop in, get the metrics you need, take action.
    """)

    # Sidebar configuration
    with st.sidebar:
        st.header("Configuration")

        # Quick guidance
        st.info("""
        **Quick Start:**
        1. Load your data (query or CSV)
        2. Check Executive Summary
        3. Use POC→Production for scaling
        4. Export proposal when ready
        """)

        st.divider()

        # Cache management section
        st.markdown("### Data Freshness")
        if st.button("Refresh Data", help="Clear cache and reload data from source"):
            st.cache_data.clear()
            st.success("Cache cleared. Data will be refreshed on next load.")
            st.rerun()

        # Show last updated time
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        st.caption(f"**Last Refreshed:** {current_time}")
        st.caption("**Cache TTL:** 5 minutes (automatic refresh)")

        st.divider()

        # Data source selection
        data_source = st.radio(
            "Data Source",
            options=["Query Views (Same Account)", "Upload Customer CSV"],
            help="Query views for your own data, or upload CSV from customer account"
        )

        uploaded_file = None
        if data_source == "Query Views (Same Account)":
            lookback_days = st.slider(
                "Historical Data Period (days)",
                min_value=7,
                max_value=90,
                value=30,
                help="Number of days of historical data to analyze"
            )
        else:
            st.markdown("### Upload Customer Data")
            uploaded_file = st.file_uploader(
                "Upload CSV from sql/02_utilities/export_metrics.sql",
                type=['csv'],
                help="CSV file exported from customer's Snowflake account"
            )
        st.caption("Data is cached for 5 minutes to improve performance. Use 'Refresh Data' to force reload.")

        st.divider()

        credit_cost = st.number_input(
            "Cost per Credit (USD)",
            value=3.00,
            min_value=0.01,
            step=0.10,
            help="Adjust based on your Snowflake pricing"
        )

        variance_pct = st.slider(
            "Projection Variance (%)",
            min_value=5,
            max_value=25,
            value=10,
            help="Variance range for cost estimates"
        ) / 100

        # "Refresh Data" is handled above (also reruns the app).

    # Load data based on source
    df = None
    if data_source == "Query Views (Same Account)":
        try:
            with st.spinner("Loading data from views..."):
                df = fetch_data_from_views(lookback_days)
        except Exception as e:
            st.error(f"Error querying views: {str(e)}")
            st.info("Make sure monitoring views are deployed in SNOWFLAKE_EXAMPLE.CORTEX_USAGE")
            return
    else:
        if 'uploaded_file' in locals() and uploaded_file is not None:
            with st.spinner("Loading CSV file..."):
                df = load_data_from_csv(uploaded_file)
        else:
            st.info("Please upload a CSV file from the customer's account.")
            st.markdown("""
            **To get customer data:**
            1. Run `@sql/02_utilities/export_metrics.sql` in customer's Snowflake
            2. Download results as CSV
            3. Upload here
            """)
            return

    if df is None or df.empty:
        st.warning("No data available. Please check your data source.")
        return

    # Normalize column names
    df.columns = df.columns.str.upper()
    if 'DATE' not in df.columns:
        df['DATE'] = pd.to_datetime(df['USAGE_DATE']) if 'USAGE_DATE' in df.columns else pd.to_datetime(df.iloc[:, 0])

    # Create tabs (Decision Support first, then detailed analysis)
    tab_summary, tab_scaling, tab_forecast, tab_user, tab_hist, tab_aisql, tab_proj, tab_export = st.tabs([
        "Executive Summary",
        "POC → Production",
        "12-Month Forecast",
        "User Attribution",
        "Historical Analysis",
        "AISQL Functions",
        "Cost Projections",
        "Export & Proposal"
    ])

    with tab_summary:
        show_executive_summary(df, credit_cost, variance_pct, data_source)

    with tab_scaling:
        show_poc_to_production(df, credit_cost)

    with tab_forecast:
        show_12_month_forecast(data_source=data_source, credit_cost=credit_cost, df=df)

    with tab_user:
        show_user_spend_attribution(data_source=data_source, lookback_days=lookback_days if data_source == "Query Views (Same Account)" else None, credit_cost=credit_cost)

    with tab_hist:
        show_historical_analysis(df, credit_cost)

    with tab_aisql:
        show_aisql_functions(credit_cost)

    with tab_proj:
        show_cost_projections(df, credit_cost, variance_pct)

    with tab_export:
        show_export_proposal(df, credit_cost, variance_pct)

# ============================================================================
# Executive Summary - Decision Support Dashboard
# ============================================================================

def show_executive_summary(df, credit_cost, variance_pct, data_source):
    """
    Primary landing page: Quick confidence snapshot for decision-makers.
    Answers: What will this cost at scale? Can I trust these numbers?
    """
    st.header("Executive Summary")
    st.caption("Get confident in your Cortex cost projections - no clicking required")

    # Assess data maturity
    maturity = assess_data_maturity(df)

    # ========================================================================
    # Data Readiness Indicator (Am I Ready?)
    # ========================================================================
    col_ready, col_spacer = st.columns([3, 1])

    with col_ready:
        # Create a visual confidence gauge
        confidence_color = maturity['color']
        st.markdown(f"""
        <div style="background: linear-gradient(90deg, {confidence_color} {maturity['confidence_score']}%, #333 {maturity['confidence_score']}%);
                    border-radius: 10px; padding: 15px; margin-bottom: 20px;">
            <h3 style="margin: 0; color: white;">Data Readiness: {maturity['confidence_label']}</h3>
            <p style="margin: 5px 0 0 0; color: white; opacity: 0.9;">{maturity['message']}</p>
        </div>
        """, unsafe_allow_html=True)

    # ========================================================================
    # Key Decision Metrics - Single Screen Snapshot
    # ========================================================================
    st.subheader("Confidence Snapshot")

    # Calculate key metrics
    total_credits = df['TOTAL_CREDITS'].sum()
    days_of_data = maturity['days']

    # Daily and monthly run rates
    avg_daily_credits = total_credits / days_of_data if days_of_data > 0 else 0
    monthly_run_rate = avg_daily_credits * 30
    annual_run_rate = monthly_run_rate * 12

    # User metrics
    avg_daily_users = df['DAILY_UNIQUE_USERS'].mean() if 'DAILY_UNIQUE_USERS' in df.columns else 0
    cost_per_user_month = (monthly_run_rate * credit_cost) / avg_daily_users if avg_daily_users > 0 else 0

    # Calculate confidence intervals
    monthly_cost = monthly_run_rate * credit_cost
    annual_cost = annual_run_rate * credit_cost
    lower_annual, upper_annual, actual_variance = calculate_confidence_interval(annual_cost, maturity['confidence_score'])

    # Top cost drivers
    service_costs = df.groupby('SERVICE_TYPE')['TOTAL_CREDITS'].sum().sort_values(ascending=False)
    top_3_services = service_costs.head(3)

    # Display key metrics
    col1, col2, col3 = st.columns(3)

    with col1:
        st.metric(
            "Monthly Run Rate",
            format_currency(monthly_cost),
            help="Current monthly cost based on observed daily average"
        )
        st.metric(
            "Annual Projection",
            format_currency(annual_cost),
            help="Projected annual cost at current run rate"
        )

    with col2:
        st.metric(
            "Confidence Range (Annual)",
            f"{format_currency(lower_annual)} - {format_currency(upper_annual)}",
            help=f"Based on {maturity['confidence_score']}% data confidence (+/- {actual_variance*100:.0f}%)"
        )
        st.metric(
            "Cost per User/Month",
            format_currency(cost_per_user_month),
            help="Average cost per active user per month"
        )

    with col3:
        st.metric(
            "Active Users (Avg)",
            f"{avg_daily_users:.1f}",
            help="Average daily unique users"
        )
        st.metric(
            "Days of Data",
            f"{days_of_data}",
            help=f"Need {DATA_MATURITY_THRESHOLDS['reliable']}+ days for reliable projections"
        )

    st.divider()

    # ========================================================================
    # Top Cost Drivers
    # ========================================================================
    st.subheader("Top Cost Drivers")

    col1, col2 = st.columns([2, 1])

    with col1:
        cost_driver_data = []
        total_cost = service_costs.sum() * credit_cost
        for service, credits in top_3_services.items():
            cost = credits * credit_cost
            pct = (credits / service_costs.sum() * 100) if service_costs.sum() > 0 else 0
            cost_driver_data.append({
                "Service": service,
                "Monthly Cost": format_currency(cost / days_of_data * 30) if days_of_data > 0 else "$0",
                "% of Total": f"{pct:.1f}%",
                "Trend": "→"  # Could be enhanced with actual trend data
            })

        if cost_driver_data:
            st.dataframe(
                pd.DataFrame(cost_driver_data),
                use_container_width=True,
                hide_index=True
            )

    with col2:
        # Mini pie chart
        if not service_costs.empty:
            fig = px.pie(
                values=service_costs.values,
                names=service_costs.index,
                hole=0.4
            )
            fig.update_layout(
                showlegend=False,
                margin=dict(l=0, r=0, t=0, b=0),
                height=200
            )
            fig.update_traces(textposition='inside', textinfo='percent')
            st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # ========================================================================
    # Quick Recommendations
    # ========================================================================
    st.subheader("Recommendations")

    for rec in maturity['recommendations']:
        st.markdown(f"- {rec}")

    # Add contextual advice based on data state
    if maturity['level'] in ['confident', 'reliable']:
        st.success("Your data is ready for budget planning. Proceed to 'POC → Production' tab for scaling estimates.")
    elif maturity['level'] == 'developing':
        st.warning("Consider using wider variance ranges (+/- 20-25%) until you have 14+ days of data.")
    else:
        st.error("Collect more data before making budget commitments. Use published Snowflake rates for initial planning.")

    # ========================================================================
    # Assumptions Statement (Always visible)
    # ========================================================================
    with st.expander("Assumptions & Methodology", expanded=False):
        st.markdown(f"""
        **This estimate assumes:**
        - Current usage patterns continue at observed rates
        - {avg_daily_users:.0f} average daily active users
        - Credit cost of ${credit_cost:.2f} per credit
        - Variance range based on {days_of_data} days of data ({actual_variance*100:.0f}%)

        **Data Sources:**
        - {"Live monitoring views" if data_source == "Query Views (Same Account)" else "Uploaded CSV file"}
        - SNOWFLAKE.ACCOUNT_USAGE telemetry

        **Limitations:**
        - Projections are estimates based on historical patterns
        - POC usage may not reflect production intensity
        - Some services (e.g., REST API calls) have limited attribution
        """)


def show_poc_to_production(df, credit_cost):
    """
    POC to Production scaling calculator with built-in multipliers.
    Helps users answer: "If we scale from POC to production, what should we budget?"
    """
    st.header("POC → Production Scaling")
    st.caption("Estimate production costs based on your POC/trial data")

    # Assess data maturity
    maturity = assess_data_maturity(df)

    if not maturity['ready_for_projection']:
        st.warning(maturity['message'])
        st.info("You need at least 3 days of data to use this calculator. Use the 'Cost Projections' tab with published Snowflake rates instead.")
        return

    # Calculate current state from data
    days_of_data = maturity['days']
    total_credits = df['TOTAL_CREDITS'].sum()
    avg_daily_credits = total_credits / days_of_data if days_of_data > 0 else 0
    current_monthly_cost = avg_daily_credits * 30 * credit_cost
    current_users = df['DAILY_UNIQUE_USERS'].mean() if 'DAILY_UNIQUE_USERS' in df.columns else 1

    st.subheader("Your Current POC State")

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Current Monthly Run Rate", format_currency(current_monthly_cost))
    with col2:
        st.metric("Current Users (Avg Daily)", f"{current_users:.1f}")
    with col3:
        cost_per_user = current_monthly_cost / current_users if current_users > 0 else 0
        st.metric("Cost per User/Month", format_currency(cost_per_user))

    st.divider()

    # ========================================================================
    # Scaling Scenario Selection
    # ========================================================================
    st.subheader("Select Scaling Scenario")

    scenario = st.selectbox(
        "How does your POC compare to expected production?",
        options=list(POC_TO_PROD_MULTIPLIERS.keys()),
        help="Select the scenario that best matches your POC characteristics"
    )

    # Show scenario description
    st.info(POC_TO_PROD_MULTIPLIERS[scenario]['description'])

    # Custom multipliers if selected
    custom_user_mult = None
    custom_usage_mult = None

    if scenario == "Custom":
        col1, col2 = st.columns(2)
        with col1:
            custom_user_mult = st.number_input(
                "User Multiplier",
                min_value=1.0,
                max_value=100.0,
                value=10.0,
                step=1.0,
                help="How many times more users in production vs POC?"
            )
        with col2:
            custom_usage_mult = st.number_input(
                "Usage Intensity Multiplier",
                min_value=0.5,
                max_value=5.0,
                value=1.0,
                step=0.1,
                help="How much more/less intensive will production usage be per user?"
            )

    # Calculate projection
    projection = calculate_poc_to_prod_projection(
        current_monthly_cost,
        current_users,
        scenario,
        custom_user_mult,
        custom_usage_mult
    )

    # Calculate confidence intervals
    lower_monthly, upper_monthly, variance = calculate_confidence_interval(
        projection['projected_monthly_cost'],
        maturity['confidence_score']
    )
    lower_annual, upper_annual, _ = calculate_confidence_interval(
        projection['projected_annual_cost'],
        maturity['confidence_score']
    )

    st.divider()

    # ========================================================================
    # Production Projection Results
    # ========================================================================
    st.subheader("Production Cost Projection")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.metric(
            "Projected Users",
            f"{projection['projected_users']:.0f}",
            delta=f"{projection['user_multiplier']}x from POC"
        )

    with col2:
        st.metric(
            "Projected Monthly Cost",
            format_currency(projection['projected_monthly_cost']),
            delta=f"{projection['user_multiplier'] * projection['usage_multiplier']:.1f}x from POC"
        )

    with col3:
        st.metric(
            "Projected Annual Cost",
            format_currency(projection['projected_annual_cost'])
        )

    # Confidence range display
    st.markdown(f"""
    **Confidence Range (based on {maturity['confidence_score']}% data confidence):**
    - Monthly: {format_currency(lower_monthly)} - {format_currency(upper_monthly)}
    - Annual: {format_currency(lower_annual)} - {format_currency(upper_annual)}
    """)

    st.divider()

    # ========================================================================
    # Side-by-Side Scenario Comparison
    # ========================================================================
    st.subheader("Compare All Scenarios")

    comparison_data = []
    for name, mult in POC_TO_PROD_MULTIPLIERS.items():
        if name == "Custom":
            continue
        proj = calculate_poc_to_prod_projection(current_monthly_cost, current_users, name)
        comparison_data.append({
            "Scenario": name.split(" (")[0],  # Shorten name
            "Users": f"{proj['projected_users']:.1f}",
            "Monthly": format_currency(proj['projected_monthly_cost']),
            "Annual": format_currency(proj['projected_annual_cost']),
            "Cost/User": format_currency(proj['cost_per_user'])
        })

    st.dataframe(
        pd.DataFrame(comparison_data),
        use_container_width=True,
        hide_index=True
    )

    # ========================================================================
    # Budget Recommendation
    # ========================================================================
    st.divider()
    st.subheader("Budget Recommendation")

    # Recommend budget with safety buffer
    safety_buffer = 1.15  # 15% safety margin
    recommended_annual = upper_annual * safety_buffer

    col1, col2 = st.columns(2)

    with col1:
        st.metric(
            "Recommended Annual Budget",
            format_currency(recommended_annual),
            help="Upper confidence bound + 15% safety buffer"
        )

    with col2:
        st.metric(
            "Recommended Monthly Budget",
            format_currency(recommended_annual / 12)
        )

    st.info(f"""
    **Budget Justification:**
    - Base projection: {format_currency(projection['projected_annual_cost'])}/year
    - Confidence range upper bound: {format_currency(upper_annual)} (+{variance*100:.0f}% variance)
    - Safety buffer: +15% for unexpected growth
    - **Recommended budget: {format_currency(recommended_annual)}**
    """)

    # ========================================================================
    # Assumptions (collapsible)
    # ========================================================================
    with st.expander("Assumptions & Methodology", expanded=False):
        st.markdown(f"""
        **Scaling Assumptions:**
        - POC baseline: {current_users:.0f} users, {format_currency(current_monthly_cost)}/month
        - Scenario: {scenario}
        - User multiplier: {projection['user_multiplier']}x
        - Usage intensity multiplier: {projection['usage_multiplier']}x

        **Confidence Calculation:**
        - Data maturity: {maturity['confidence_label']} ({maturity['days']} days)
        - Confidence score: {maturity['confidence_score']}%
        - Applied variance: +/- {variance*100:.0f}%

        **Important Caveats:**
        - POC users often explore more than production users (accounted for in usage multiplier)
        - Production may have different usage patterns (spikes, automation)
        - New services/features may be adopted post-launch
        """)


def show_export_proposal(df, credit_cost, variance_pct):
    """
    Generate shareable proposal/summary for stakeholders.
    One-click export to text, CSV, or formatted summary.
    """
    st.header("Export & Proposal Generator")
    st.caption("Generate stakeholder-ready summaries and export data")

    # Assess data maturity
    maturity = assess_data_maturity(df)

    # Calculate projections for export
    days_of_data = maturity['days']
    total_credits = df['TOTAL_CREDITS'].sum()
    avg_daily_credits = total_credits / days_of_data if days_of_data > 0 else 0
    monthly_cost = avg_daily_credits * 30 * credit_cost
    annual_cost = monthly_cost * 12
    avg_users = df['DAILY_UNIQUE_USERS'].mean() if 'DAILY_UNIQUE_USERS' in df.columns else 0

    lower, upper, variance = calculate_confidence_interval(annual_cost, maturity['confidence_score'])

    # Service breakdown
    service_breakdown = {}
    for service, credits in df.groupby('SERVICE_TYPE')['TOTAL_CREDITS'].sum().items():
        service_breakdown[service] = (credits / days_of_data * 30 * credit_cost) if days_of_data > 0 else 0

    projections = {
        'current_monthly': monthly_cost,
        'projected_monthly': monthly_cost,
        'projected_annual': annual_cost,
        'lower_bound': lower,
        'upper_bound': upper,
        'avg_users': avg_users,
        'service_breakdown': service_breakdown
    }

    assumptions = [
        f"Based on {days_of_data} days of observed usage data",
        f"Average of {avg_users:.1f} daily active users",
        f"Credit cost: ${credit_cost:.2f}/credit",
        f"Variance range: +/- {variance*100:.0f}% (based on data maturity)",
        "Assumes current usage patterns continue"
    ]

    # ========================================================================
    # Quick Summary Preview
    # ========================================================================
    st.subheader("Proposal Preview")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.metric("Monthly Estimate", format_currency(monthly_cost))
    with col2:
        st.metric("Annual Estimate", format_currency(annual_cost))
    with col3:
        st.metric("Confidence Range", f"{format_currency(lower)} - {format_currency(upper)}")

    st.divider()

    # ========================================================================
    # One-Click Proposal Generation
    # ========================================================================
    st.subheader("Generate Proposal")

    proposal_text = generate_proposal_text(df, credit_cost, maturity, projections, assumptions)

    # Display preview
    with st.expander("Preview Proposal Text", expanded=True):
        st.code(proposal_text, language=None)

    # Download buttons
    col1, col2, col3 = st.columns(3)

    with col1:
        st.download_button(
            label="Download Proposal (TXT)",
            data=proposal_text,
            file_name=f"cortex_cost_proposal_{datetime.now().strftime('%Y%m%d')}.txt",
            mime="text/plain",
            use_container_width=True
        )

    with col2:
        # Generate CSV summary
        summary_csv_data = {
            'Metric': [
                'Analysis Period (days)',
                'Monthly Cost Estimate',
                'Annual Cost Estimate',
                'Lower Bound (Annual)',
                'Upper Bound (Annual)',
                'Average Daily Users',
                'Cost per User/Month',
                'Data Confidence'
            ],
            'Value': [
                days_of_data,
                f"${monthly_cost:,.2f}",
                f"${annual_cost:,.2f}",
                f"${lower:,.2f}",
                f"${upper:,.2f}",
                f"{avg_users:.0f}",
                f"${monthly_cost/avg_users if avg_users > 0 else 0:,.2f}",
                f"{maturity['confidence_label']} ({maturity['confidence_score']}%)"
            ]
        }
        summary_df = pd.DataFrame(summary_csv_data)

        st.download_button(
            label="Download Summary (CSV)",
            data=summary_df.to_csv(index=False),
            file_name=f"cortex_cost_summary_{datetime.now().strftime('%Y%m%d')}.csv",
            mime="text/csv",
            use_container_width=True
        )

    with col3:
        # Full raw data export
        st.download_button(
            label="Download Raw Data (CSV)",
            data=df.to_csv(index=False),
            file_name=f"cortex_usage_data_{datetime.now().strftime('%Y%m%d')}.csv",
            mime="text/csv",
            use_container_width=True
        )

    st.divider()

    # ========================================================================
    # Service Breakdown Table
    # ========================================================================
    st.subheader("Detailed Service Breakdown")

    service_table = []
    for service, monthly_cost_svc in service_breakdown.items():
        annual_cost_svc = monthly_cost_svc * 12
        pct = (monthly_cost_svc / monthly_cost * 100) if monthly_cost > 0 else 0
        service_table.append({
            'Service': service,
            'Monthly Cost': format_currency(monthly_cost_svc),
            'Annual Cost': format_currency(annual_cost_svc),
            '% of Total': f"{pct:.1f}%"
        })

    st.dataframe(
        pd.DataFrame(service_table),
        use_container_width=True,
        hide_index=True
    )

    # ========================================================================
    # Copy-Paste Summary for Emails/Slack
    # ========================================================================
    st.subheader("Quick Copy Summary")

    quick_summary = f"""Cortex Cost Estimate ({datetime.now().strftime('%Y-%m-%d')})
• Monthly: {format_currency(monthly_cost)}
• Annual: {format_currency(annual_cost)} (range: {format_currency(lower)} - {format_currency(upper)})
• Based on {days_of_data} days of data, {avg_users:.0f} avg users
• Confidence: {maturity['confidence_label']}"""

    st.code(quick_summary, language=None)
    st.caption("Copy the above text for quick sharing via email or Slack")

def show_user_spend_attribution(data_source, lookback_days, credit_cost):
    """Primary view: who is driving spend, and with which features/models."""
    st.header("User Spend Attribution")

    if data_source != "Query Views (Same Account)":
        st.info("User attribution is available only when querying the monitoring views in the same account (it relies on ACCOUNT_USAGE + QUERY_HISTORY).")
        return

    if lookback_days is None:
        lookback_days = 30

    try:
        with st.spinner("Loading user attribution data..."):
            udf = fetch_user_spend_attribution(lookback_days)
    except Exception as e:
        st.error(f"Error loading user attribution views: {str(e)}")
        st.info("Make sure monitoring views v3.1+ are deployed (V_USER_SPEND_ATTRIBUTION).")
        return

    if udf is None or udf.empty:
        st.warning("No attributable user-level data found in the selected period.")
        st.caption("Note: some services (e.g., Cortex Search) cannot be attributed to users due to platform limitations.")
        return

    udf.columns = udf.columns.str.upper()
    udf["COST_USD"] = udf["CREDITS_USED"] * credit_cost

    total_credits = float(udf["CREDITS_USED"].sum())
    total_cost = float(udf["COST_USD"].sum())
    unique_users = int(udf["USER_NAME"].nunique())

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Total Credits (Attributed)", format_number(total_credits))
    with col2:
        st.metric("Total Cost (Attributed)", format_currency(total_cost))
    with col3:
        st.metric("Users (Attributed)", f"{unique_users:.0f}")

    st.divider()

    st.subheader("Top Users by Spend")
    top_users = (
        udf.groupby("USER_NAME", as_index=False)[["CREDITS_USED", "COST_USD"]]
        .sum()
        .sort_values("CREDITS_USED", ascending=False)
        .head(15)
    )

    fig_users = px.bar(
        top_users,
        x="USER_NAME",
        y="CREDITS_USED",
        title="Top users by credits consumed (attributed)",
        labels={"USER_NAME": "User", "CREDITS_USED": "Credits"},
    )
    fig_users.update_layout(xaxis_tickangle=-45)
    st.plotly_chart(fig_users, use_container_width=True)

    st.dataframe(
        top_users.style.format({"CREDITS_USED": "{:,.4f}", "COST_USD": "${:,.2f}"}),
        use_container_width=True,
        hide_index=True,
    )

    st.divider()

    st.subheader("What Features Are Driving Spend?")
    sunburst_df = (
        udf.groupby(["USER_NAME", "SERVICE_TYPE", "FEATURE_NAME", "MODEL_NAME"], as_index=False)["CREDITS_USED"]
        .sum()
        .sort_values("CREDITS_USED", ascending=False)
    )

    # Plotly sunburst struggles with NULL labels; normalize for visualization.
    sunburst_df["MODEL_NAME"] = sunburst_df["MODEL_NAME"].fillna("(none)")

    fig_sb = px.sunburst(
        sunburst_df,
        path=["USER_NAME", "SERVICE_TYPE", "FEATURE_NAME", "MODEL_NAME"],
        values="CREDITS_USED",
        title="User -> service -> feature -> model (credits)",
    )
    st.plotly_chart(fig_sb, use_container_width=True)

    st.divider()

    st.subheader("Drill-down: User Details")
    user_options = [u for u in udf["USER_NAME"].unique() if u is not None]
    selected_user = st.selectbox("Select a user", options=sorted(user_options))
    user_df = udf[udf["USER_NAME"] == selected_user].copy()
    user_breakdown = (
        user_df.groupby(["SERVICE_TYPE", "FEATURE_NAME", "MODEL_NAME"], as_index=False)[["CREDITS_USED", "COST_USD"]]
        .sum()
        .sort_values("CREDITS_USED", ascending=False)
    )
    user_breakdown["MODEL_NAME"] = user_breakdown["MODEL_NAME"].fillna("(none)")

    st.dataframe(
        user_breakdown.style.format({"CREDITS_USED": "{:,.4f}", "COST_USD": "${:,.2f}"}),
        use_container_width=True,
        hide_index=True,
    )

def show_12_month_forecast(data_source, credit_cost, df):
    """Primary view: forecast current usage out 12 months (ML.FORECAST when available)."""
    st.header("12-Month Forecast")

    projection_months = st.slider(
        "Projection period (months)",
        min_value=3,
        max_value=24,
        value=12,
        help="Uses ML.FORECAST when available; otherwise falls back to a simple statistical projection.",
    )
    projection_days = int(projection_months * 30.5)

    # ------------------------------------------------------------------------
    # Preferred path: ML forecast from Snowflake (same-account deployments)
    # ------------------------------------------------------------------------
    if data_source == "Query Views (Same Account)":
        try:
            with st.spinner("Loading ML forecast..."):
                fdf = fetch_ml_forecast_12m()
        except Exception as e:
            fdf = pd.DataFrame()
            st.warning(f"Unable to query ML forecast view: {str(e)}")

        if fdf is not None and not fdf.empty:
            fdf.columns = fdf.columns.str.upper()
            fdf["FORECAST_DATE"] = pd.to_datetime(fdf["FORECAST_DATE"])

            # Filter to requested horizon from first forecast date
            start_date = fdf["FORECAST_DATE"].min()
            end_date = start_date + pd.Timedelta(days=projection_days)
            fdf = fdf[(fdf["FORECAST_DATE"] >= start_date) & (fdf["FORECAST_DATE"] < end_date)].copy()

            if fdf.empty:
                st.warning("ML forecast returned no rows for the selected horizon.")
            else:
                st.caption("Forecast produced by Snowflake ML forecasting (`SNOWFLAKE.ML.FORECAST`).")

                # Monthly rollup (credits + bounds)
                fdf["MONTH"] = fdf["FORECAST_DATE"].dt.to_period("M").dt.to_timestamp()

                monthly = (
                    fdf.groupby(["MONTH", "SERVICE_TYPE"], as_index=False)[
                        ["FORECAST_CREDITS", "LOWER_BOUND_CREDITS", "UPPER_BOUND_CREDITS"]
                    ]
                    .sum()
                )
                monthly_total = (
                    monthly.groupby("MONTH", as_index=False)[
                        ["FORECAST_CREDITS", "LOWER_BOUND_CREDITS", "UPPER_BOUND_CREDITS"]
                    ]
                    .sum()
                )
                monthly_total["FORECAST_COST_USD"] = monthly_total["FORECAST_CREDITS"] * credit_cost
                monthly_total["LOWER_COST_USD"] = monthly_total["LOWER_BOUND_CREDITS"] * credit_cost
                monthly_total["UPPER_COST_USD"] = monthly_total["UPPER_BOUND_CREDITS"] * credit_cost

                total_forecast_credits = float(monthly_total["FORECAST_CREDITS"].sum())
                total_forecast_cost = float(monthly_total["FORECAST_COST_USD"].sum())

                col1, col2 = st.columns(2)
                with col1:
                    st.metric("Forecast credits (total)", format_number(total_forecast_credits))
                with col2:
                    st.metric("Forecast cost (total)", format_currency(total_forecast_cost))

                st.divider()

                fig = go.Figure()
                fig.add_trace(
                    go.Scatter(
                        x=monthly_total["MONTH"],
                        y=monthly_total["UPPER_COST_USD"],
                        mode="lines",
                        name="Upper bound",
                        line=dict(width=0),
                        showlegend=True,
                    )
                )
                fig.add_trace(
                    go.Scatter(
                        x=monthly_total["MONTH"],
                        y=monthly_total["LOWER_COST_USD"],
                        mode="lines",
                        name="Lower bound",
                        line=dict(width=0),
                        fill="tonexty",
                        fillcolor="rgba(41, 181, 232, 0.2)",
                        showlegend=True,
                    )
                )
                fig.add_trace(
                    go.Scatter(
                        x=monthly_total["MONTH"],
                        y=monthly_total["FORECAST_COST_USD"],
                        mode="lines+markers",
                        name="Forecast",
                        line=dict(color="#29B5E8", width=3),
                    )
                )
                fig.update_layout(
                    title="Monthly forecast (total cost)",
                    xaxis_title="Month",
                    yaxis_title="Projected cost (USD)",
                    hovermode="x unified",
                )
                st.plotly_chart(fig, use_container_width=True)

                st.subheader("Monthly breakdown (total)")
                st.dataframe(
                    monthly_total[["MONTH", "FORECAST_CREDITS", "FORECAST_COST_USD", "LOWER_COST_USD", "UPPER_COST_USD"]].style.format(
                        {
                            "FORECAST_CREDITS": "{:,.4f}",
                            "FORECAST_COST_USD": "${:,.2f}",
                            "LOWER_COST_USD": "${:,.2f}",
                            "UPPER_COST_USD": "${:,.2f}",
                        }
                    ),
                    use_container_width=True,
                    hide_index=True,
                )

                st.subheader("Service breakdown (monthly credits)")
                service_month = monthly.pivot_table(
                    index="MONTH", columns="SERVICE_TYPE", values="FORECAST_CREDITS", aggfunc="sum", fill_value=0
                ).reset_index()
                st.dataframe(service_month, use_container_width=True, hide_index=True)

                return

        st.info("ML forecast model/view is unavailable or empty. Falling back to a simple projection from historical data.")

    # ------------------------------------------------------------------------
    # Fallback path: simple statistical projection from the currently loaded data
    # ------------------------------------------------------------------------
    if df is None or df.empty:
        st.warning("No historical data available to project.")
        return

    df_local = df.copy()
    df_local.columns = df_local.columns.str.upper()
    if "DATE" not in df_local.columns:
        st.warning("Expected a DATE column in the historical dataset.")
        return

    df_local["DATE"] = pd.to_datetime(df_local["DATE"])
    daily_total = df_local.groupby("DATE", as_index=False)["TOTAL_CREDITS"].sum().sort_values("DATE")

    if len(daily_total) < 7:
        st.warning("Not enough historical data points to create a meaningful projection (need at least 7 days).")
        return

    # Linear trend on daily totals (simple, transparent fallback)
    x = np.arange(len(daily_total))
    y = daily_total["TOTAL_CREDITS"].values.astype(float)
    slope, intercept = np.polyfit(x, y, deg=1)

    last_date = daily_total["DATE"].max()
    future_dates = pd.date_range(start=last_date + pd.Timedelta(days=1), periods=projection_days, freq="D")
    x_future = np.arange(len(daily_total), len(daily_total) + len(future_dates))
    y_future = np.maximum(0, intercept + slope * x_future)

    proj = pd.DataFrame({"DATE": future_dates, "FORECAST_CREDITS": y_future})
    proj["MONTH"] = proj["DATE"].dt.to_period("M").dt.to_timestamp()
    monthly = proj.groupby("MONTH", as_index=False)["FORECAST_CREDITS"].sum()
    monthly["FORECAST_COST_USD"] = monthly["FORECAST_CREDITS"] * credit_cost

    st.caption("Fallback forecast: simple linear trend extrapolation on daily total credits.")

    col1, col2 = st.columns(2)
    with col1:
        st.metric("Forecast credits (total)", format_number(float(monthly["FORECAST_CREDITS"].sum())))
    with col2:
        st.metric("Forecast cost (total)", format_currency(float(monthly["FORECAST_COST_USD"].sum())))

    fig = px.line(monthly, x="MONTH", y="FORECAST_COST_USD", title="Monthly projected cost (fallback)")
    st.plotly_chart(fig, use_container_width=True)

    st.dataframe(
        monthly.style.format({"FORECAST_CREDITS": "{:,.4f}", "FORECAST_COST_USD": "${:,.2f}"}),
        use_container_width=True,
        hide_index=True,
    )

def show_historical_analysis(df, credit_cost):
    """Display historical analysis tab"""
    st.header("Historical Usage Analysis")

    # Summary statistics
    total_credits = df['TOTAL_CREDITS'].sum()
    total_cost = total_credits * credit_cost
    avg_daily_credits = df.groupby('DATE')['TOTAL_CREDITS'].sum().mean()
    avg_daily_users = df['DAILY_UNIQUE_USERS'].mean()

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("Total Credits", format_number(total_credits))
    with col2:
        st.metric("Total Cost", format_currency(total_cost))
    with col3:
        st.metric("Avg Daily Credits", format_number(avg_daily_credits))
    with col4:
        st.metric("Avg Daily Users", f"{avg_daily_users:.1f}")

    st.divider()

    # 30-Day Rolling Totals
    st.subheader("30-Day Rolling Totals (Most Recent)")
    st.caption("Rolling 30-day windows for cost estimation")

    # Calculate 30-day totals
    df_with_30d = calculate_30day_totals(df)

    if not df_with_30d.empty:
        # Get most recent 30-day totals by service
        latest_30d = df_with_30d.groupby('SERVICE_TYPE').last().reset_index()
        latest_30d['COST_30D_USD'] = latest_30d['credits_30d_total'] * credit_cost
        latest_30d['COST_PER_USER_30D_USD'] = latest_30d['cost_per_user_30d'] * credit_cost

        # Display metrics
        col1, col2, col3, col4 = st.columns(4)

        total_30d_credits = latest_30d['credits_30d_total'].sum()
        total_30d_cost = total_30d_credits * credit_cost
        avg_30d_users = latest_30d['users_30d_avg'].mean()
        avg_cost_per_user_30d = total_30d_cost / avg_30d_users if avg_30d_users > 0 else 0

        with col1:
            st.metric("30-Day Total Credits", format_number(total_30d_credits))
        with col2:
            st.metric("30-Day Total Cost", format_currency(total_30d_cost))
        with col3:
            st.metric("30-Day Avg Users", format_number(avg_30d_users))
        with col4:
            st.metric("Avg Cost/User (30d)", format_currency(avg_cost_per_user_30d))

        # Service-level 30-day breakdown
        st.caption("30-Day Totals by Service")
        service_30d_display = latest_30d[['SERVICE_TYPE', 'credits_30d_total', 'COST_30D_USD',
                                           'operations_30d_total', 'users_30d_avg', 'COST_PER_USER_30D_USD']].copy()
        service_30d_display.columns = ['Service', '30d Credits', '30d Cost', '30d Operations', '30d Avg Users', 'Cost/User (30d)']

        st.dataframe(
            service_30d_display.style.format({
                '30d Credits': '{:,.0f}',
                '30d Cost': '${:,.2f}',
                '30d Operations': '{:,.0f}',
                '30d Avg Users': '{:.1f}',
                'Cost/User (30d)': '${:,.2f}'
            }),
            use_container_width=True,
            hide_index=True
        )

    st.divider()

    # Service breakdown
    st.subheader("Service Breakdown")
    service_agg = df.groupby('SERVICE_TYPE').agg({
        'TOTAL_CREDITS': 'sum',
        'DAILY_UNIQUE_USERS': 'mean',
        'TOTAL_OPERATIONS': 'sum'
    }).reset_index()
    service_agg['TOTAL_COST_USD'] = service_agg['TOTAL_CREDITS'] * credit_cost
    service_agg = service_agg.sort_values('TOTAL_CREDITS', ascending=False)

    col1, col2 = st.columns([2, 1])

    with col1:
        st.dataframe(
            service_agg.style.format({
                'TOTAL_CREDITS': '{:,.0f}',
                'TOTAL_COST_USD': '${:,.2f}',
                'DAILY_UNIQUE_USERS': '{:.0f}',
                'TOTAL_OPERATIONS': '{:,.0f}'
            }),
            use_container_width=True
        )

    with col2:
        fig = px.pie(
            service_agg,
            values='TOTAL_CREDITS',
            names='SERVICE_TYPE',
            title='Credits by Service'
        )
        st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Usage trends
    st.subheader("Usage Trends")

    daily_totals = df.groupby(['DATE', 'SERVICE_TYPE'])['TOTAL_CREDITS'].sum().reset_index()

    fig = px.line(
        daily_totals,
        x='DATE',
        y='TOTAL_CREDITS',
        color='SERVICE_TYPE',
        title='Daily Credits Usage by Service'
    )
    fig.update_layout(hovermode='x unified')
    st.plotly_chart(fig, use_container_width=True)

@st.cache_data(ttl=300)  # Cache for 5 minutes
def fetch_aisql_data():
    """Fetch all AISQL data in one go (cached for performance)"""
    try:
        # Function Summary - LIMIT to top 50 for performance
        function_summary_df = session.sql("""
            SELECT
                function_name,
                model_name,
                call_count,
                total_credits,
                total_tokens,
                avg_credits_per_call,
                avg_tokens_per_call,
                cost_per_million_tokens,
                serverless_calls,
                compute_calls
            FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_AISQL_FUNCTION_SUMMARY
            ORDER BY total_credits DESC
            LIMIT 50
        """).to_pandas()

        # Model Comparison
        model_comparison_df = session.sql("""
            SELECT
                model_name,
                functions_used,
                total_calls,
                total_credits,
                total_tokens,
                avg_credits_per_call,
                cost_per_million_tokens,
                median_credits,
                p90_credits
            FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_AISQL_MODEL_COMPARISON
            ORDER BY total_credits DESC
            LIMIT 20
        """).to_pandas()

        # Daily Trends - LIMIT to last 30 days and top functions
        daily_trends_df = session.sql("""
            SELECT
                usage_date,
                function_name,
                model_name,
                daily_credits,
                daily_tokens,
                serverless_calls,
                compute_calls
            FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_AISQL_DAILY_TRENDS
            WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
            ORDER BY usage_date DESC, daily_credits DESC
            LIMIT 500
        """).to_pandas()

        return function_summary_df, model_comparison_df, daily_trends_df
    except Exception as e:
        return None, None, None

def show_aisql_functions(credit_cost):
    """Display AISQL Functions analysis tab (NEW in v2.5)"""
    st.header("AISQL Function and Model Analysis")
    st.markdown("**Detailed tracking of Cortex AISQL functions and models** (v3.3: Updated Feb 2026 - new models, deprecation warnings)")

    # ========================================================================
    # Fetch AISQL data (cached for performance)
    # ========================================================================

    with st.spinner("Loading AISQL data..."):
        function_summary_df, model_comparison_df, daily_trends_df = fetch_aisql_data()

    if function_summary_df is None:
        st.error("Unable to load AISQL function data.")
        st.info("Make sure you've deployed the monitoring views using deploy_cortex_monitoring.sql")
        return

    if function_summary_df.empty:
        st.warning("No AISQL function usage found. Start using Cortex AISQL functions to see data here!")
        st.markdown("""
        **Tracked AISQL Functions:**
        - AI_COMPLETE, COMPLETE
        - AI_CLASSIFY
        - AI_FILTER
        - AI_AGG
        - AI_EMBED, EMBED_TEXT, EMBED_IMAGE
        - AI_EXTRACT
        - AI_SENTIMENT
        - AI_SUMMARIZE_AGG
        - AI_TRANSCRIBE
        - And more...
        """)
        return

    if model_comparison_df is None:
        model_comparison_df = pd.DataFrame()
    if daily_trends_df is None:
        daily_trends_df = pd.DataFrame()

    # ========================================================================
    # Section 1: Function & Model Overview
    # ========================================================================

    st.subheader("Function and Model Overview")

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        total_functions = function_summary_df['FUNCTION_NAME'].nunique()
        st.metric("Functions Used", total_functions)

    with col2:
        total_models = function_summary_df['MODEL_NAME'].dropna().nunique()
        st.metric("Models Used", total_models)

    with col3:
        total_calls = function_summary_df['CALL_COUNT'].sum()
        st.metric("Total Calls", f"{total_calls:,.0f}")

    with col4:
        total_credits = function_summary_df['TOTAL_CREDITS'].sum()
        total_cost = total_credits * credit_cost
        st.metric("Total Cost", f"${total_cost:,.2f}")

    st.markdown("---")

    # ========================================================================
    # Section 2: Top Functions by Cost
    # ========================================================================

    st.subheader("Top Functions by Cost")

    # Aggregate by function (across all models)
    top_functions = function_summary_df.groupby('FUNCTION_NAME').agg({
        'CALL_COUNT': 'sum',
        'TOTAL_CREDITS': 'sum',
        'TOTAL_TOKENS': 'sum',
        'SERVERLESS_CALLS': 'sum',
        'COMPUTE_CALLS': 'sum'
    }).reset_index()

    top_functions['COST_USD'] = top_functions['TOTAL_CREDITS'] * credit_cost
    top_functions = top_functions.sort_values('TOTAL_CREDITS', ascending=False).head(10)

    # Bar chart
    fig_functions = px.bar(
        top_functions,
        x='FUNCTION_NAME',
        y='TOTAL_CREDITS',
        title='Top 10 AISQL Functions by Credit Usage',
        labels={'TOTAL_CREDITS': 'Total Credits', 'FUNCTION_NAME': 'Function'},
        color='TOTAL_CREDITS',
        color_continuous_scale='Viridis'
    )
    fig_functions.update_layout(showlegend=False)
    st.plotly_chart(fig_functions, use_container_width=True)

    # Display table
    display_cols = ['FUNCTION_NAME', 'CALL_COUNT', 'TOTAL_CREDITS', 'COST_USD',
                    'TOTAL_TOKENS', 'SERVERLESS_CALLS', 'COMPUTE_CALLS']
    st.dataframe(
        top_functions[display_cols].style.format({
            'CALL_COUNT': '{:,.0f}',
            'TOTAL_CREDITS': '{:.4f}',
            'COST_USD': '${:,.2f}',
            'TOTAL_TOKENS': '{:,.0f}',
            'SERVERLESS_CALLS': '{:,.0f}',
            'COMPUTE_CALLS': '{:,.0f}'
        }),
        use_container_width=True,
        hide_index=True
    )

    st.markdown("---")

    # ========================================================================
    # Section 3: Model Comparison
    # ========================================================================

    if not model_comparison_df.empty:
        st.subheader("Model Comparison")

        # Prepare data
        model_comparison_df['COST_USD'] = model_comparison_df['TOTAL_CREDITS'] * credit_cost
        model_comparison_df['COST_PER_MILLION_USD'] = model_comparison_df['COST_PER_MILLION_TOKENS'] * credit_cost

        # Scatter plot: Cost vs Usage
        fig_models = px.scatter(
            model_comparison_df,
            x='TOTAL_CALLS',
            y='TOTAL_CREDITS',
            size='TOTAL_TOKENS',
            color='MODEL_NAME',
            title='Model Usage: Calls vs Credits (bubble size = tokens)',
            labels={
                'TOTAL_CALLS': 'Total Calls',
                'TOTAL_CREDITS': 'Total Credits',
                'MODEL_NAME': 'Model'
            },
            hover_data=['FUNCTIONS_USED', 'AVG_CREDITS_PER_CALL', 'COST_PER_MILLION_TOKENS']
        )
        fig_models.update_traces(marker=dict(sizemode='diameter', sizeref=model_comparison_df['TOTAL_TOKENS'].max()/1e6))
        st.plotly_chart(fig_models, use_container_width=True)

        # Model comparison table
        st.markdown("**Model Details**")
        display_cols_model = ['MODEL_NAME', 'FUNCTIONS_USED', 'TOTAL_CALLS', 'TOTAL_CREDITS',
                              'COST_USD', 'COST_PER_MILLION_USD', 'TOTAL_TOKENS']
        st.dataframe(
            model_comparison_df[display_cols_model].style.format({
                'FUNCTIONS_USED': '{:.0f}',
                'TOTAL_CALLS': '{:,.0f}',
                'TOTAL_CREDITS': '{:.4f}',
                'COST_USD': '${:,.2f}',
                'COST_PER_MILLION_USD': '${:,.2f}',
                'TOTAL_TOKENS': '{:,.0f}'
            }),
            use_container_width=True,
            hide_index=True
        )

        st.markdown("---")

    # ========================================================================
    # Section 4: Function-Model Heatmap (Collapsible for performance)
    # ========================================================================

    with st.expander("Function-Model Usage Heatmap", expanded=False):
        # Create pivot table for heatmap
        heatmap_data = function_summary_df.pivot_table(
            index='FUNCTION_NAME',
            columns='MODEL_NAME',
            values='TOTAL_CREDITS',
            fill_value=0
        )

        # Create heatmap
        fig_heatmap = px.imshow(
            heatmap_data,
            labels=dict(x="Model", y="Function", color="Credits"),
            title="Credit Usage by Function and Model",
            color_continuous_scale='YlOrRd',
            aspect='auto'
        )
        fig_heatmap.update_xaxes(side='bottom')
        st.plotly_chart(fig_heatmap, use_container_width=True)

    st.markdown("---")

    # ========================================================================
    # Section 5: Daily Trends (Collapsible for performance)
    # ========================================================================

    if not daily_trends_df.empty:
        with st.expander("Daily Usage Trends (Last 30 Days)", expanded=False):
            # Aggregate by date and function
            daily_agg = daily_trends_df.groupby(['USAGE_DATE', 'FUNCTION_NAME']).agg({
                'DAILY_CREDITS': 'sum',
                'DAILY_TOKENS': 'sum'
            }).reset_index()

            # Line chart
            fig_trends = px.line(
                daily_agg,
                x='USAGE_DATE',
                y='DAILY_CREDITS',
                color='FUNCTION_NAME',
                title='Daily Credit Usage by Function (Last 30 Days)',
                labels={'DAILY_CREDITS': 'Daily Credits', 'USAGE_DATE': 'Date'}
            )
            fig_trends.update_layout(hovermode='x unified')
            st.plotly_chart(fig_trends, use_container_width=True)

        st.markdown("---")

    # ========================================================================
    # Section 6: Detailed Function-Model Table (Collapsible for performance)
    # ========================================================================

    with st.expander("Detailed Function-Model Breakdown", expanded=False):
        st.markdown("**Complete data table with all metrics**")

        # Prepare detailed table
        detailed_df = function_summary_df.copy()
        detailed_df['COST_USD'] = detailed_df['TOTAL_CREDITS'] * credit_cost
        detailed_df['COST_PER_MILLION_USD'] = detailed_df['COST_PER_MILLION_TOKENS'] * credit_cost
        detailed_df = detailed_df.sort_values('TOTAL_CREDITS', ascending=False)

        display_cols_detailed = [
            'FUNCTION_NAME', 'MODEL_NAME', 'CALL_COUNT', 'TOTAL_CREDITS', 'COST_USD',
            'TOTAL_TOKENS', 'COST_PER_MILLION_USD', 'AVG_TOKENS_PER_CALL',
            'SERVERLESS_CALLS', 'COMPUTE_CALLS'
        ]

        st.dataframe(
            detailed_df[display_cols_detailed].style.format({
                'CALL_COUNT': '{:,.0f}',
                'TOTAL_CREDITS': '{:.6f}',
                'COST_USD': '${:,.4f}',
                'TOTAL_TOKENS': '{:,.0f}',
                'COST_PER_MILLION_USD': '${:,.2f}',
                'AVG_TOKENS_PER_CALL': '{:,.0f}',
                'SERVERLESS_CALLS': '{:,.0f}',
                'COMPUTE_CALLS': '{:,.0f}'
            }),
            use_container_width=True,
            hide_index=True
        )

        # Download button
        csv = detailed_df.to_csv(index=False)
        st.download_button(
            label="Download AISQL Data as CSV",
            data=csv,
            file_name=f"aisql_function_analysis_{datetime.now().strftime('%Y%m%d')}.csv",
            mime="text/csv"
        )

    st.markdown("---")
    st.info("Tip: Use this data to optimize your AISQL function usage and choose the most cost-effective models for your use case.")

def show_cost_projections(df, credit_cost, variance_pct):
    """Display cost projections tab"""
    st.header("Cost Projections")

    # ========================================================================
    # Important: API vs SQL Function Usage
    # ========================================================================
    st.info("""
    ### Understanding Your Cortex Usage Costs

    **Two ways to use Cortex services:**

    1. **SQL functions** (e.g., `SELECT SNOWFLAKE.CORTEX.COMPLETE(...)`)
       - Tracked via `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY` (query, function, model, tokens, credits)
       - Query-level grouping is available (by `QUERY_ID`)
       - Best visibility for per-query and per-model usage telemetry

    2. **REST API** (e.g., `POST /api/v2/cortex/complete`, Cortex Agents)
       - Per-request token tracking available via `CORTEX_REST_API_USAGE_HISTORY` (user, model, tokens, region)
       - Per-request **credits** are not available in this view; validate totals via metering (`METERING_DAILY_HISTORY`, service_type = `AI_SERVICES`)

    **Key insight:** this calculator's detailed function/model breakdown is based on SQL query telemetry
    (`CORTEX_AISQL_USAGE_HISTORY`). If you use the REST API heavily, reconcile totals using the metering view
    (`V_METERING_AI_SERVICES`) to confirm coverage.
    """)

    # ========================================================================
    # Snowflake Official Consumption Rates (Reference)
    # ========================================================================
    with st.expander("Snowflake Official Consumption Rates (Updated Feb 2026)", expanded=False):
        st.markdown("""
        **Reference: Snowflake AI Features Credit Table (Table 6)**

        These are Snowflake's published consumption rates for Cortex services:
        *Source: [Snowflake Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf) (Effective Feb 6, 2026)*

        **Note:** Some models are deprecated in the 2025_05 behavior bundle. See LLM Functions tab for details.
        """)

        # Create tabs for different service categories
        rate_tab1, rate_tab2, rate_tab3, rate_tab4 = st.tabs([
            "Document AI and Search",
            "LLM Functions",
            "Text Functions",
            "Embeddings",
        ])

        with rate_tab1:
            st.markdown("**Document AI & Search Services**")
            rates_data_doc = pd.DataFrame([
                {
                    'Service': 'AI Parse Document (Layout)',
                    'Rate': '3.33 credits per 1,000 pages',
                    'Access': 'SQL + API',
                    'Metric': 'Pages processed',
                    'Your Data': 'V_DOCUMENT_AI_DETAIL view'
                },
                {
                    'Service': 'AI Parse Document (OCR)',
                    'Rate': '0.5 credits per 1,000 pages',
                    'Access': 'SQL + API',
                    'Metric': 'Pages processed',
                    'Your Data': 'V_DOCUMENT_AI_DETAIL view'
                },
                {
                    'Service': 'Cortex Analyst',
                    'Rate': '67 credits per 1,000 messages (0.067/msg)',
                    'Access': 'API only',
                    'Metric': 'Messages/requests',
                    'Your Data': 'V_CORTEX_ANALYST_DETAIL view'
                },
                {
                    'Service': 'Cortex Search',
                    'Rate': '6.3 credits per GB/month',
                    'Access': 'SQL + API',
                    'Metric': 'Indexed data size',
                    'Your Data': 'V_CORTEX_SEARCH_DETAIL view'
                },
                {
                    'Service': 'Document AI',
                    'Rate': '8 credits per hour',
                    'Access': 'SQL + API',
                    'Metric': 'Compute hours',
                    'Your Data': 'V_DOCUMENT_AI_DETAIL view'
                }
            ])
            st.dataframe(rates_data_doc, use_container_width=True, hide_index=True)

        with rate_tab2:
            st.markdown("**LLM Text Generation Functions (COMPLETE, CLASSIFY, etc.)**")
            st.caption("Rates shown are credits per 1 million tokens. Available via SQL functions AND REST API.")

            # Current models (as of Feb 2026)
            llm_rates = pd.DataFrame([
                # Claude models (current)
                {'Model': 'claude-4-sonnet', 'Input': 3.0, 'Output': 15.0, 'Access': 'SQL + API', 'Notes': 'Latest Claude'},
                {'Model': 'claude-3-7-sonnet', 'Input': 3.0, 'Output': 15.0, 'Access': 'SQL + API', 'Notes': 'High capability'},
                {'Model': 'claude-3-5-sonnet', 'Input': 3.0, 'Output': 15.0, 'Access': 'SQL + API', 'Notes': 'High capability'},
                {'Model': 'claude-3-5-haiku', 'Input': 1.0, 'Output': 5.0, 'Access': 'SQL + API', 'Notes': 'Fast & efficient'},
                {'Model': 'claude-3-opus', 'Input': 15.0, 'Output': 75.0, 'Access': 'SQL + API', 'Notes': 'Most capable'},
                {'Model': 'claude-3-sonnet', 'Input': 3.0, 'Output': 15.0, 'Access': 'SQL + API', 'Notes': 'Balanced'},
                {'Model': 'claude-3-haiku', 'Input': 0.25, 'Output': 1.25, 'Access': 'SQL + API', 'Notes': 'Fastest'},
                # Llama models (current)
                {'Model': 'snowflake-llama-3.3-70b', 'Input': 0.4, 'Output': 0.4, 'Access': 'SQL + API', 'Notes': 'Snowflake optimized'},
                {'Model': 'llama3.1-405b', 'Input': 3.0, 'Output': 3.0, 'Access': 'SQL + API', 'Notes': 'Large model'},
                {'Model': 'llama3.1-70b', 'Input': 0.4, 'Output': 0.4, 'Access': 'SQL + API', 'Notes': 'Good balance'},
                {'Model': 'llama3.1-8b', 'Input': 0.1, 'Output': 0.1, 'Access': 'SQL + API', 'Notes': 'Efficient'},
                {'Model': 'llama3-70b', 'Input': 0.4, 'Output': 0.4, 'Access': 'SQL + API', 'Notes': 'Previous gen'},
                {'Model': 'llama3-8b', 'Input': 0.1, 'Output': 0.1, 'Access': 'SQL + API', 'Notes': 'Previous gen'},
                # DeepSeek (new)
                {'Model': 'deepseek-r1', 'Input': 0.55, 'Output': 2.19, 'Access': 'SQL + API', 'Notes': 'Cross-region'},
                # Mistral models (current)
                {'Model': 'mistral-large2', 'Input': 2.0, 'Output': 6.0, 'Access': 'SQL + API', 'Notes': 'Latest large'},
                {'Model': 'mistral-large', 'Input': 2.0, 'Output': 6.0, 'Access': 'SQL + API', 'Notes': 'Large model'},
                {'Model': 'mixtral-8x7b', 'Input': 0.15, 'Output': 0.15, 'Access': 'SQL + API', 'Notes': 'MoE model'},
                {'Model': 'mistral-7b', 'Input': 0.1, 'Output': 0.1, 'Access': 'SQL + API', 'Notes': 'Base model'},
            ])

            st.dataframe(
                llm_rates.style.format({
                    'Input': '{:.2f}',
                    'Output': '{:.2f}'
                }),
                use_container_width=True,
                hide_index=True
            )

            # Deprecated models warning
            st.warning("""
            **Deprecated Models (2025_05 bundle):** The following models are being deprecated and should not be used for new projects:
            - `gemma-7b`, `jamba-1.5-large`, `jamba-1.5-mini`, `jamba-instruct`
            - `llama2-70b-chat`, `llama3.2-1b`, `llama3.2-3b`
            - `reka-core`, `reka-flash`

            Migrate to newer alternatives like `snowflake-llama-3.3-70b` or `mistral-large2`.
            """)

            st.info("""
            **Important**: These models are used for functions like:
            - `COMPLETE()` / `AI_COMPLETE()` - Text generation
            - `AI_CLASSIFY()` - Classification tasks
            - `AI_FILTER()` - Content filtering
            - `AI_AGG()` - Aggregation tasks
            """)

        with rate_tab3:
            st.markdown("**Specialized Text Functions**")
            st.caption("Rates shown are credits per 1 million tokens. Available via SQL functions AND REST API.")

            text_rates = pd.DataFrame([
                {'Function': 'SENTIMENT', 'Rate': 0.056, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'},
                {'Function': 'SUMMARIZE', 'Rate': 0.056, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'},
                {'Function': 'TRANSLATE', 'Rate': 0.056, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'},
                {'Function': 'EXTRACT_ANSWER', 'Rate': 0.056, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'},
                {'Function': 'AI_EXTRACT (standard)', 'Rate': 0.15, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'},
                {'Function': 'AI_EXTRACT (mistral-large)', 'Rate': 2.0, 'Access': 'SQL + API', 'Metric': 'per 1M input tokens'},
                {'Function': 'AI_EXTRACT (mistral-large)', 'Rate': 6.0, 'Access': 'SQL + API', 'Metric': 'per 1M output tokens'},
                {'Function': 'AI_SENTIMENT', 'Rate': 0.3, 'Access': 'SQL + API', 'Metric': 'per 1M tokens'}
            ])

            st.dataframe(
                text_rates.style.format({'Rate': '{:.3f}'}),
                use_container_width=True,
                hide_index=True
            )

        with rate_tab4:
            st.markdown("**Embedding Functions**")
            st.caption("Rates shown are credits per 1 million tokens. Available via SQL functions AND REST API.")

            embedding_rates = pd.DataFrame([
                {'Function': 'EMBED_TEXT_768', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 768},
                {'Function': 'EMBED_TEXT_1024', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 1024},
                {'Function': 'AI_EMBED (e5-base-v2)', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 768},
                {'Function': 'AI_EMBED (multilingual-e5-large)', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 1024},
                {'Function': 'AI_EMBED (snowflake-arctic-embed-l-v2.0)', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 1024},
                {'Function': 'AI_EMBED (snowflake-arctic-embed-m-v2.0)', 'Rate': 0.014, 'Access': 'SQL + API', 'Dimensions': 768},
                {'Function': 'EMBED_IMAGE_1024', 'Rate': 0.14, 'Access': 'SQL + API', 'Dimensions': 1024}
            ])

            st.dataframe(
                embedding_rates.style.format({'Rate': '{:.4f}'}),
                use_container_width=True,
                hide_index=True
            )

        rates_data = pd.DataFrame([
            {
                'Service': 'AI Parse Document (Layout)',
                'Rate': '3.33 credits per 1,000 pages',
                'Access Method': 'SQL + API',
                'Metric': 'Pages processed',
                'Your Data': 'V_DOCUMENT_AI_DETAIL view'
            },
            {
                'Service': 'AI Parse Document (OCR)',
                'Rate': '0.5 credits per 1,000 pages',
                'Access Method': 'SQL + API',
                'Metric': 'Pages processed',
                'Your Data': 'V_DOCUMENT_AI_DETAIL view'
            },
            {
                'Service': 'Cortex Analyst',
                'Rate': '67 credits per 1,000 messages (0.067/msg)',
                'Access Method': 'API only',
                'Metric': 'Messages/requests',
                'Your Data': 'V_CORTEX_ANALYST_DETAIL view'
            },
            {
                'Service': 'Cortex Search',
                'Rate': '6.3 credits per GB/month',
                'Access Method': 'SQL + API',
                'Metric': 'Indexed data size',
                'Your Data': 'V_CORTEX_SEARCH_DETAIL view'
            },
            {
                'Service': 'AISQL Functions',
                'Rate': 'Varies by model & tokens (see tabs above)',
                'Access Method': 'SQL + API',
                'Metric': 'Tokens processed',
                'Your Data': 'V_AISQL_FUNCTION_SUMMARY view'
            }
        ])

        st.dataframe(
            rates_data,
            use_container_width=True,
            hide_index=True
        )

        st.info("""
        **How to validate your costs:**
        1. Check the "Historical Analysis" tab for actual credit consumption
        2. Compare credits/operation ratios with rates above
        3. For AISQL functions, check the "AISQL Functions" tab for per-token costs
        4. If rates differ significantly, verify your ACCOUNT_USAGE data
        """)

        st.info("""
        **Important Notes:**
        - **Pricing is identical** for both SQL functions AND REST API calls (same rates apply)
        - **All usage is tracked** in ACCOUNT_USAGE views with tokens, credits, function, and model details
        - AISQL function costs vary by model (claude, llama, mistral, etc.) and token usage
        - Token-based pricing depends on input + output tokens
        - Rates shown are for Snowflake-managed compute
        - **Query-level breakdown** available only for SQL functions; REST API usage appears in hourly aggregates
        """)

        # Calculate actual rates from data if available
        if not df.empty:
            st.markdown("---")
            st.markdown("**Your Actual Consumption Rates (from ACCOUNT_USAGE)**")

            actual_rates = []

            for service in df['SERVICE_TYPE'].unique():
                service_data = df[df['SERVICE_TYPE'] == service]
                total_credits = service_data['TOTAL_CREDITS'].sum()
                total_ops = service_data['TOTAL_OPERATIONS'].sum()

                if total_ops > 0:
                    rate_per_op = total_credits / total_ops

                    # Add service-specific context
                    if 'Analyst' in service:
                        expected = 0.067  # 0.067 credits per message
                        display_rate = f'{rate_per_op:.4f} credits per message'
                        metric = 'messages'
                    elif 'Document' in service:
                        rate_per_1000 = rate_per_op * 1000
                        expected = 1.915  # Average of Layout (3.33) and OCR (0.5) per 1,000 pages
                        display_rate = f'{rate_per_1000:.2f} credits per 1,000 pages'
                        metric = 'pages'
                    elif 'Search' in service:
                        expected = None  # GB-based, different metric
                        display_rate = f'{rate_per_op:.4f} credits per operation'
                        metric = 'operations'
                    else:
                        expected = None
                        display_rate = f'{rate_per_op:.4f} credits per operation'
                        metric = 'operations'

                    # Check if within range (+/-50% tolerance)
                    if expected:
                        actual_value = rate_per_op if 'Analyst' in service else rate_per_op * 1000
                        within_range = abs(actual_value - expected) / expected < 0.5
                        status = 'Within range' if within_range else 'Verify'
                    else:
                        status = 'No baseline'

                    actual_rates.append({
                        'Service': service,
                        'Your Rate': display_rate,
                        'Total Operations': f'{total_ops:,.0f}',
                        'Total Credits': f'{total_credits:.4f}',
                        'Status': status
                    })

            if actual_rates:
                actual_rates_df = pd.DataFrame(actual_rates)
                st.dataframe(
                    actual_rates_df,
                    use_container_width=True,
                    hide_index=True
                )

                st.info("""
                **Validation:** Your actual rates are calculated from ACCOUNT_USAGE data and represent real consumption.
                Differences from published rates may occur due to:
                - Different models/configurations
                - Mixed operation types (e.g., Layout vs OCR)
                - Rounding in aggregated data
                """)

    st.divider()

    # ========================================================================
    # Cost Calculation Methodology
    # ========================================================================
    with st.expander("How We Calculate Your Costs (SQL vs API Usage)", expanded=False):
        st.markdown("""
        ### Calculation Methodology

        **Data Sources:**
        - **SQL AI Function details**: `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY`
        - **Document processing details**: `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY`
        - **Cortex Analyst details**: `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY`
        - **Total AI services credits validation**: `SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY` filtered to `AI_SERVICES`

        **What This Means:**
        """)

        comparison_data = pd.DataFrame([
            {'Feature': 'Total AI services credits', 'SQL Functions': 'Yes (metering validation)', 'REST API': 'Yes (metering validation)'},
            {'Feature': 'Function & model breakdown', 'SQL Functions': 'Yes (CORTEX_AISQL_USAGE_HISTORY)', 'REST API': 'Limited'},
            {'Feature': 'Per-query details', 'SQL Functions': 'Yes (QUERY_ID level)', 'REST API': 'Not available'},
            {'Feature': 'User attribution', 'SQL Functions': 'Yes (QUERY_HISTORY join)', 'REST API': 'Not available'},
            {'Feature': 'Historical trend analysis', 'SQL Functions': 'Yes (full detail)', 'REST API': 'Yes (metering totals)'}
        ])

        st.dataframe(comparison_data, use_container_width=True, hide_index=True)

        st.markdown("""
        **Impact on Your Cost Analysis:**

        **Good news:** for SQL-based usage, this calculator provides high-detail attribution and projections because:
        - `CORTEX_AISQL_USAGE_HISTORY` provides query/function/model/token/credit telemetry for AI Functions used in SQL
        - User attribution is computed via the `USER_ID` column (GA Dec 2025)

        **REST API usage:** per-request **token** tracking is available via `CORTEX_REST_API_USAGE_HISTORY`
        (user, model, tokens, region). However, per-request **credits** are not in this view.
        Use `V_METERING_AI_SERVICES` to validate total credits and detect gaps if REST API usage is significant.

        **Bottom line:** Use the detailed tabs for SQL telemetry, and use metering to validate total AI services spend.
        """)

    # ========================================================================
    # Cost per User Calculator - MOVED TO TOP
    # ========================================================================
    st.subheader("Cost per User Calculator")
    st.markdown("**Estimate per-user costs based on usage patterns**")

    show_cost_per_user_calculator(df, credit_cost)

    st.divider()
    st.divider()

    # ========================================================================
    # Growth-Based Cost Projections
    # ========================================================================
    st.header("Growth-Based Cost Projections")

    col1, col2 = st.columns(2)

    with col1:
        projection_months = st.slider(
            "Projection Period (months)",
            min_value=3,
            max_value=24,
            value=12
        )

    with col2:
        growth_rate = st.slider(
            "Monthly Growth Rate (%)",
            min_value=0,
            max_value=100,
            value=25
        ) / 100

    # Calculate projection
    projection_df = calculate_growth_projection(df, growth_rate, projection_months, credit_cost)

    # Summary metrics
    monthly_totals = projection_df.groupby('month')['projected_cost_usd'].sum().reset_index()

    month_1_cost = monthly_totals[monthly_totals['month'] == 1]['projected_cost_usd'].iloc[0] if len(monthly_totals) > 0 else 0
    month_12_cost = monthly_totals[monthly_totals['month'] == 12]['projected_cost_usd'].iloc[0] if len(monthly_totals) >= 12 else 0
    total_year_cost = monthly_totals['projected_cost_usd'].sum()

    st.divider()

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("Month 1 Cost", format_currency(month_1_cost))
    with col2:
        st.metric("Month 12 Cost", format_currency(month_12_cost))
    with col3:
        st.metric("Total Year Cost", format_currency(total_year_cost))
    with col4:
        variance_range = f"+/-{format_currency(total_year_cost * variance_pct)}"
        st.metric("Variance Range", variance_range)

    st.divider()

    # Projection chart
    fig = go.Figure()

    monthly_totals['lower_bound'] = monthly_totals['projected_cost_usd'] * (1 - variance_pct)
    monthly_totals['upper_bound'] = monthly_totals['projected_cost_usd'] * (1 + variance_pct)

    fig.add_trace(go.Scatter(
        x=monthly_totals['month'],
        y=monthly_totals['upper_bound'],
        mode='lines',
        name=f'Upper (+{variance_pct*100:.0f}%)',
        line=dict(width=0),
        showlegend=True
    ))

    fig.add_trace(go.Scatter(
        x=monthly_totals['month'],
        y=monthly_totals['lower_bound'],
        mode='lines',
        name=f'Lower (-{variance_pct*100:.0f}%)',
        line=dict(width=0),
        fillcolor='rgba(41, 181, 232, 0.2)',
        fill='tonexty',
        showlegend=True
    ))

    fig.add_trace(go.Scatter(
        x=monthly_totals['month'],
        y=monthly_totals['projected_cost_usd'],
        mode='lines+markers',
        name='Projected Cost',
        line=dict(color='#29B5E8', width=3)
    ))

    fig.update_layout(
        title='Cost Projection with Variance Range',
        xaxis_title='Month',
        yaxis_title='Projected Cost (USD)',
        hovermode='x unified'
    )

    st.plotly_chart(fig, use_container_width=True)

    # Detailed table
    st.subheader("Monthly Breakdown")
    st.dataframe(
        monthly_totals.style.format({
            'projected_cost_usd': '${:,.2f}',
            'lower_bound': '${:,.2f}',
            'upper_bound': '${:,.2f}'
        }),
        use_container_width=True
    )

def show_cost_per_user_calculator(df, credit_cost):
    """
    Simplified calculator for cost per user estimation
    Shows: persona name, user count, requests per day, cost per request
    """

    # Calculate historical baseline metrics from usage data
    # Use a more robust aggregation approach that handles sparse data better

    # Aggregate by service type across all available dates
    latest_30d = df.groupby('SERVICE_TYPE').agg({
        'TOTAL_OPERATIONS': 'sum',
        'DAILY_UNIQUE_USERS': 'mean',
        'TOTAL_CREDITS': 'sum',
        'DATE': 'count'  # Count number of days with data
    }).reset_index()

    # Rename DATE count to days_with_data for clarity
    latest_30d.rename(columns={'DATE': 'days_with_data'}, inplace=True)

    # Calculate average requests per day based on actual days with data
    latest_30d['requests_per_day'] = latest_30d['TOTAL_OPERATIONS'] / latest_30d['days_with_data']
    latest_30d['users_in_env'] = latest_30d['DAILY_UNIQUE_USERS']

    # Calculate cost per request (handle division by zero)
    latest_30d['cost_per_request'] = latest_30d.apply(
        lambda row: (row['TOTAL_CREDITS'] * credit_cost) / row['TOTAL_OPERATIONS']
        if row['TOTAL_OPERATIONS'] > 0 else 0,
        axis=1
    )

    # ========================================================================
    # Historical Usage Reference Table - MOVED TO TOP AS GUIDE
    # ========================================================================
    st.markdown("#### Historical Usage Reference (from your data)")
    st.caption("Use these metrics as a guide for your cost estimates below")

    # Debug expander to show raw data and accuracy checks
    with st.expander("Debug: View Raw Data and Accuracy Checks", expanded=False):
        st.markdown("**Latest Aggregated Data:**")
        st.dataframe(latest_30d, use_container_width=True)

        st.markdown("---")
        st.markdown("**Accuracy Validation Checks:**")

        # Check 1: Cortex Analyst rate validation
        analyst_data = latest_30d[latest_30d['SERVICE_TYPE'] == 'Cortex Analyst']
        if not analyst_data.empty:
            analyst_rate = analyst_data.iloc[0]['cost_per_request'] / credit_cost
            expected_rate = 0.067
            rate_diff_pct = abs((analyst_rate - expected_rate) / expected_rate * 100)

            if rate_diff_pct < 5:
                st.success(f"Cortex Analyst: {analyst_rate:.4f} credits/msg (Expected: {expected_rate}, Diff: {rate_diff_pct:.1f}%)")
            elif rate_diff_pct < 20:
                st.warning(
                    f"Cortex Analyst: {analyst_rate:.4f} credits/msg (Expected: {expected_rate}, Diff: {rate_diff_pct:.1f}%) "
                    "- Within acceptable range"
                )
            else:
                st.error(
                    f"Cortex Analyst: {analyst_rate:.4f} credits/msg (Expected: {expected_rate}, Diff: {rate_diff_pct:.1f}%) "
                    "- Significant deviation"
                )

        # Check 2: Verify no division by zero issues
        zero_ops = latest_30d[latest_30d['TOTAL_OPERATIONS'] == 0]
        if not zero_ops.empty:
            st.error(f"Found {len(zero_ops)} service(s) with 0 operations: {', '.join(zero_ops['SERVICE_TYPE'].tolist())}")
        else:
            st.success("All services have non-zero operations")

        # Check 3: Verify cost per request is reasonable
        unreasonable_costs = latest_30d[latest_30d['cost_per_request'] > 10]  # Flag if >$10 per request
        if not unreasonable_costs.empty:
            st.warning(f"Unusually high cost per request detected for: {', '.join(unreasonable_costs['SERVICE_TYPE'].tolist())}")
        else:
            st.success("All cost per request values are in a reasonable range")

        # Check 4: Data completeness
        st.markdown("**Data Completeness:**")
        for _, row in latest_30d.iterrows():
            days_pct = (row['days_with_data'] / 30) * 100
            if days_pct < 30:
                st.warning(f"{row['SERVICE_TYPE']}: Only {row['days_with_data']} days of data ({days_pct:.0f}% of 30 days)")
            else:
                st.info(f"{row['SERVICE_TYPE']}: {row['days_with_data']} days of data ({days_pct:.0f}% coverage)")

        st.markdown("---")
        st.markdown("**Raw Input Data (Last 10 Rows):**")
        st.dataframe(df.tail(10), use_container_width=True)

    reference_table = []
    for _, service in latest_30d.iterrows():
        reference_table.append({
            'Service': service['SERVICE_TYPE'],
            'Days of Data': int(service['days_with_data']),
            'Users in Environment': f"{service['users_in_env']:.0f}",
            'Requests per Day': f"{service['requests_per_day']:,.1f}",
            'Cost per Request': f"${service['cost_per_request']:.6f}"
        })

    reference_df = pd.DataFrame(reference_table)
    st.dataframe(reference_df, use_container_width=True, hide_index=True)

    st.divider()

    # ========================================================================
    # User Persona Configuration
    # ========================================================================
    st.markdown("#### Define User Personas and Estimate Costs")

    # Initialize session state for user personas if not exists
    if 'user_personas_simple' not in st.session_state:
        st.session_state.user_personas_simple = [
            {'name': 'Power User', 'count': 10, 'requests_per_day': 50},
            {'name': 'Regular User', 'count': 30, 'requests_per_day': 20}
        ]

    # User persona inputs
    personas_to_remove = []
    for idx, persona in enumerate(st.session_state.user_personas_simple):
        col1, col2, col3, col4 = st.columns([2, 1, 1, 0.5])

        with col1:
            persona['name'] = st.text_input(
                "Persona Name",
                value=persona['name'],
                key=f"simple_persona_name_{idx}",
                placeholder="e.g., Power User, Analyst, Executive"
            )

        with col2:
            persona['count'] = st.number_input(
                "Number of Users",
                min_value=1,
                value=persona['count'],
                step=1,
                key=f"simple_count_{idx}"
            )

        with col3:
            persona['requests_per_day'] = st.number_input(
                "Requests per Day",
                min_value=1,
                value=persona['requests_per_day'],
                step=5,
                key=f"simple_req_{idx}",
                help="Average requests per user per day"
            )

        with col4:
            if len(st.session_state.user_personas_simple) > 1:
                if st.button("Remove", key=f"simple_remove_{idx}", help="Remove"):
                    personas_to_remove.append(idx)

    # Remove personas marked for deletion
    for idx in sorted(personas_to_remove, reverse=True):
        st.session_state.user_personas_simple.pop(idx)
        st.rerun()

    # Add new persona button
    if st.button("Add Another Persona"):
        st.session_state.user_personas_simple.append({
            'name': f'User Type {len(st.session_state.user_personas_simple) + 1}',
            'count': 10,
            'requests_per_day': 20
        })
        st.rerun()

    st.divider()

    # ========================================================================
    # Calculate Costs per Persona
    # ========================================================================
    st.markdown("#### Cost Estimates by Persona")

    # Add toggle for rate source
    use_official_rates = st.checkbox(
        "Use official Snowflake rates (0.067 credits/message for Analyst)",
        value=False,
        help="Toggle between actual rates from your usage data vs official published rates"
    )

    # Calculate cost per request based on user selection
    if use_official_rates:
        # Use official rate: 0.067 credits per message * credit_cost
        avg_cost_per_request = 0.067 * credit_cost
        st.info(f"Using official rate: 0.067 credits/message = ${avg_cost_per_request:.6f} per request")
    else:
        # Calculate weighted average cost per request across all services from actual data
        total_ops = latest_30d['requests_per_day'].sum() * 30  # Monthly operations
        total_cost_30d = sum(
            (row['requests_per_day'] * 30 * row['cost_per_request'])
            for _, row in latest_30d.iterrows()
        )
        avg_cost_per_request = total_cost_30d / total_ops if total_ops > 0 else 0
        st.info(f"Using observed rate from your data: ${avg_cost_per_request:.6f} per request")

    # Calculate costs for each persona
    persona_results = []
    for persona in st.session_state.user_personas_simple:
        monthly_requests = persona['requests_per_day'] * 30
        cost_per_user_monthly = monthly_requests * avg_cost_per_request
        total_cost_monthly = cost_per_user_monthly * persona['count']

        persona_results.append({
            'Persona': persona['name'],
            'Users': persona['count'],
            'Requests/Day': persona['requests_per_day'],
            'Requests/Month': f"{monthly_requests:,}",
            'Cost/Request': f"${avg_cost_per_request:.6f}",
            'Cost/User/Month': f"${cost_per_user_monthly:,.2f}",
            'Total Monthly Cost': f"${total_cost_monthly:,.2f}"
        })

    results_df = pd.DataFrame(persona_results)
    st.dataframe(results_df, use_container_width=True, hide_index=True)

    # Summary metrics
    total_users = sum(p['count'] for p in st.session_state.user_personas_simple)
    total_monthly_cost = sum(
        p['requests_per_day'] * 30 * avg_cost_per_request * p['count']
        for p in st.session_state.user_personas_simple
    )
    total_monthly_requests = sum(
        p['requests_per_day'] * 30 * p['count']
        for p in st.session_state.user_personas_simple
    )
    avg_cost_per_user = total_monthly_cost / total_users if total_users > 0 else 0

    st.divider()

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("Total Users", f"{total_users:,}")
    with col2:
        st.metric("Total Monthly Requests", f"{total_monthly_requests:,.0f}")
    with col3:
        st.metric("Avg Cost per User", f"${avg_cost_per_user:,.2f}")
    with col4:
        st.metric("Total Monthly Cost", f"${total_monthly_cost:,.2f}")

    # Quick accuracy check reminder
    st.info(f"""
    **Quick Accuracy Check:**
    - **Cortex Analyst** (Official Rate): 0.067 credits per message = ${0.067 * credit_cost:.4f} per request at ${credit_cost:.2f}/credit
    - **Manual verification**: Total Monthly Cost = Total Users x Requests/Day x 30 days x Cost/Request
    - **Toggle the checkbox above** to compare observed rates vs official Snowflake rates
    - **Open the Debug expander** at the top to see detailed validation checks

    **Official Rates (Feb 6, 2026):**
    - Cortex Analyst: 67 credits per 1,000 messages (0.067/msg)
    - LLM models: Varies by model (0.1 - 75 credits per 1M tokens)
    - Document AI Layout: 3.33 credits per 1,000 pages
    - Document AI OCR: 0.5 credits per 1,000 pages
    """)

if __name__ == "__main__":
    main()
