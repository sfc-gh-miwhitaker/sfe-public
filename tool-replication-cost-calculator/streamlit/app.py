import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.exceptions import SnowparkSQLException

session = get_active_session()

PRICING_TABLE_FQN = "SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT"
DB_METADATA_VIEW_FQN = "SNOWFLAKE_EXAMPLE.REPLICATION_CALC.DB_METADATA"


def get_current_role():
    try:
        result = session.sql("SELECT CURRENT_ROLE()").collect()
        return result[0][0] if result else None
    except Exception:
        return None


@st.cache_data(ttl=300, show_spinner="Loading pricing data...")
def load_pricing():
    try:
        df = session.table(PRICING_TABLE_FQN)
        rows = df.collect()
        if not rows:
            return [], None
        updated_at = max(r.UPDATED_AT for r in rows) if hasattr(rows[0], 'UPDATED_AT') else None
        return rows, updated_at
    except SnowparkSQLException as e:
        st.error(f"Failed to load pricing data: {str(e)}. Ensure deploy_all.sql was executed successfully.")
        return [], None
    except Exception as e:
        st.error(f"Unexpected error loading pricing: {str(e)}")
        return [], None


@st.cache_data(ttl=600, show_spinner="Loading database metadata...")
def load_db_metadata():
    try:
        df = session.table(DB_METADATA_VIEW_FQN)
        return df.collect()
    except SnowparkSQLException as e:
        st.error(f"Failed to load database metadata: {str(e)}. Check ACCOUNT_USAGE access.")
        return []
    except Exception as e:
        st.error(f"Unexpected error loading database metadata: {str(e)}")
        return []


def get_cloud_and_region():
    try:
        region_result = session.sql("SELECT CURRENT_REGION()").collect()
        region_full = region_result[0][0] if region_result else "AWS_US_EAST_1"

        if region_full:
            parts = region_full.split("_", 1)
            if len(parts) >= 2:
                cloud = parts[0]
                region = parts[1].lower().replace("_", "-")
            else:
                cloud = "AWS"
                region = region_full.lower()
        else:
            cloud = "AWS"
            region = "us-east-1"

        return cloud, region
    except Exception as e:
        st.warning(f"Could not detect cloud/region: {str(e)}. Using defaults.")
        return "AWS", "us-east-1"


def cost_lookup(pricing_rows, service_type, cloud, region):
    for r in pricing_rows:
        if (
            r.SERVICE_TYPE == service_type
            and r.CLOUD.upper() == cloud.upper()
            and r.REGION.upper() == region.upper()
        ):
            rate = float(r.RATE) if r.RATE is not None else None
            return rate, r.UNIT, False

    for r in pricing_rows:
        if (
            r.SERVICE_TYPE == service_type
            and r.CLOUD.upper() == cloud.upper()
        ):
            rate = float(r.RATE) if r.RATE is not None else None
            return rate, r.UNIT, True

    for r in pricing_rows:
        if r.SERVICE_TYPE == service_type:
            rate = float(r.RATE) if r.RATE is not None else None
            return rate, r.UNIT, True

    return None, None, True


def find_lowest_cost_regions(pricing_rows, service_types):
    region_costs = {}

    for r in pricing_rows:
        if r.SERVICE_TYPE in service_types:
            key = f"{r.CLOUD}:{r.REGION}"
            if key not in region_costs:
                region_costs[key] = 0
            region_costs[key] += r.RATE

    if not region_costs:
        return []

    sorted_regions = sorted(region_costs.items(), key=lambda x: x[1])
    return sorted_regions[:3]


def calculate_monthly_projection(daily_transfer_cost, daily_compute_cost, storage_cost, serverless_cost):
    days_per_month = 30
    monthly_transfer = daily_transfer_cost * days_per_month
    monthly_compute = daily_compute_cost * days_per_month
    monthly_total = monthly_transfer + monthly_compute + storage_cost + serverless_cost
    annual_total = monthly_total * 12

    return {
        "monthly_transfer": monthly_transfer,
        "monthly_compute": monthly_compute,
        "monthly_storage": storage_cost,
        "monthly_serverless": serverless_cost,
        "monthly_total": monthly_total,
        "annual_total": annual_total
    }


