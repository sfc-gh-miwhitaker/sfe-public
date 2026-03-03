"""
Casino Campaign Recommendation Engine -- Streamlit Dashboard
Generated from prompt: "Create an interactive dashboard with campaign targeting
  and player lookalike tabs."
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
"""

from snowflake.snowpark.context import get_active_session
import streamlit as st

st.set_page_config(
    page_title="Campaign Engine",
    page_icon="🎰",
    layout="wide",
)

session = get_active_session()

PIPELINE_CSS = """
<style>
.pipeline-step {
    background: linear-gradient(135deg, #1a1f36 0%, #252b48 100%);
    border: 1px solid #3b4574;
    border-radius: 10px;
    padding: 14px 10px;
    text-align: center;
    min-height: 90px;
    display: flex;
    flex-direction: column;
    justify-content: center;
}
.pipeline-step .step-icon { font-size: 24px; margin-bottom: 4px; }
.pipeline-step .step-label {
    font-size: 11px; font-weight: 600; color: #a8b4e0;
    text-transform: uppercase; letter-spacing: 0.5px;
}
.pipeline-step .step-detail {
    font-size: 12px; color: #e2e8f0; margin-top: 2px;
}
.pipeline-arrow {
    display: flex; align-items: center; justify-content: center;
    font-size: 22px; color: #4a72ff; min-height: 90px;
}
</style>
"""
st.markdown(PIPELINE_CSS, unsafe_allow_html=True)


def pipeline_step(icon, label, detail=""):
    detail_html = f'<div class="step-detail">{detail}</div>' if detail else ""
    return (
        f'<div class="pipeline-step">'
        f'<div class="step-icon">{icon}</div>'
        f'<div class="step-label">{label}</div>'
        f'{detail_html}'
        f'</div>'
    )


def pipeline_arrow():
    return '<div class="pipeline-arrow">▸</div>'


SCORE_AUDIENCE_SQL = """
WITH scored AS (
    SELECT
        f.player_id, p.name, p.loyalty_tier,
        f.avg_daily_wager, f.session_frequency, f.avg_session_duration,
        f.win_rate, f.slots_pct, f.table_pct, f.poker_pct, f.sportsbook_pct,
        f.weekend_pct, f.mobile_pct, f.days_since_last_visit, f.lifetime_wagered,
        f.loyalty_tier_num, f.avg_bet_size, f.visit_consistency, f.game_diversity,
        '{campaign_type}' AS campaign_type
    FROM CAMPAIGN_ENGINE.DT_PLAYER_FEATURES f
    JOIN CAMPAIGN_ENGINE.RAW_PLAYERS p ON f.player_id = p.player_id
),
predictions AS (
    SELECT
        player_id, name, loyalty_tier,
        avg_daily_wager, lifetime_wagered, days_since_last_visit,
        CAMPAIGN_ENGINE.CAMPAIGN_RESPONSE_MODEL!PREDICT(
            INPUT_DATA => OBJECT_CONSTRUCT(
                'AVG_DAILY_WAGER',       avg_daily_wager,
                'SESSION_FREQUENCY',     session_frequency,
                'AVG_SESSION_DURATION',  avg_session_duration,
                'WIN_RATE',              win_rate,
                'SLOTS_PCT',             slots_pct,
                'TABLE_PCT',             table_pct,
                'POKER_PCT',             poker_pct,
                'SPORTSBOOK_PCT',        sportsbook_pct,
                'WEEKEND_PCT',           weekend_pct,
                'MOBILE_PCT',            mobile_pct,
                'DAYS_SINCE_LAST_VISIT', days_since_last_visit,
                'LIFETIME_WAGERED',      lifetime_wagered,
                'LOYALTY_TIER_NUM',      loyalty_tier_num,
                'AVG_BET_SIZE',          avg_bet_size,
                'VISIT_CONSISTENCY',     visit_consistency,
                'GAME_DIVERSITY',        game_diversity,
                'CAMPAIGN_TYPE',         campaign_type
            )
        ) AS prediction
    FROM scored
)
SELECT
    player_id           AS PLAYER_ID,
    name                AS NAME,
    loyalty_tier        AS LOYALTY_TIER,
    prediction:class::BOOLEAN               AS PREDICTED_RESPONSE,
    prediction:probability:True::FLOAT      AS RESPONSE_PROBABILITY,
    avg_daily_wager::FLOAT                  AS AVG_DAILY_WAGER,
    lifetime_wagered::FLOAT                 AS LIFETIME_WAGERED,
    days_since_last_visit                   AS DAYS_SINCE_LAST_VISIT
FROM predictions
WHERE prediction:class::BOOLEAN = TRUE
ORDER BY RESPONSE_PROBABILITY DESC
"""

