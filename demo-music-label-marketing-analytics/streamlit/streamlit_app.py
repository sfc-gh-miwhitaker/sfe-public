from snowflake.snowpark.context import get_active_session
import streamlit as st
import pandas as pd

session = get_active_session()

st.set_page_config(page_title="Apex Records Marketing", page_icon="🎵", layout="wide")

PAGES = [
    "📝 Budget Entry",
    "📊 Budget vs. Actual",
    "🎯 Campaign Performance",
    "🎤 Artist Profile",
    "⚠️ Anomaly Alerts",
]

st.sidebar.title("Apex Records")
st.sidebar.caption("Marketing Analytics")
page = st.sidebar.radio("Navigate", PAGES, label_visibility="collapsed")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

@st.cache_data(ttl=300)
def run_query(sql):
    return session.sql(sql).to_pandas()


def fmt_currency(val):
    if val is None or pd.isna(val):
        return "—"
    return f"${val:,.2f}"


def fmt_number(val):
    if val is None or pd.isna(val):
        return "—"
    return f"{val:,.0f}"


# ---------------------------------------------------------------------------
# Page 1: Budget Entry (the "spreadsheet" page)
# ---------------------------------------------------------------------------
if page == PAGES[0]:
    st.title("Budget Entry")
    st.caption(
        "Edit budget allocations just like a spreadsheet. "
        "Changes write directly to Snowflake when you click Save."
    )

    artists = run_query(
        "SELECT DISTINCT artist_name FROM DIM_ARTIST ORDER BY artist_name"
    )
    artist_filter = st.selectbox(
        "Filter by artist", ["All Artists"] + artists["ARTIST_NAME"].tolist()
    )

    where = ""
    if artist_filter != "All Artists":
        safe = artist_filter.replace("'", "''")
        where = f"AND a.artist_name = '{safe}'"

    budget_df = run_query(f"""
        SELECT
            b.budget_id,
            a.artist_name,
            b.campaign_id,
            b.channel,
            b.territory,
            b.budget_period,
            b.allocated_amount,
            b.notes
        FROM RAW_MARKETING_BUDGET b
        JOIN RAW_ARTISTS a ON b.artist_id = a.artist_id
        WHERE b.budget_period >= DATE_TRUNC('month', CURRENT_DATE())
        {where}
        ORDER BY a.artist_name, b.budget_period, b.channel
        LIMIT 200
    """)

    if budget_df.empty:
        st.info("No upcoming budget entries found.")
    else:
        edited = st.data_editor(
            budget_df,
            column_config={
                "BUDGET_ID": st.column_config.NumberColumn("ID", disabled=True),
                "ARTIST_NAME": st.column_config.TextColumn("Artist", disabled=True),
                "CAMPAIGN_ID": st.column_config.NumberColumn("Campaign", disabled=True),
                "CHANNEL": st.column_config.TextColumn("Channel", disabled=True),
                "TERRITORY": st.column_config.TextColumn("Territory", disabled=True),
                "BUDGET_PERIOD": st.column_config.DateColumn("Period", disabled=True),
                "ALLOCATED_AMOUNT": st.column_config.NumberColumn(
                    "Budget ($)", min_value=0, format="$%.2f"
                ),
                "NOTES": st.column_config.TextColumn("Notes"),
            },
            use_container_width=True,
            num_rows="fixed",
            key="budget_editor",
        )

        if st.button("💾 Save Changes", type="primary"):
            changes = 0
            for idx, row in edited.iterrows():
                orig = budget_df.iloc[idx]
                if (
                    row["ALLOCATED_AMOUNT"] != orig["ALLOCATED_AMOUNT"]
                    or row["NOTES"] != orig["NOTES"]
                ):
                    notes_val = str(row["NOTES"]).replace("'", "''") if pd.notna(row["NOTES"]) else ""
                    session.sql(f"""
                        UPDATE RAW_MARKETING_BUDGET
                        SET allocated_amount = {row['ALLOCATED_AMOUNT']},
                            notes = '{notes_val}',
                            last_updated_by = CURRENT_USER()
                        WHERE budget_id = {row['BUDGET_ID']}
                    """).collect()
                    changes += 1
            if changes > 0:
                st.success(f"Saved {changes} change(s) to Snowflake.")
                st.cache_data.clear()
            else:
                st.info("No changes detected.")