def pricing_rows_to_dataframe(pricing_rows):
    return pd.DataFrame(
        [
            {
                "SERVICE_TYPE": r.SERVICE_TYPE,
                "CLOUD": r.CLOUD,
                "REGION": r.REGION,
                "UNIT": r.UNIT,
                "RATE": float(r.RATE) if r.RATE is not None else None,
                "CURRENCY": r.CURRENCY,
            }
            for r in pricing_rows
        ]
    )


def render_admin_manage_pricing(pricing_rows, updated_at):
    st.subheader("Admin: Manage Pricing")

    current_role = get_current_role()
    st.caption(f"Current role: {current_role or 'Unknown'}")

    if current_role not in ("SYSADMIN", "ACCOUNTADMIN"):
        st.error("Insufficient privileges. Switch to SYSADMIN or ACCOUNTADMIN to edit pricing.")
        return

    if updated_at:
        st.caption(f"Pricing data last updated: {updated_at}")

    pricing_df = pricing_rows_to_dataframe(pricing_rows)
    if pricing_df.empty:
        st.error("No pricing data found. Re-run deploy_all.sql to seed baseline pricing.")
        return

    edited_df = st.data_editor(
        pricing_df,
        num_rows="dynamic",
        use_container_width=True,
        hide_index=True,
    )

    col1, col2 = st.columns(2)
    with col1:
        save_clicked = st.button("Save Changes", type="primary")
    with col2:
        st.caption("Saving will overwrite the pricing table with the edited rows.")

    if not save_clicked:
        return

    required_cols = ["SERVICE_TYPE", "CLOUD", "REGION", "UNIT", "RATE", "CURRENCY"]
    missing = [c for c in required_cols if c not in edited_df.columns]
    if missing:
        st.error(f"Missing required columns: {', '.join(missing)}")
        return

    cleaned = edited_df[required_cols].copy()
    cleaned = cleaned.dropna(subset=["SERVICE_TYPE", "CLOUD", "REGION", "UNIT", "RATE", "CURRENCY"])

    if cleaned.empty:
        st.error("No valid rows to save after removing empty rows.")
        return

    cleaned["SERVICE_TYPE"] = cleaned["SERVICE_TYPE"].astype(str).str.strip().str.upper()
    cleaned["CLOUD"] = cleaned["CLOUD"].astype(str).str.strip().str.upper()
    cleaned["REGION"] = cleaned["REGION"].astype(str).str.strip()
    cleaned["UNIT"] = cleaned["UNIT"].astype(str).str.strip().str.upper()
    cleaned["CURRENCY"] = cleaned["CURRENCY"].astype(str).str.strip().str.upper()

    try:
        cleaned["RATE"] = cleaned["RATE"].astype(float)
    except Exception:
        st.error("RATE must be numeric for all rows.")
        return

    invalid_rates = cleaned[cleaned["RATE"] <= 0]
    if not invalid_rates.empty:
        st.error("RATE must be > 0 for all rows.")
        return

    non_credits = cleaned[cleaned["CURRENCY"] != "CREDITS"]
    if not non_credits.empty:
        st.error("CURRENCY must be CREDITS for all rows.")
        return

    key_cols = ["SERVICE_TYPE", "CLOUD", "REGION", "UNIT"]
    dupes = cleaned.duplicated(subset=key_cols, keep=False)
    if dupes.any():
        st.error("Duplicate rows detected for the key (SERVICE_TYPE, CLOUD, REGION, UNIT). Remove duplicates and try again.")
        return

    rows_for_insert = [
        (
            r.SERVICE_TYPE,
            r.CLOUD,
            r.REGION,
            r.UNIT,
            float(r.RATE),
            r.CURRENCY,
        )
        for r in cleaned.itertuples(index=False)
    ]

    try:
        tmp_df = session.create_dataframe(
            rows_for_insert,
            schema=["SERVICE_TYPE", "CLOUD", "REGION", "UNIT", "RATE", "CURRENCY"],
        )
        tmp_df.create_or_replace_temp_view("PRICING_UPDATES_TMP")

        session.sql(f"TRUNCATE TABLE {PRICING_TABLE_FQN}").collect()
        session.sql(
            f"""
            INSERT INTO {PRICING_TABLE_FQN} (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY)
            SELECT SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY
            FROM PRICING_UPDATES_TMP
            """
        ).collect()

        load_pricing.clear()
        st.success(f"Pricing saved. Rows written: {len(rows_for_insert)}")
    except SnowparkSQLException as e:
        st.error(f"Failed to save pricing: {str(e)}")
    except Exception as e:
        st.error(f"Unexpected error saving pricing: {str(e)}")