LOOKALIKE_SQL = """
WITH seed_vectors AS (
    SELECT behavior_vector::ARRAY AS bv
    FROM CAMPAIGN_ENGINE.DT_PLAYER_VECTORS
    WHERE player_id IN ({seed_ids})
),
seed_avg AS (
    SELECT
        ARRAY_CONSTRUCT(
            AVG(bv[0]::FLOAT),  AVG(bv[1]::FLOAT),  AVG(bv[2]::FLOAT),  AVG(bv[3]::FLOAT),
            AVG(bv[4]::FLOAT),  AVG(bv[5]::FLOAT),  AVG(bv[6]::FLOAT),  AVG(bv[7]::FLOAT),
            AVG(bv[8]::FLOAT),  AVG(bv[9]::FLOAT),  AVG(bv[10]::FLOAT), AVG(bv[11]::FLOAT),
            AVG(bv[12]::FLOAT), AVG(bv[13]::FLOAT), AVG(bv[14]::FLOAT), AVG(bv[15]::FLOAT)
        )::VECTOR(FLOAT, 16) AS avg_vector
    FROM seed_vectors
)
SELECT
    v.player_id                              AS PLAYER_ID,
    p.name                                   AS NAME,
    p.loyalty_tier                           AS LOYALTY_TIER,
    VECTOR_COSINE_SIMILARITY(v.behavior_vector, s.avg_vector)::FLOAT AS SIMILARITY_SCORE,
    f.avg_daily_wager::FLOAT                 AS AVG_DAILY_WAGER,
    f.session_frequency::FLOAT               AS SESSION_FREQUENCY,
    f.lifetime_wagered::FLOAT                AS LIFETIME_WAGERED,
    f.game_diversity                         AS GAME_DIVERSITY
FROM CAMPAIGN_ENGINE.DT_PLAYER_VECTORS v
CROSS JOIN seed_avg s
JOIN CAMPAIGN_ENGINE.RAW_PLAYERS p    ON v.player_id = p.player_id
JOIN CAMPAIGN_ENGINE.DT_PLAYER_FEATURES f ON v.player_id = f.player_id
WHERE v.player_id NOT IN ({seed_ids})
ORDER BY SIMILARITY_SCORE DESC
LIMIT 10
"""

st.title("Casino Campaign Recommendation Engine")
st.caption("ML-powered audience targeting and vector-based player lookalike matching")

tab_targeting, tab_lookalike = st.tabs(["🎯 Campaign Targeting", "🔍 Player Lookalike"])

# ── Tab 1: Campaign Targeting ────────────────────────────────────────────────