# ---------------------------------------------------------------------------
# Page 2: Budget vs. Actual
# ---------------------------------------------------------------------------
elif page == PAGES[1]:
    st.title("Budget vs. Actual")

    summary = run_query("""
        SELECT
            SUM(monthly_budget) AS total_budget,
            SUM(actual_spend)   AS total_spend
        FROM FACT_MARKETING_SPEND
        WHERE spend_date >= DATE_TRUNC('quarter', CURRENT_DATE())
    """)

    c1, c2, c3 = st.columns(3)
    total_budget = summary["TOTAL_BUDGET"].iloc[0] or 0
    total_spend = summary["TOTAL_SPEND"].iloc[0] or 0
    variance = total_spend - total_budget

    c1.metric("Budget (QTD)", fmt_currency(total_budget))
    c2.metric("Actual Spend (QTD)", fmt_currency(total_spend))
    c3.metric(
        "Variance",
        fmt_currency(abs(variance)),
        delta=f"{'Over' if variance > 0 else 'Under'} budget",
        delta_color="inverse",
    )

    by_channel = run_query("""
        SELECT
            channel,
            SUM(monthly_budget) AS budget,
            SUM(actual_spend)   AS actual,
            SUM(actual_spend) - SUM(monthly_budget) AS variance
        FROM FACT_MARKETING_SPEND
        WHERE spend_date >= DATEADD('month', -3, CURRENT_DATE())
        GROUP BY channel
        ORDER BY actual DESC
    """)
    st.subheader("By Channel (Last 3 Months)")
    st.dataframe(
        by_channel.style.format(
            {"BUDGET": "${:,.0f}", "ACTUAL": "${:,.0f}", "VARIANCE": "${:,.0f}"}
        ),
        use_container_width=True,
    )

    monthly = run_query("""
        SELECT
            DATE_TRUNC('month', spend_date) AS month,
            SUM(monthly_budget) AS budget,
            SUM(actual_spend)   AS actual
        FROM FACT_MARKETING_SPEND
        GROUP BY DATE_TRUNC('month', spend_date)
        ORDER BY month
    """)
    st.subheader("Monthly Trend")
    st.line_chart(monthly.set_index("MONTH")[["BUDGET", "ACTUAL"]])


# ---------------------------------------------------------------------------
# Page 3: Campaign Performance
# ---------------------------------------------------------------------------
elif page == PAGES[2]:
    st.title("Campaign Performance")

    kpi = run_query("""
        SELECT
            COUNT(campaign_id) AS total_campaigns,
            ROUND(AVG(roi), 3)  AS avg_roi,
            ROUND(AVG(streams_per_dollar), 0) AS avg_streams_per_dollar,
            SUM(total_spend)    AS total_invested
        FROM FACT_CAMPAIGN_PERFORMANCE
        WHERE total_spend > 0
    """)
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Campaigns", fmt_number(kpi["TOTAL_CAMPAIGNS"].iloc[0]))
    c2.metric("Avg ROI", f"{kpi['AVG_ROI'].iloc[0]:.2f}x" if pd.notna(kpi["AVG_ROI"].iloc[0]) else "—")
    c3.metric("Streams / $", fmt_number(kpi["AVG_STREAMS_PER_DOLLAR"].iloc[0]))
    c4.metric("Total Invested", fmt_currency(kpi["TOTAL_INVESTED"].iloc[0]))

    sort_col = st.selectbox("Sort by", ["ROI", "STREAMS_PER_DOLLAR", "TOTAL_SPEND"], index=0)
    top = run_query(f"""
        SELECT
            campaign_name,
            a.artist_name,
            f.resolved_campaign_type AS campaign_type,
            f.territory,
            total_spend,
            total_streams_during_campaign AS streams,
            total_royalties_during_campaign AS royalties,
            roi,
            streams_per_dollar
        FROM FACT_CAMPAIGN_PERFORMANCE f
        JOIN DIM_ARTIST a ON f.artist_id = a.artist_id
        WHERE total_spend > 0
        ORDER BY {sort_col} DESC NULLS LAST
        LIMIT 25
    """)
    st.subheader(f"Top 25 Campaigns by {sort_col.replace('_', ' ').title()}")
    st.dataframe(top, use_container_width=True)

    by_type = run_query("""
        SELECT
            resolved_campaign_type AS campaign_type,
            COUNT(campaign_id) AS campaigns,
            ROUND(AVG(roi), 3) AS avg_roi,
            ROUND(AVG(streams_per_dollar), 0) AS avg_streams_per_dollar,
            SUM(total_spend) AS total_spend
        FROM FACT_CAMPAIGN_PERFORMANCE
        WHERE total_spend > 0
          AND resolved_campaign_type IS NOT NULL
        GROUP BY resolved_campaign_type
        ORDER BY avg_roi DESC
    """)
    st.subheader("Performance by Campaign Type")
    st.bar_chart(by_type.set_index("CAMPAIGN_TYPE")["AVG_ROI"])


