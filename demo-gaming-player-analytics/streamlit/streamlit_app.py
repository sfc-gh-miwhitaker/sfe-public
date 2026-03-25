from snowflake.snowpark.context import get_active_session
import streamlit as st
import pandas as pd

session = get_active_session()

st.set_page_config(page_title="Pixel Forge Analytics", page_icon="🎮", layout="wide")

PAGES = [
    "🎯 Player Cohorts",
    "📈 Engagement Trends",
    "⚠️ Churn Risk",
    "💬 Feedback Analysis",
]

st.sidebar.title("Pixel Forge Studios")
st.sidebar.caption("Player Analytics")
page = st.sidebar.radio("Navigate", PAGES, label_visibility="collapsed")


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


def fmt_pct(val):
    if val is None or pd.isna(val):
        return "—"
    return f"{val:.1%}"


# ---------------------------------------------------------------------------
# Page 1: Player Cohorts
# ---------------------------------------------------------------------------
if page == PAGES[0]:
    st.title("Player Cohorts")
    st.caption(
        "AI-classified player segments based on spending, engagement, and recency."
    )

    cohort_summary = run_query("""
        SELECT
            ai_player_cohort AS cohort,
            COUNT(*) AS players,
            ROUND(AVG(total_spent), 2) AS avg_lifetime_spend,
            ROUND(AVG(active_days_last_30), 1) AS avg_active_days_30d,
            ROUND(AVG(avg_daily_playtime_minutes), 1) AS avg_playtime_min,
            ROUND(AVG(dau_mau_ratio), 3) AS avg_stickiness
        FROM DIM_PLAYERS
        GROUP BY ai_player_cohort
        ORDER BY avg_lifetime_spend DESC
    """)

    c1, c2, c3, c4 = st.columns(4)
    for i, row in cohort_summary.iterrows():
        col = [c1, c2, c3, c4][i % 4]
        col.metric(
            row["COHORT"],
            f"{row['PLAYERS']} players",
            f"Avg LTV: {fmt_currency(row['AVG_LIFETIME_SPEND'])}",
        )

    st.subheader("Cohort Comparison")
    st.dataframe(
        cohort_summary.rename(columns={
            "COHORT": "Cohort",
            "PLAYERS": "Players",
            "AVG_LIFETIME_SPEND": "Avg LTV ($)",
            "AVG_ACTIVE_DAYS_30D": "Avg Active Days (30d)",
            "AVG_PLAYTIME_MIN": "Avg Playtime (min/day)",
            "AVG_STICKINESS": "Stickiness (DAU/MAU)",
        }),
        use_container_width=True,
        hide_index=True,
    )

    st.subheader("Cohort by Platform")
    platform_cohort = run_query("""
        SELECT platform, ai_player_cohort AS cohort, COUNT(*) AS players
        FROM DIM_PLAYERS
        GROUP BY platform, ai_player_cohort
        ORDER BY platform, cohort
    """)
    if not platform_cohort.empty:
        pivot = platform_cohort.pivot_table(
            index="PLATFORM", columns="COHORT", values="PLAYERS", fill_value=0
        )
        st.bar_chart(pivot)

    st.subheader("Cohort by Acquisition Source")
    acq_cohort = run_query("""
        SELECT acquisition_source, ai_player_cohort AS cohort, COUNT(*) AS players
        FROM DIM_PLAYERS
        GROUP BY acquisition_source, ai_player_cohort
        ORDER BY acquisition_source, cohort
    """)
    if not acq_cohort.empty:
        pivot_acq = acq_cohort.pivot_table(
            index="ACQUISITION_SOURCE", columns="COHORT", values="PLAYERS", fill_value=0
        )
        st.bar_chart(pivot_acq)