with tab_targeting:
    st.header("Campaign Audience Targeting")

    cols = st.columns([3, 1, 3, 1, 3, 1, 3, 1, 3])
    cols[0].markdown(pipeline_step("👥", "500 Players", "RAW_PLAYERS"), unsafe_allow_html=True)
    cols[1].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[2].markdown(pipeline_step("⚙️", "16 Features", "Dynamic Table"), unsafe_allow_html=True)
    cols[3].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[4].markdown(pipeline_step("🧠", "ML Classify", "CLASSIFICATION"), unsafe_allow_html=True)
    cols[5].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[6].markdown(pipeline_step("🎯", "Score & Rank", "Per campaign type"), unsafe_allow_html=True)
    cols[7].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[8].markdown(pipeline_step("💬", "LLM Copy", "CORTEX.COMPLETE"), unsafe_allow_html=True)

    st.markdown("")

    campaign_types = ["RETENTION", "ACQUISITION", "UPSELL", "REACTIVATION"]
    selected_type = st.selectbox("Campaign Type", campaign_types)

    if st.button("Score Audience", key="score_btn", type="primary"):
        with st.status("Running ML pipeline...", expanded=True) as status:
            try:
                st.write("Querying DT_PLAYER_FEATURES (16 behavioral metrics)...")
                st.write(f"Scoring all players for **{selected_type}** via CAMPAIGN_RESPONSE_MODEL!PREDICT...")

                scored_df = session.sql(
                    SCORE_AUDIENCE_SQL.format(campaign_type=selected_type)
                ).to_pandas()

                if len(scored_df) > 0:
                    st.write(f"Found **{len(scored_df)}** players predicted to respond.")
                    status.update(label="Scoring complete", state="complete", expanded=True)

                    col1, col2, col3 = st.columns(3)
                    col1.metric("Predicted Audience Size", f"{len(scored_df):,}")
                    col2.metric(
                        "Avg Response Probability",
                        f"{scored_df['RESPONSE_PROBABILITY'].mean():.1%}",
                    )
                    col3.metric(
                        "Avg Daily Wager",
                        f"${scored_df['AVG_DAILY_WAGER'].mean():,.0f}",
                    )

                    chart_col, tier_col = st.columns(2)

                    with chart_col:
                        st.subheader("Response Probability Distribution")
                        prob_bins = scored_df['RESPONSE_PROBABILITY'].rename("Probability")
                        st.bar_chart(
                            prob_bins.value_counts(bins=10).sort_index().rename("Players"),
                        )

                    with tier_col:
                        st.subheader("Audience by Loyalty Tier")
                        tier_order = ["Bronze", "Silver", "Gold", "Platinum", "Diamond"]
                        tier_counts = (
                            scored_df['LOYALTY_TIER']
                            .value_counts()
                            .reindex(tier_order, fill_value=0)
                            .rename("Players")
                        )
                        st.bar_chart(tier_counts)

                    st.subheader(f"Top {min(50, len(scored_df))} Candidates")
                    st.dataframe(
                        scored_df.head(50).rename(
                            columns={
                                "PLAYER_ID": "Player ID",
                                "NAME": "Name",
                                "LOYALTY_TIER": "Tier",
                                "PREDICTED_RESPONSE": "Predicted Response",
                                "RESPONSE_PROBABILITY": "Probability",
                                "AVG_DAILY_WAGER": "Avg Daily Wager",
                                "LIFETIME_WAGERED": "Lifetime Wagered",
                                "DAYS_SINCE_LAST_VISIT": "Days Since Visit",
                            }
                        ),
                        use_container_width=True,
                        hide_index=True,
                    )
                else:
                    status.update(label="No candidates found", state="error")
                    st.info("No candidates scored above threshold for this campaign type.")
            except Exception as e:
                status.update(label="Scoring failed", state="error")
                st.error(f"Scoring error: {e}")

    st.divider()
    st.subheader("Campaign Recommendation")
    st.markdown("Generate LLM-powered campaign messaging and channel strategy for the selected audience.")

    if st.button("Generate Recommendation", key="rec_btn", type="primary"):
        with st.status("Generating with Cortex...", expanded=True) as status:
            try:
                st.write("Aggregating audience profile from V_CAMPAIGN_RECOMMENDATIONS...")
                st.write(f"Calling CORTEX.COMPLETE for **{selected_type}** strategy...")

                rec_df = session.sql(f"""
                    SELECT CAMPAIGN_ENGINE.GENERATE_CAMPAIGN_RECOMMENDATION(
                        '{selected_type}',
                        avg_wager,
                        avg_tier,
                        avg_frequency,
                        top_game_type,
                        audience_size
                    ) AS RECOMMENDATION
                    FROM CAMPAIGN_ENGINE.V_CAMPAIGN_RECOMMENDATIONS
                    WHERE campaign_type = '{selected_type}'
                """).to_pandas()

                if len(rec_df) > 0:
                    status.update(label="Recommendation ready", state="complete", expanded=True)
                    st.markdown(rec_df.iloc[0]["RECOMMENDATION"])
                else:
                    status.update(label="No profile found", state="error")
                    st.warning("No audience profile found for this campaign type.")
            except Exception as e:
                status.update(label="Generation failed", state="error")
                st.error(f"Recommendation error: {e}")

# ── Tab 2: Player Lookalike ──────────────────────────────────────────────────