# ---------------------------------------------------------------------------
# Page 4: Artist Marketing Profile
# ---------------------------------------------------------------------------
elif page == PAGES[3]:
    st.title("Artist Marketing Profile")

    artists = run_query(
        "SELECT artist_name FROM DIM_ARTIST ORDER BY artist_name"
    )
    selected = st.selectbox("Select Artist", artists["ARTIST_NAME"].tolist())
    safe = selected.replace("'", "''")

    profile = run_query(f"""
        SELECT
            a.artist_name, a.genre, a.territory, a.days_on_roster,
            COALESCE(s.total_spend, 0) AS total_marketing_spend,
            COALESCE(st.total_streams, 0) AS total_streams,
            COALESCE(r.total_royalties, 0) AS total_royalties,
            CASE WHEN COALESCE(s.total_spend, 0) > 0
                 THEN ROUND(COALESCE(r.total_royalties, 0) / s.total_spend, 3)
                 ELSE NULL END AS overall_roi,
            CASE WHEN COALESCE(s.total_spend, 0) > 0
                 THEN ROUND(COALESCE(st.total_streams, 0) / s.total_spend, 0)
                 ELSE NULL END AS overall_streams_per_dollar
        FROM DIM_ARTIST a
        LEFT JOIN (
            SELECT artist_id, SUM(amount) AS total_spend
            FROM RAW_MARKETING_SPEND GROUP BY artist_id
        ) s ON a.artist_id = s.artist_id
        LEFT JOIN (
            SELECT artist_id, SUM(stream_count) AS total_streams
            FROM RAW_STREAMS GROUP BY artist_id
        ) st ON a.artist_id = st.artist_id
        LEFT JOIN (
            SELECT artist_id, SUM(amount) AS total_royalties
            FROM RAW_ROYALTIES GROUP BY artist_id
        ) r ON a.artist_id = r.artist_id
        WHERE a.artist_name = '{safe}'
    """)

    if not profile.empty:
        p = profile.iloc[0]
        st.markdown(f"**{p['ARTIST_NAME']}** · {p['GENRE']} · {p['TERRITORY']} · {p['DAYS_ON_ROSTER']} days on roster")

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Marketing Spend", fmt_currency(p["TOTAL_MARKETING_SPEND"]))
        c2.metric("Total Streams", fmt_number(p["TOTAL_STREAMS"]))
        c3.metric("Total Royalties", fmt_currency(p["TOTAL_ROYALTIES"]))
        c4.metric("ROI", f"{p['OVERALL_ROI']:.2f}x" if pd.notna(p["OVERALL_ROI"]) else "—")

    campaigns = run_query(f"""
        SELECT
            f.campaign_name, f.resolved_campaign_type AS type,
            f.channel, f.total_spend, f.roi, f.streams_per_dollar,
            f.total_streams_during_campaign AS streams,
            f.total_royalties_during_campaign AS royalties
        FROM FACT_CAMPAIGN_PERFORMANCE f
        JOIN DIM_ARTIST a ON f.artist_id = a.artist_id
        WHERE a.artist_name = '{safe}'
        ORDER BY f.total_spend DESC
    """)
    st.subheader("Campaign History")
    st.dataframe(campaigns, use_container_width=True)

    monthly_streams = run_query(f"""
        SELECT
            DATE_TRUNC('month', s.stream_date) AS month,
            s.platform,
            SUM(s.stream_count) AS streams
        FROM FACT_STREAMS s
        JOIN DIM_ARTIST a ON s.artist_id = a.artist_id
        WHERE a.artist_name = '{safe}'
        GROUP BY DATE_TRUNC('month', s.stream_date), s.platform
        ORDER BY month
    """)
    if not monthly_streams.empty:
        st.subheader("Monthly Streams by Platform")
        pivot = monthly_streams.pivot_table(
            index="MONTH", columns="PLATFORM", values="STREAMS", fill_value=0
        )
        st.area_chart(pivot)