def results_to_csv_bytes(
    selected_dbs,
    total_size_tb,
    source_cloud,
    source_region,
    dest_cloud,
    dest_region,
    daily_change_pct,
    refresh_per_day,
    transfer_cost,
    compute_cost,
    storage_cost,
    serverless_cost,
    projections,
    price_per_credit,
):
    export_rows = [
        {"FIELD": "SOURCE_CLOUD", "VALUE": source_cloud},
        {"FIELD": "SOURCE_REGION", "VALUE": source_region},
        {"FIELD": "DEST_CLOUD", "VALUE": dest_cloud},
        {"FIELD": "DEST_REGION", "VALUE": dest_region},
        {"FIELD": "SELECTED_DATABASES", "VALUE": ", ".join(selected_dbs) if selected_dbs else ""},
        {"FIELD": "TOTAL_SIZE_TB", "VALUE": total_size_tb},
        {"FIELD": "DAILY_CHANGE_PCT", "VALUE": daily_change_pct},
        {"FIELD": "REFRESHES_PER_DAY", "VALUE": refresh_per_day},
        {"FIELD": "PRICE_PER_CREDIT_USD", "VALUE": price_per_credit},
        {"FIELD": "DAILY_TRANSFER_CREDITS", "VALUE": transfer_cost},
        {"FIELD": "DAILY_REPLICATION_COMPUTE_CREDITS", "VALUE": compute_cost},
        {"FIELD": "MONTHLY_STORAGE_CREDITS", "VALUE": storage_cost},
        {"FIELD": "MONTHLY_SERVERLESS_CREDITS", "VALUE": serverless_cost},
        {"FIELD": "MONTHLY_TOTAL_CREDITS", "VALUE": projections["monthly_total"]},
        {"FIELD": "ANNUAL_TOTAL_CREDITS", "VALUE": projections["annual_total"]},
        {"FIELD": "MONTHLY_TOTAL_USD", "VALUE": projections["monthly_total"] * price_per_credit},
        {"FIELD": "ANNUAL_TOTAL_USD", "VALUE": projections["annual_total"] * price_per_credit},
    ]
    export_df = pd.DataFrame(export_rows)
    return export_df.to_csv(index=False).encode("utf-8")