with tab_lookalike:
    st.header("Player Lookalike Finder")

    cols = st.columns([3, 1, 3, 1, 3, 1, 3])
    cols[0].markdown(pipeline_step("🌱", "Seed Players", "Up to 10 IDs"), unsafe_allow_html=True)
    cols[1].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[2].markdown(pipeline_step("📐", "Avg Vector", "VECTOR(FLOAT,16)"), unsafe_allow_html=True)
    cols[3].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[4].markdown(pipeline_step("📊", "Cosine Similarity", "All 500 players"), unsafe_allow_html=True)
    cols[5].markdown(pipeline_arrow(), unsafe_allow_html=True)
    cols[6].markdown(pipeline_step("🎯", "Top 10 Matches", "Ranked by score"), unsafe_allow_html=True)

    st.markdown("")

    players_df = session.sql("""
        SELECT player_id, name, loyalty_tier
        FROM CAMPAIGN_ENGINE.RAW_PLAYERS
        ORDER BY player_id
        LIMIT 500
    """).to_pandas()

    player_options = {
        f"{row['PLAYER_ID']} - {row['NAME']} ({row['LOYALTY_TIER']})": row["PLAYER_ID"]
        for _, row in players_df.iterrows()
    }

    selected_players = st.multiselect(
        "Select Seed Players (up to 10)",
        options=list(player_options.keys()),
        max_selections=10,
    )

    if st.button("Find Similar Players", key="lookalike_btn", type="primary") and selected_players:
        seed_ids = [int(player_options[p]) for p in selected_players]
        ids_str = ",".join(str(i) for i in seed_ids)

        with st.status("Computing vector similarity...", expanded=True) as status:
            try:
                st.write(f"Computing average behavior vector from **{len(seed_ids)}** seed player(s)...")
                st.write("Ranking all other players by VECTOR_COSINE_SIMILARITY...")

                similar_df = session.sql(
                    LOOKALIKE_SQL.format(seed_ids=ids_str)
                ).to_pandas()

                if len(similar_df) > 0:
                    st.write(f"Found **{len(similar_df)}** closest matches.")
                    status.update(label="Similarity search complete", state="complete", expanded=True)

                    col1, col2, col3 = st.columns(3)
                    col1.metric(
                        "Avg Similarity Score",
                        f"{similar_df['SIMILARITY_SCORE'].mean():.4f}",
                    )
                    col2.metric("Results Found", len(similar_df))
                    col3.metric(
                        "Score Range",
                        f"{similar_df['SIMILARITY_SCORE'].min():.4f} – {similar_df['SIMILARITY_SCORE'].max():.4f}",
                    )

                    st.subheader("Similarity Scores")
                    chart_data = (
                        similar_df[["NAME", "SIMILARITY_SCORE"]]
                        .set_index("NAME")
                        .sort_values("SIMILARITY_SCORE", ascending=True)
                        .rename(columns={"SIMILARITY_SCORE": "Cosine Similarity"})
                    )
                    st.bar_chart(chart_data)

                    st.subheader("Most Similar Players")
                    st.dataframe(
                        similar_df.rename(
                            columns={
                                "PLAYER_ID": "Player ID",
                                "NAME": "Name",
                                "LOYALTY_TIER": "Tier",
                                "SIMILARITY_SCORE": "Similarity",
                                "AVG_DAILY_WAGER": "Avg Daily Wager",
                                "SESSION_FREQUENCY": "Sessions/Week",
                                "LIFETIME_WAGERED": "Lifetime Wagered",
                                "GAME_DIVERSITY": "Game Types",
                            }
                        ),
                        use_container_width=True,
                        hide_index=True,
                    )
                else:
                    status.update(label="No matches found", state="error")
                    st.info("No similar players found.")
            except Exception as e:
                status.update(label="Search failed", state="error")
                st.error(f"Lookalike error: {e}")

    elif not selected_players:
        st.info("Select at least one seed player to begin.")

# ── Footer ───────────────────────────────────────────────────────────────────

st.divider()
st.caption(
    "Pair-programmed by SE Community + Cortex Code | "
    "Data: SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE | "
    "Features: VECTOR(FLOAT,16), ML CLASSIFICATION, CORTEX.COMPLETE, Dynamic Tables"
)
