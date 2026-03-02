/*==============================================================================
LOAD SAMPLE DATA
Generated from prompt: "Generate realistic synthetic casino data: 500 players,
  ~10K activities, 8 campaigns, ~2K responses. Use GENERATOR and UNIFORM."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

----------------------------------------------------------------------
-- 1. Players (500 across 5 loyalty tiers, weighted distribution)
----------------------------------------------------------------------
INSERT OVERWRITE INTO RAW_PLAYERS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS player_id,
    'Player_' || ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR AS name,
    'player' || ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR || '@example.com' AS email,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN '21-30'
        WHEN 2 THEN '31-40'
        WHEN 3 THEN '41-50'
        WHEN 4 THEN '51-60'
        ELSE '61+'
    END AS age_band,
    CASE
        WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 'Bronze'
        WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'Silver'
        WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'Gold'
        WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN 'Platinum'
        ELSE 'Diamond'
    END AS loyalty_tier,
    DATEADD('day', -UNIFORM(30, 1095, RANDOM()), CURRENT_DATE()) AS registration_date,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'Las Vegas Strip'
        WHEN 2 THEN 'Atlantic City'
        WHEN 3 THEN 'Biloxi'
        WHEN 4 THEN 'Lake Tahoe'
        ELSE 'New Orleans'
    END AS home_property
FROM TABLE(GENERATOR(ROWCOUNT => 500));

----------------------------------------------------------------------
-- 2. Player Activity (~10,000 sessions over 6 months)
----------------------------------------------------------------------
INSERT OVERWRITE INTO RAW_PLAYER_ACTIVITY
WITH base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS activity_id,
        UNIFORM(1, 500, RANDOM()) AS player_id,
        DATEADD('day', -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS activity_date,
        UNIFORM(1, 100, RANDOM()) AS game_rand,
        UNIFORM(1, 100, RANDOM()) AS device_rand
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
),
typed AS (
    SELECT
        activity_id,
        player_id,
        activity_date,
        CASE
            WHEN game_rand <= 45 THEN 'SLOTS'
            WHEN game_rand <= 75 THEN 'TABLE_GAMES'
            WHEN game_rand <= 90 THEN 'POKER'
            ELSE 'SPORTS_BOOK'
        END AS game_type,
        CASE
            WHEN device_rand <= 55 THEN 'FLOOR'
            WHEN device_rand <= 85 THEN 'MOBILE'
            ELSE 'WEB'
        END AS device
    FROM base
),
with_wager AS (
    SELECT
        activity_id,
        player_id,
        activity_date,
        game_type,
        CASE game_type
            WHEN 'SLOTS' THEN
                CASE UNIFORM(1, 5, RANDOM())
                    WHEN 1 THEN 'Lucky 7s'
                    WHEN 2 THEN 'Mega Fortune'
                    WHEN 3 THEN 'Golden Dragon'
                    WHEN 4 THEN 'Diamond Deluxe'
                    ELSE 'Wild Jackpot'
                END
            WHEN 'TABLE_GAMES' THEN
                CASE UNIFORM(1, 4, RANDOM())
                    WHEN 1 THEN 'Blackjack'
                    WHEN 2 THEN 'Roulette'
                    WHEN 3 THEN 'Baccarat'
                    ELSE 'Craps'
                END
            WHEN 'POKER' THEN
                CASE UNIFORM(1, 3, RANDOM())
                    WHEN 1 THEN 'Texas Holdem'
                    WHEN 2 THEN 'Omaha'
                    ELSE 'Three Card Poker'
                END
            ELSE
                CASE UNIFORM(1, 3, RANDOM())
                    WHEN 1 THEN 'NFL Lines'
                    WHEN 2 THEN 'NBA Parlays'
                    ELSE 'MLB Futures'
                END
        END AS game_name,
        CASE game_type
            WHEN 'SLOTS'       THEN UNIFORM(10, 120, RANDOM())
            WHEN 'TABLE_GAMES' THEN UNIFORM(30, 240, RANDOM())
            WHEN 'POKER'       THEN UNIFORM(60, 360, RANDOM())
            ELSE                    UNIFORM(5, 30, RANDOM())
        END AS session_duration_min,
        CASE game_type
            WHEN 'SLOTS'       THEN ROUND(UNIFORM(10, 500, RANDOM()) * 1.0, 2)
            WHEN 'TABLE_GAMES' THEN ROUND(UNIFORM(50, 5000, RANDOM()) * 1.0, 2)
            WHEN 'POKER'       THEN ROUND(UNIFORM(100, 3000, RANDOM()) * 1.0, 2)
            ELSE                    ROUND(UNIFORM(20, 1000, RANDOM()) * 1.0, 2)
        END AS total_wagered,
        device
    FROM typed
)
SELECT
    activity_id,
    player_id,
    activity_date,
    game_type,
    game_name,
    session_duration_min,
    total_wagered,
    ROUND(total_wagered * UNIFORM(0, 200, RANDOM()) / 100.0, 2) AS total_won,
    device
FROM with_wager;

----------------------------------------------------------------------
-- 3. Campaigns (8 across 4 types)
----------------------------------------------------------------------
INSERT OVERWRITE INTO RAW_CAMPAIGNS
SELECT column1, column2, column3, column4, column5, column6, column7
FROM VALUES
    (1, 'Weekend High-Roller Slots Blitz',   'UPSELL',       'Gold+',     '2025-10-01'::DATE, '2025-10-31'::DATE, 'Double comp points on slot play over $500 on weekends'),
    (2, 'Welcome Back Bonus',                'REACTIVATION', 'Inactive',  '2025-11-01'::DATE, '2025-11-30'::DATE, '$50 free play for players inactive 30+ days'),
    (3, 'Table Games Tuesday',               'RETENTION',    'All',       '2025-11-01'::DATE, '2026-01-31'::DATE, '2x rewards on table games every Tuesday'),
    (4, 'Diamond Elite Experience',          'RETENTION',    'Diamond',   '2025-12-01'::DATE, '2025-12-31'::DATE, 'Exclusive VIP lounge access and concierge service'),
    (5, 'New Player First Bet Match',        'ACQUISITION',  'New',       '2026-01-01'::DATE, '2026-03-31'::DATE, 'First bet matched up to $200 for new registrations'),
    (6, 'Sports Book Super Bowl Special',    'UPSELL',       'Sports',    '2026-01-15'::DATE, '2026-02-15'::DATE, 'Enhanced odds and free prop bets for Super Bowl'),
    (7, 'Mobile App Download Reward',        'ACQUISITION',  'Non-Mobile','2026-02-01'::DATE, '2026-03-31'::DATE, '$25 free play for downloading and using the mobile app'),
    (8, 'Spring Break Poker Tournament',     'UPSELL',       'Poker',     '2026-03-01'::DATE, '2026-03-31'::DATE, 'Free entry to $10K guaranteed tournament with $100+ buy-in history');

----------------------------------------------------------------------
-- 4. Campaign Responses (~2,000 with ~30% positive rate)
----------------------------------------------------------------------
INSERT OVERWRITE INTO RAW_CAMPAIGN_RESPONSES
WITH base_responses AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS response_id,
        UNIFORM(1, 8, RANDOM()) AS campaign_id,
        UNIFORM(1, 500, RANDOM()) AS player_id,
        UNIFORM(1, 100, RANDOM()) <= 30 AS responded,
        DATEADD('day', -UNIFORM(0, 150, RANDOM()), CURRENT_DATE()) AS base_date
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
    response_id,
    campaign_id,
    player_id,
    responded,
    CASE WHEN responded THEN base_date ELSE NULL END AS response_date,
    CASE WHEN responded THEN ROUND(UNIFORM(10, 500, RANDOM()) * 1.0, 2) ELSE 0 END AS redemption_amount
FROM base_responses;