def main():
    st.set_page_config(page_title="Replication Cost Calculator", layout="wide")

    st.title("Replication / DR Cost Calculator (Business Critical)")

    st.info(
        "**Disclaimer:** This calculator provides cost estimates for budgeting purposes only. "
        "Actual costs may vary based on usage patterns, data compression, and other factors. "
        "Always monitor actual consumption via Snowflake's usage views."
    )

    st.caption("Business Critical pricing; rates managed via SQL by authorized users.")

    st.sidebar.header("Pricing Configuration")
    mode = st.sidebar.radio("Mode", ["Calculator", "Admin: Manage Pricing"])
    price_per_credit = st.sidebar.number_input(
        "Price per credit (USD)",
        min_value=0.50,
        max_value=10.00,
        value=4.00,
        step=0.10,
        help="Enter your contract price per credit. Standard list price is ~$2-4 depending on edition and region."
    )
    st.sidebar.caption(f"All USD costs calculated at ${price_per_credit:.2f}/credit")

    pricing_rows, updated_at = load_pricing()

    if not pricing_rows:
        st.error("No pricing data found. Please contact an administrator to configure pricing rates.")
        return

    if updated_at:
        st.caption(f"Pricing data last updated: {updated_at}")

    if mode == "Admin: Manage Pricing":
        render_admin_manage_pricing(pricing_rows, updated_at)
        return

    db_rows = load_db_metadata()
    db_options = {r.DATABASE_NAME: r for r in db_rows}

    selected_dbs = st.multiselect("Select databases", sorted(db_options.keys()))

    if not selected_dbs and st.session_state.get('calculation_attempted'):
        st.warning("Please select at least one database to calculate costs.")

    source_cloud, source_region = get_cloud_and_region()

    st.subheader("Destination Selection")

    available_clouds = sorted({r.CLOUD for r in pricing_rows})
    dest_cloud = st.selectbox(
        "Destination cloud provider",
        available_clouds,
        index=available_clouds.index(source_cloud) if source_cloud in available_clouds else 0,
        help="Select the destination cloud provider for replication"
    )

    cloud_regions = sorted({r.REGION for r in pricing_rows if r.CLOUD == dest_cloud})
    dest_region = st.selectbox(
        "Destination region",
        cloud_regions,
        index=0 if cloud_regions else None,
        help=f"Select the destination region in {dest_cloud}"
    ) if cloud_regions else None

    st.subheader("Replication Parameters")
    daily_change_pct = st.slider("Daily change rate (%)", 0.0, 20.0, 5.0, 0.5,
                                   help="Percentage of total data that changes each day")
    refresh_per_day = st.slider("Refreshes per day", 0.0, 24.0, 1.0, 0.5,
                                  help="Number of replication refresh operations per day")

    total_size_tb = float(sum(db_options[n].SIZE_TB for n in selected_dbs)) if selected_dbs else 0.0
    change_tb_per_refresh = total_size_tb * (daily_change_pct / 100.0)
    daily_transfer_tb = change_tb_per_refresh * refresh_per_day

    transfer_rate, _, transfer_est = cost_lookup(pricing_rows, "DATA_TRANSFER", source_cloud, source_region)
    compute_rate, _, compute_est = cost_lookup(pricing_rows, "REPLICATION_COMPUTE", source_cloud, source_region)
    storage_rate, _, storage_est = cost_lookup(pricing_rows, "STORAGE_TB_MONTH", dest_cloud, dest_region) if dest_region else (None, None, True)
    serverless_rate, _, serverless_est = cost_lookup(pricing_rows, "SERVERLESS_MAINT", dest_cloud, dest_region) if dest_region else (None, None, True)

    transfer_cost = (daily_transfer_tb * (transfer_rate or 0.0))
    compute_cost = (daily_transfer_tb * (compute_rate or 0.0))
    storage_cost = (total_size_tb * (storage_rate or 0.0))
    serverless_cost = (total_size_tb * (serverless_rate or 0.0))

    projections = calculate_monthly_projection(transfer_cost, compute_cost, storage_cost, serverless_cost)

    st.subheader("Cost Summary")

    col1, col2 = st.columns(2)
    with col1:
        st.write("**Source (detected):**")
        st.write(f"Cloud: {source_cloud}")
        st.write(f"Region: {source_region}")
        if transfer_rate:
            st.caption(f"Transfer rate: {transfer_rate} credits/TB")
        else:
            st.caption("No exact rate found - using fallback")
    with col2:
        st.write("**Destination:**")
        st.write(f"Cloud: {dest_cloud or '-'}")
        st.write(f"Region: {dest_region or '-'}")

    st.write(f"**Selected DB size:** {total_size_tb:.6f} TB ({total_size_tb * 1024:.3f} GB)")
    st.write(f"**Daily change:** {daily_change_pct}% = {daily_transfer_tb:.6f} TB/day")
    st.write(f"**Refreshes/day:** {refresh_per_day}")

    if total_size_tb > 0 and total_size_tb < 0.01:
        st.warning(
            f"Selected databases are very small ({total_size_tb * 1024 * 1024:.1f} MB). "
            "Costs may appear as $0.00. This is expected for small datasets."
        )

    if selected_dbs:
        with st.expander("Selected databases detail"):
            for db_name in selected_dbs:
                db_info = db_options[db_name]
                age_indicator = ""
                if hasattr(db_info, 'AS_OF'):
                    age_indicator = f" (as of {db_info.AS_OF})"
                st.write(f"- {db_name}: {float(db_info.SIZE_TB):.3f} TB{age_indicator}")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Daily Costs")
        st.table(
            [
                {
                    "Component": "Data Transfer",
                    "Credits": f"{transfer_cost:.4f}",
                    "USD": f"${transfer_cost * price_per_credit:.4f}",
                    "Estimate": transfer_est
                },
                {
                    "Component": "Replication Compute",
                    "Credits": f"{compute_cost:.4f}",
                    "USD": f"${compute_cost * price_per_credit:.4f}",
                    "Estimate": compute_est
                },
            ]
        )

    with col2:
        st.subheader("Monthly Costs")
        st.table(
            [
                {
                    "Component": "Transfer (30d)",
                    "Credits": f"{projections['monthly_transfer']:.4f}",
                    "USD": f"${projections['monthly_transfer'] * price_per_credit:.4f}"
                },
                {
                    "Component": "Compute (30d)",
                    "Credits": f"{projections['monthly_compute']:.4f}",
                    "USD": f"${projections['monthly_compute'] * price_per_credit:.4f}"
                },
                {
                    "Component": "Storage",
                    "Credits": f"{storage_cost:.4f}",
                    "USD": f"${storage_cost * price_per_credit:.4f}",
                    "Estimate": storage_est
                },
                {
                    "Component": "Serverless Maint",
                    "Credits": f"{serverless_cost:.4f}",
                    "USD": f"${serverless_cost * price_per_credit:.4f}",
                    "Estimate": serverless_est
                },
            ]
        )

    col_m1, col_m2 = st.columns(2)
    with col_m1:
        st.metric("Monthly Total", f"{projections['monthly_total']:.2f} credits")
        st.metric("Annual Credits", f"{projections['annual_total']:.2f} credits")
    with col_m2:
        monthly_usd = projections['monthly_total'] * price_per_credit
        annual_usd = projections['annual_total'] * price_per_credit
        st.metric("Monthly Total (USD)", f"${monthly_usd:,.2f}")
        st.metric("Annual Projection (USD)", f"${annual_usd:,.2f}")

    if pricing_rows:
        st.subheader("Cost Optimization")
        lowest_regions = find_lowest_cost_regions(pricing_rows, ["DATA_TRANSFER", "REPLICATION_COMPUTE", "STORAGE_TB_MONTH"])
        if lowest_regions:
            st.write("**Lowest cost destination regions:**")
            for region, cost in lowest_regions:
                st.write(f"- {region}: {cost:.2f} credits per TB (combined)")

    st.subheader("Details")
    st.write("Data transfer and compute costs shown as daily values based on change rate.")
    st.write("Storage and serverless maintenance are monthly costs based on total database size.")
    st.write("Values marked as estimates rely on fallback rates when exact region match is unavailable.")

    csv_bytes = results_to_csv_bytes(
        selected_dbs=selected_dbs,
        total_size_tb=total_size_tb,
        source_cloud=source_cloud,
        source_region=source_region,
        dest_cloud=dest_cloud,
        dest_region=dest_region,
        daily_change_pct=daily_change_pct,
        refresh_per_day=refresh_per_day,
        transfer_cost=transfer_cost,
        compute_cost=compute_cost,
        storage_cost=storage_cost,
        serverless_cost=serverless_cost,
        projections=projections,
        price_per_credit=price_per_credit,
    )
    st.download_button(
        "Download CSV",
        data=csv_bytes,
        file_name="replication_cost_estimate.csv",
        mime="text/csv",
        disabled=not bool(selected_dbs),
        help="Select at least one database to enable export.",
    )

    st.session_state['calculation_attempted'] = True


if __name__ == "__main__":
    main()
