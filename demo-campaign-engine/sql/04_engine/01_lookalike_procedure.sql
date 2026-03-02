/*==============================================================================
LOOKALIKE PROCEDURE
Generated from prompt: "Create a stored procedure FIND_SIMILAR_PLAYERS that
  takes an array of up to 10 player IDs, computes their average behavior
  vector, and returns the 10 most similar players using VECTOR_COSINE_SIMILARITY."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE PROCEDURE FIND_SIMILAR_PLAYERS(SEED_PLAYER_IDS ARRAY)
RETURNS TABLE (
    player_id       NUMBER,
    name            VARCHAR,
    loyalty_tier    VARCHAR,
    similarity_score FLOAT,
    avg_daily_wager FLOAT,
    session_frequency FLOAT,
    lifetime_wagered FLOAT,
    game_diversity  NUMBER
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'find_similar'
COMMENT = 'DEMO: Find 10 players most similar to seed set via vector cosine similarity (Expires: 2026-05-01)'
AS
$$
def find_similar(session, seed_player_ids):
    import json

    id_list = seed_player_ids if isinstance(seed_player_ids, list) else json.loads(seed_player_ids)
    ids_str = ','.join(str(int(i)) for i in id_list)

    query = f"""
    WITH seed_avg AS (
        SELECT
            ARRAY_CONSTRUCT(
                AVG(behavior_vector[0]),
                AVG(behavior_vector[1]),
                AVG(behavior_vector[2]),
                AVG(behavior_vector[3]),
                AVG(behavior_vector[4]),
                AVG(behavior_vector[5]),
                AVG(behavior_vector[6]),
                AVG(behavior_vector[7]),
                AVG(behavior_vector[8]),
                AVG(behavior_vector[9]),
                AVG(behavior_vector[10]),
                AVG(behavior_vector[11]),
                AVG(behavior_vector[12]),
                AVG(behavior_vector[13]),
                AVG(behavior_vector[14]),
                AVG(behavior_vector[15])
            )::VECTOR(FLOAT, 16) AS avg_vector
        FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_VECTORS
        WHERE player_id IN ({ids_str})
    )
    SELECT
        v.player_id,
        p.name,
        p.loyalty_tier,
        VECTOR_COSINE_SIMILARITY(v.behavior_vector, s.avg_vector) AS similarity_score,
        f.avg_daily_wager,
        f.session_frequency,
        f.lifetime_wagered,
        f.game_diversity
    FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_VECTORS v
    CROSS JOIN seed_avg s
    JOIN SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.RAW_PLAYERS p
        ON v.player_id = p.player_id
    JOIN SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_FEATURES f
        ON v.player_id = f.player_id
    WHERE v.player_id NOT IN ({ids_str})
    ORDER BY similarity_score DESC
    LIMIT 10
    """

    return session.sql(query)
$$;
