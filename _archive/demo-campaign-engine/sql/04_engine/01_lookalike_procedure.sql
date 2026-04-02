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
    WITH seed_vectors AS (
        SELECT behavior_vector::ARRAY AS bv
        FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_VECTORS
        WHERE player_id IN ({ids_str})
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
        v.player_id,
        p.name,
        p.loyalty_tier,
        VECTOR_COSINE_SIMILARITY(v.behavior_vector, s.avg_vector)::FLOAT AS similarity_score,
        f.avg_daily_wager::FLOAT AS avg_daily_wager,
        f.session_frequency::FLOAT AS session_frequency,
        f.lifetime_wagered::FLOAT AS lifetime_wagered,
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