# ---------------------------------------------------------------------------
# Page 5: Anomaly Alerts
# ---------------------------------------------------------------------------
elif page == PAGES[4]:
    st.title("Anomaly Alerts")
    st.caption("Campaigns exceeding budget thresholds or underperforming relative to peers.")

    alerts = run_query("""
        SELECT
            campaign_name,
            artist_name,
            channel,
            territory,
            budget_period,
            monthly_budget,
            actual_spend,
            variance,
            pct_of_budget,
            alert_status
        FROM V_BUDGET_ALERTS
        WHERE alert_status IN ('CRITICAL', 'WARNING')
        ORDER BY
            CASE alert_status WHEN 'CRITICAL' THEN 1 ELSE 2 END,
            variance DESC
        LIMIT 50
    """)

    critical = alerts[alerts["ALERT_STATUS"] == "CRITICAL"]
    warning = alerts[alerts["ALERT_STATUS"] == "WARNING"]

    c1, c2, c3 = st.columns(3)
    c1.metric("Critical", len(critical), delta="over 120% of budget", delta_color="inverse")
    c2.metric("Warning", len(warning), delta="over 100% of budget", delta_color="inverse")
    c3.metric("Total Alerts", len(alerts))

    if not critical.empty:
        st.subheader("🔴 Critical — Over 120% of Budget")
        st.dataframe(
            critical[["CAMPAIGN_NAME", "ARTIST_NAME", "CHANNEL", "MONTHLY_BUDGET",
                       "ACTUAL_SPEND", "VARIANCE", "PCT_OF_BUDGET"]],
            use_container_width=True,
        )

    if not warning.empty:
        st.subheader("🟡 Warning — Over 100% of Budget")
        st.dataframe(
            warning[["CAMPAIGN_NAME", "ARTIST_NAME", "CHANNEL", "MONTHLY_BUDGET",
                      "ACTUAL_SPEND", "VARIANCE", "PCT_OF_BUDGET"]],
            use_container_width=True,
        )

    underperformers = run_query("""
        SELECT
            campaign_name,
            a.artist_name,
            resolved_campaign_type AS type,
            channel,
            total_spend,
            roi,
            streams_per_dollar
        FROM FACT_CAMPAIGN_PERFORMANCE f
        JOIN DIM_ARTIST a ON f.artist_id = a.artist_id
        WHERE total_spend > 1000
          AND (roi < 0.1 OR streams_per_dollar < 50)
        ORDER BY roi ASC NULLS LAST
        LIMIT 20
    """)
    if not underperformers.empty:
        st.subheader("📉 Underperforming Campaigns (Low ROI or Low Streams/$)")
        st.dataframe(underperformers, use_container_width=True)

    st.divider()
    st.subheader("Recent Alert Log")
    log = run_query("""
        SELECT alert_timestamp, campaign_name, artist_name, channel,
               monthly_budget, actual_spend, variance, alert_status
        FROM BUDGET_ALERT_LOG
        ORDER BY alert_timestamp DESC
        LIMIT 25
    """)
    if not log.empty:
        st.dataframe(log, use_container_width=True)
    else:
        st.info("No alerts logged yet. The budget alert task runs hourly.")