# ---------------------------------------------------------------------------
# Page 2: Engagement Trends
# ---------------------------------------------------------------------------
elif page == PAGES[1]:
    st.title("Engagement Trends")
    st.caption("Daily active players, session counts, and revenue over time.")

    kpi = run_query("""
        SELECT
            SUM(daily_active_players) AS total_dau_today,
            SUM(total_sessions) AS total_sessions_today,
            SUM(daily_revenue) AS revenue_today
        FROM FACT_DAILY_ENGAGEMENT
        WHERE event_date = (SELECT MAX(event_date) FROM FACT_DAILY_ENGAGEMENT)
    """)

    c1, c2, c3 = st.columns(3)
    c1.metric("DAU (Latest)", fmt_number(kpi["TOTAL_DAU_TODAY"].iloc[0]))
    c2.metric("Sessions (Latest)", fmt_number(kpi["TOTAL_SESSIONS_TODAY"].iloc[0]))
    c3.metric("Revenue (Latest)", fmt_currency(kpi["REVENUE_TODAY"].iloc[0]))

    st.subheader("DAU by Cohort (Last 30 Days)")
    dau_trend = run_query("""
        SELECT event_date, ai_player_cohort AS cohort, daily_active_players AS dau
        FROM FACT_DAILY_ENGAGEMENT
        WHERE event_date >= DATEADD('day', -30, CURRENT_DATE())
        ORDER BY event_date
    """)
    if not dau_trend.empty:
        pivot_dau = dau_trend.pivot_table(
            index="EVENT_DATE", columns="COHORT", values="DAU", fill_value=0
        )
        st.area_chart(pivot_dau)

    st.subheader("Daily Revenue by Cohort (Last 30 Days)")
    rev_trend = run_query("""
        SELECT event_date, ai_player_cohort AS cohort, daily_revenue AS revenue
        FROM FACT_DAILY_ENGAGEMENT
        WHERE event_date >= DATEADD('day', -30, CURRENT_DATE())
        ORDER BY event_date
    """)
    if not rev_trend.empty:
        pivot_rev = rev_trend.pivot_table(
            index="EVENT_DATE", columns="COHORT", values="REVENUE", fill_value=0
        )
        st.bar_chart(pivot_rev)

    st.subheader("Average Session Length by Cohort")
    session_len = run_query("""
        SELECT ai_player_cohort AS cohort, ROUND(AVG(avg_playtime_minutes), 1) AS avg_minutes
        FROM FACT_DAILY_ENGAGEMENT
        WHERE event_date >= DATEADD('day', -30, CURRENT_DATE())
        GROUP BY ai_player_cohort
        ORDER BY avg_minutes DESC
    """)
    st.dataframe(
        session_len.rename(columns={"COHORT": "Cohort", "AVG_MINUTES": "Avg Session (min)"}),
        use_container_width=True,
        hide_index=True,
    )


# ---------------------------------------------------------------------------
# Page 3: Churn Risk
# ---------------------------------------------------------------------------
elif page == PAGES[2]:
    st.title("Churn Risk Dashboard")
    st.caption("Players at risk of leaving, segmented by value and recency.")

    risk_summary = run_query("""
        SELECT
            churn_risk_level,
            COUNT(*) AS players,
            ROUND(AVG(lifetime_spend), 2) AS avg_ltv,
            ROUND(AVG(days_since_last_active), 0) AS avg_days_inactive
        FROM FACT_PLAYER_LIFETIME
        GROUP BY churn_risk_level
        ORDER BY CASE churn_risk_level
            WHEN 'High' THEN 1 WHEN 'Medium' THEN 2
            WHEN 'Low' THEN 3 ELSE 4 END
    """)

    c1, c2, c3 = st.columns(3)
    for i, row in risk_summary.iterrows():
        col = [c1, c2, c3][i % 3]
        label = row["CHURN_RISK_LEVEL"]
        icon = {"High": "🔴", "Medium": "🟡", "Low": "🟢"}.get(label, "⚪")
        col.metric(
            f"{icon} {label} Risk",
            f"{row['PLAYERS']} players",
            f"Avg LTV: {fmt_currency(row['AVG_LTV'])}",
        )

    st.subheader("Value-Risk Matrix")
    value_risk = run_query("""
        SELECT
            value_risk_segment,
            COUNT(*) AS players,
            ROUND(AVG(lifetime_spend), 2) AS avg_ltv,
            ROUND(AVG(sessions_last_30), 0) AS avg_sessions_30d
        FROM FACT_PLAYER_LIFETIME
        GROUP BY value_risk_segment
        ORDER BY avg_ltv DESC
    """)
    st.dataframe(
        value_risk.rename(columns={
            "VALUE_RISK_SEGMENT": "Segment",
            "PLAYERS": "Players",
            "AVG_LTV": "Avg LTV ($)",
            "AVG_SESSIONS_30D": "Avg Sessions (30d)",
        }),
        use_container_width=True,
        hide_index=True,
    )

    st.subheader("High-Value At-Risk Players")
    at_risk = run_query("""
        SELECT
            p.username,
            p.platform,
            p.country,
            f.lifetime_spend,
            f.lifetime_sessions,
            f.days_since_last_active,
            f.churn_risk_level,
            f.dominant_feedback_sentiment
        FROM FACT_PLAYER_LIFETIME f
        JOIN DIM_PLAYERS p ON f.player_id = p.player_id
        WHERE f.value_risk_segment = 'High Value At Risk'
        ORDER BY f.lifetime_spend DESC
        LIMIT 25
    """)
    if not at_risk.empty:
        st.dataframe(at_risk, use_container_width=True)
    else:
        st.info("No high-value at-risk players found.")

    st.subheader("Churn Risk by Cohort")
    churn_cohort = run_query("""
        SELECT
            ai_player_cohort AS cohort,
            churn_risk_level AS risk,
            COUNT(*) AS players
        FROM FACT_PLAYER_LIFETIME
        GROUP BY ai_player_cohort, churn_risk_level
        ORDER BY cohort, risk
    """)
    if not churn_cohort.empty:
        pivot_churn = churn_cohort.pivot_table(
            index="COHORT", columns="RISK", values="PLAYERS", fill_value=0
        )
        st.bar_chart(pivot_churn)


