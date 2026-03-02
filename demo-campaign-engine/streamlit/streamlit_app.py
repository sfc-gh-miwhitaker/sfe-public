"""
Casino Campaign Recommendation Engine -- Streamlit Dashboard
Generated from prompt: "Create an interactive dashboard with campaign targeting
  and player lookalike tabs."
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
"""

from snowflake.snowpark.context import get_active_session
import streamlit as st

st.set_page_config(
    page_title="Campaign Engine",
    page_icon="🎰",
    layout="wide",
)

session = get_active_session()

st.title("Casino Campaign Recommendation Engine")
st.caption("ML-powered audience targeting and vector-based player lookalike matching")

tab_targeting, tab_lookalike = st.tabs(["Campaign Targeting", "Player Lookalike"])

# ── Tab 1: Campaign Targeting ────────────────────────────────────────────────

with tab_targeting:
    st.header("Campaign Audience Targeting")
    st.markdown(
        "Select a campaign type to score all players using the ML classification model "
        "and view the top candidates ranked by predicted response probability."
    )

    campaign_types = ["RETENTION", "ACQUISITION", "UPSELL", "REACTIVATION"]
    selected_type = st.selectbox("Campaign Type", campaign_types)

    if st.button("Score Audience", key="score_btn"):
        with st.spinner("Running ML classification model..."):
            try:
                scored_df = session.sql(
                    f"CALL CAMPAIGN_ENGINE.SCORE_CAMPAIGN_AUDIENCE('{selected_type}')"
                ).to_pandas()

                if len(scored_df) > 0:
                    col1, col2, col3 = st.columns(3)
                    col1.metric("Candidates Found", len(scored_df))
                    col2.metric(
                        "Avg Response Probability",
                        f"{scored_df['RESPONSE_PROBABILITY'].mean():.1%}",
                    )
                    col3.metric(
                        "Avg Daily Wager",
                        f"${scored_df['AVG_DAILY_WAGER'].mean():,.0f}",
                    )

                    st.subheader("Top Candidates")
                    st.dataframe(
                        scored_df.rename(
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
                    st.info("No candidates scored above threshold for this campaign type.")
            except Exception as e:
                st.error(f"Scoring error: {e}")

    st.divider()
    st.subheader("Campaign Recommendation")
    st.markdown("Generate LLM-powered campaign messaging for the selected audience.")

    if st.button("Generate Recommendation", key="rec_btn"):
        with st.spinner("Generating recommendation with Cortex..."):
            try:
                rec_df = session.sql(f"""
                    SELECT GENERATE_CAMPAIGN_RECOMMENDATION(
                        '{selected_type}',
                        avg_wager,
                        avg_tier,
                        avg_frequency,
                        top_game_type,
                        audience_size
                    ) AS recommendation
                    FROM V_CAMPAIGN_RECOMMENDATIONS
                    WHERE campaign_type = '{selected_type}'
                """).to_pandas()

                if len(rec_df) > 0:
                    st.success("Recommendation generated")
                    st.markdown(rec_df.iloc[0]["RECOMMENDATION"])
                else:
                    st.warning("No audience profile found for this campaign type.")
            except Exception as e:
                st.error(f"Recommendation error: {e}")

# ── Tab 2: Player Lookalike ──────────────────────────────────────────────────

with tab_lookalike:
    st.header("Player Lookalike Finder")
    st.markdown(
        "Select up to 10 seed players and find 10 more with the most similar "
        "behavioral patterns using vector cosine similarity."
    )

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

    if st.button("Find Similar Players", key="lookalike_btn") and selected_players:
        seed_ids = [int(player_options[p]) for p in selected_players]
        array_str = "[" + ",".join(str(i) for i in seed_ids) + "]"

        with st.spinner("Computing vector similarity..."):
            try:
                similar_df = session.sql(
                    f"CALL CAMPAIGN_ENGINE.FIND_SIMILAR_PLAYERS(PARSE_JSON('{array_str}'))"
                ).to_pandas()

                if len(similar_df) > 0:
                    col1, col2 = st.columns(2)
                    col1.metric(
                        "Avg Similarity Score",
                        f"{similar_df['SIMILARITY_SCORE'].mean():.4f}",
                    )
                    col2.metric("Results Found", len(similar_df))

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
                    st.info("No similar players found.")
            except Exception as e:
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
