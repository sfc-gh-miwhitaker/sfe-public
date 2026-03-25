/*==============================================================================
SAMPLE DATA - Gaming Player Analytics
Generates synthetic player telemetry for Pixel Forge Studios.
500 players, ~90 days of events, purchases, and feedback.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

-- Players: 500 players across platforms and countries
INSERT INTO RAW_PLAYERS (player_id, username, signup_date, platform, country, acquisition_source)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS player_id,
    'player_' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 4, '0') AS username,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS signup_date,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'iOS'
        WHEN 2 THEN 'Android'
        WHEN 3 THEN 'Steam'
        ELSE 'Console'
    END AS platform,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 'United States'
        WHEN 2 THEN 'United Kingdom'
        WHEN 3 THEN 'Japan'
        WHEN 4 THEN 'Germany'
        WHEN 5 THEN 'Brazil'
        ELSE 'South Korea'
    END AS country,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'Organic'
        WHEN 2 THEN 'Paid Social'
        WHEN 3 THEN 'Influencer'
        WHEN 4 THEN 'App Store Feature'
        ELSE 'Cross-Promo'
    END AS acquisition_source
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- Player Events: ~50,000 events across session_start, session_end, level_complete, ad_view
INSERT INTO RAW_PLAYER_EVENTS (event_id, player_id, event_type, event_timestamp, event_date, session_id, level_id, duration_seconds, metadata)
WITH event_base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS event_id,
        UNIFORM(1, 500, RANDOM()) AS player_id,
        CASE UNIFORM(1, 5, RANDOM())
            WHEN 1 THEN 'session_start'
            WHEN 2 THEN 'session_end'
            WHEN 3 THEN 'level_complete'
            WHEN 4 THEN 'ad_view'
            ELSE 'achievement_unlock'
        END AS event_type,
        DATEADD('second',
            -UNIFORM(1, 7776000, RANDOM()),
            CURRENT_TIMESTAMP()
        ) AS event_timestamp,
        UUID_STRING() AS session_id,
        UNIFORM(1, 100, RANDOM()) AS level_id,
        CASE
            WHEN UNIFORM(1, 5, RANDOM()) <= 2 THEN UNIFORM(30, 3600, RANDOM())
            ELSE NULL
        END AS duration_seconds
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
)
SELECT
    event_id,
    player_id,
    event_type,
    event_timestamp,
    event_timestamp::DATE AS event_date,
    session_id,
    CASE WHEN event_type = 'level_complete' THEN level_id ELSE NULL END AS level_id,
    CASE WHEN event_type IN ('session_end', 'level_complete') THEN duration_seconds ELSE NULL END AS duration_seconds,
    CASE event_type
        WHEN 'level_complete' THEN OBJECT_CONSTRUCT('score', UNIFORM(100, 10000, RANDOM()), 'stars', UNIFORM(1, 3, RANDOM()))
        WHEN 'ad_view' THEN OBJECT_CONSTRUCT('ad_type', CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'rewarded' WHEN 2 THEN 'interstitial' ELSE 'banner' END)
        ELSE NULL
    END AS metadata
FROM event_base;

-- In-App Purchases: ~2,000 transactions
INSERT INTO RAW_IN_APP_PURCHASES (purchase_id, player_id, item_name, item_category, amount_usd, currency, purchase_timestamp)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS purchase_id,
    UNIFORM(1, 500, RANDOM()) AS player_id,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'Gem Pack (Small)'
        WHEN 2 THEN 'Gem Pack (Large)'
        WHEN 3 THEN 'Gem Pack (Mega)'
        WHEN 4 THEN 'Battle Pass'
        WHEN 5 THEN 'Starter Bundle'
        WHEN 6 THEN 'Legendary Skin'
        WHEN 7 THEN 'Extra Lives (5)'
        WHEN 8 THEN 'VIP Membership'
        WHEN 9 THEN 'Season Pass'
        ELSE 'Cosmetic Crate'
    END AS item_name,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'Currency'
        WHEN 2 THEN 'Cosmetic'
        WHEN 3 THEN 'Subscription'
        ELSE 'Consumable'
    END AS item_category,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 0.99
        WHEN 2 THEN 2.99
        WHEN 3 THEN 4.99
        WHEN 4 THEN 9.99
        WHEN 5 THEN 19.99
        ELSE 49.99
    END AS amount_usd,
    'USD' AS currency,
    DATEADD('second', -UNIFORM(1, 7776000, RANDOM()), CURRENT_TIMESTAMP()) AS purchase_timestamp
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

-- Player Feedback: 500 free-text reviews/tickets/surveys
INSERT INTO RAW_PLAYER_FEEDBACK (feedback_id, player_id, feedback_text, feedback_source, submitted_at)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS feedback_id,
    UNIFORM(1, 500, RANDOM()) AS player_id,
    CASE UNIFORM(1, 20, RANDOM())
        WHEN 1  THEN 'Love this game! The puzzle mechanics are so addictive. Been playing daily for 3 months.'
        WHEN 2  THEN 'The new update broke my saved progress. Lost all my gems and level 47 completion. Very frustrated.'
        WHEN 3  THEN 'Great game but too many ads between levels. Would pay to remove them if there was an option.'
        WHEN 4  THEN 'PvP matchmaking is terrible. Keep getting matched against players 20 levels above me.'
        WHEN 5  THEN 'The seasonal event was fantastic! Best content this game has ever released.'
        WHEN 6  THEN 'Game crashes every time I try to open the shop on my Pixel 7. Needs a fix ASAP.'
        WHEN 7  THEN 'Honestly the best mobile RPG I have played. The story quests are genuinely compelling.'
        WHEN 8  THEN 'Pay to win mechanics are ruining this game. The gem costs are outrageous for what you get.'
        WHEN 9  THEN 'Just started playing last week. Tutorial was helpful but the UI is confusing for new players.'
        WHEN 10 THEN 'Been a loyal player since launch. The guild system is what keeps me coming back every day.'
        WHEN 11 THEN 'Customer support took 2 weeks to respond to my billing issue. Unacceptable for a paid game.'
        WHEN 12 THEN 'The new character designs are amazing! Art team is killing it this season.'
        WHEN 13 THEN 'Game is fun but drains battery like crazy. Heats up my phone after 20 minutes.'
        WHEN 14 THEN 'Would love to see cross-platform play with my friends on Steam. We all play but cant group together.'
        WHEN 15 THEN 'Deleted the game after the last update nerfed my main character. Balance changes were unnecessary.'
        WHEN 16 THEN 'The daily login rewards keep me engaged. Small thing but it works.'
        WHEN 17 THEN 'Lag spikes during boss fights make the game unplayable. Fix your servers please.'
        WHEN 18 THEN 'This game has helped me relax after work. The ambient soundtrack is beautiful.'
        WHEN 19 THEN 'Refund request: purchased the battle pass but none of the rewards unlocked properly.'
        WHEN 20 THEN 'Five stars! My whole family plays this game together. The co-op mode is perfect for casual gaming.'
    END AS feedback_text,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'App Store Review'
        WHEN 2 THEN 'Support Ticket'
        WHEN 3 THEN 'In-Game Survey'
        ELSE 'Discord'
    END AS feedback_source,
    DATEADD('second', -UNIFORM(1, 7776000, RANDOM()), CURRENT_TIMESTAMP()) AS submitted_at
FROM TABLE(GENERATOR(ROWCOUNT => 500));