# ---------------------------------------------------------------------------
# Page 4: Feedback Analysis
# ---------------------------------------------------------------------------
elif page == PAGES[3]:
    st.title("Feedback Analysis")
    st.caption("AI-enriched player feedback with sentiment, topic, and urgency extraction.")

    sentiment_summary = run_query("""
        SELECT ai_sentiment AS sentiment, COUNT(*) AS count
        FROM DT_FEEDBACK_ENRICHED
        GROUP BY ai_sentiment
        ORDER BY count DESC
    """)

    c1, c2, c3 = st.columns(3)
    for i, row in sentiment_summary.iterrows():
        col = [c1, c2, c3][i % 3]
        icon = {"Positive": "😊", "Negative": "😞", "Neutral": "😐"}.get(
            row["SENTIMENT"], "❓"
        )
        col.metric(f"{icon} {row['SENTIMENT']}", fmt_number(row["COUNT"]))

    source_filter = st.selectbox(
        "Filter by source",
        ["All Sources", "App Store Review", "Support Ticket", "In-Game Survey", "Discord"],
    )

    where_clause = ""
    if source_filter != "All Sources":
        safe_source = source_filter.replace("'", "''")
        where_clause = f"AND feedback_source = '{safe_source}'"

    st.subheader("Top Feedback Topics")
    topics = run_query(f"""
        SELECT
            feedback_topic AS topic,
            ai_sentiment AS sentiment,
            COUNT(*) AS count
        FROM DT_FEEDBACK_ENRICHED
        WHERE feedback_topic IS NOT NULL {where_clause}
        GROUP BY feedback_topic, ai_sentiment
        ORDER BY count DESC
        LIMIT 30
    """)
    if not topics.empty:
        pivot_topics = topics.pivot_table(
            index="TOPIC", columns="SENTIMENT", values="COUNT", fill_value=0
        )
        st.bar_chart(pivot_topics)

    st.subheader("Urgent Feedback (HIGH Priority)")
    urgent = run_query(f"""
        SELECT
            feedback_text,
            ai_sentiment,
            feedback_topic,
            feedback_source,
            submitted_at
        FROM DT_FEEDBACK_ENRICHED
        WHERE feedback_urgency = 'HIGH' {where_clause}
        ORDER BY submitted_at DESC
        LIMIT 20
    """)
    if not urgent.empty:
        st.dataframe(urgent, use_container_width=True)
    else:
        st.info("No high-urgency feedback found.")

    st.subheader("Feature Requests")
    features = run_query(f"""
        SELECT
            feature_request,
            COUNT(*) AS mentions,
            MODE(ai_sentiment) AS typical_sentiment
        FROM DT_FEEDBACK_ENRICHED
        WHERE feature_request IS NOT NULL
          AND feature_request != 'None' {where_clause}
        GROUP BY feature_request
        ORDER BY mentions DESC
        LIMIT 15
    """)
    if not features.empty:
        st.dataframe(
            features.rename(columns={
                "FEATURE_REQUEST": "Feature Request",
                "MENTIONS": "Mentions",
                "TYPICAL_SENTIMENT": "Typical Sentiment",
            }),
            use_container_width=True,
            hide_index=True,
        )
    else:
        st.info("No feature requests extracted yet.")

    st.subheader("Recent Feedback")
    recent = run_query(f"""
        SELECT
            feedback_text,
            ai_sentiment,
            feedback_topic,
            feedback_urgency,
            feedback_source,
            submitted_at
        FROM DT_FEEDBACK_ENRICHED
        WHERE 1=1 {where_clause}
        ORDER BY submitted_at DESC
        LIMIT 25
    """)
    st.dataframe(recent, use_container_width=True)
