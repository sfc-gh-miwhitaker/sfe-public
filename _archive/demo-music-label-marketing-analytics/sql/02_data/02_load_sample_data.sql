/*==============================================================================
LOAD SAMPLE DATA - Music Label Marketing Analytics
Synthetic data for "Apex Records": 50 artists, 200 campaigns, 12 months.
Some campaign metadata is intentionally messy to demonstrate AI enrichment.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- ============================================================================
-- 1. Artists (50 across 5 genres, 4 territories)
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE _artist_seed AS
WITH genres AS (
    SELECT column1 AS genre FROM VALUES
        ('Hip-Hop'), ('R&B'), ('Pop'), ('Latin'), ('Indie')
),
territories AS (
    SELECT column1 AS territory FROM VALUES
        ('US'), ('LATAM'), ('Europe'), ('Asia-Pacific')
),
names AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
           'Artist_' || LPAD(SEQ4() + 1, 3, '0') AS base_name
    FROM TABLE(GENERATOR(ROWCOUNT => 50))
)
SELECT
    n.rn AS artist_id,
    CASE MOD(n.rn - 1, 25)
        WHEN 0  THEN 'Nia Blaze'       WHEN 1  THEN 'Marco Fuentes'   WHEN 2  THEN 'Jade Moon'
        WHEN 3  THEN 'Dex Carter'      WHEN 4  THEN 'Sofia Reyes'     WHEN 5  THEN 'Kai Tanaka'
        WHEN 6  THEN 'Lena Osei'       WHEN 7  THEN 'Rio Vasquez'     WHEN 8  THEN 'Aisha Banks'
        WHEN 9  THEN 'Yuki Nakamura'   WHEN 10 THEN 'Devon Cole'      WHEN 11 THEN 'Camila Torres'
        WHEN 12 THEN 'Zain Patel'      WHEN 13 THEN 'Mika Laurent'    WHEN 14 THEN 'Jalen Wright'
        WHEN 15 THEN 'Elena Ruiz'      WHEN 16 THEN 'Soren Beck'      WHEN 17 THEN 'Priya Sharma'
        WHEN 18 THEN 'Tyrell King'     WHEN 19 THEN 'Luna Park'       WHEN 20 THEN 'Andre Dubois'
        WHEN 21 THEN 'Valentina Cruz'  WHEN 22 THEN 'Omar Hassan'     WHEN 23 THEN 'Freya Andersen'
        WHEN 24 THEN 'Mateo Silva'
    END
    || CASE WHEN n.rn > 25 THEN ' ' || CAST(CEIL(n.rn / 25.0) AS VARCHAR) ELSE '' END AS artist_name,
    CASE MOD(n.rn - 1, 5)
        WHEN 0 THEN 'Hip-Hop' WHEN 1 THEN 'R&B' WHEN 2 THEN 'Pop'
        WHEN 3 THEN 'Latin'   ELSE 'Indie'
    END AS genre,
    CASE MOD(n.rn - 1, 4)
        WHEN 0 THEN 'US' WHEN 1 THEN 'LATAM' WHEN 2 THEN 'Europe' ELSE 'Asia-Pacific'
    END AS territory,
    DATEADD('day', -UNIFORM(60, 730, RANDOM()), CURRENT_DATE()) AS roster_join_date
FROM names n;

INSERT OVERWRITE INTO RAW_ARTISTS
SELECT artist_id, artist_name, genre, territory, roster_join_date, 'Apex Records'
FROM _artist_seed;

-- ============================================================================
-- 2. Campaigns (200 across 12 months)
--    ~30% have messy/missing metadata to demo AI enrichment
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE _campaign_seed AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS campaign_id,
        MOD(SEQ4(), 50) + 1 AS artist_id,
        DATEADD('day', UNIFORM(0, 364, RANDOM()), DATEADD('month', -12, CURRENT_DATE())) AS start_date
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
)
SELECT
    b.campaign_id,
    a.artist_name || ' - ' ||
        CASE MOD(b.campaign_id, 5)
            WHEN 0 THEN 'Single Launch'
            WHEN 1 THEN 'Album Cycle'
            WHEN 2 THEN 'Playlist Push'
            WHEN 3 THEN 'Tour Support'
            ELSE 'TikTok Promo'
        END AS campaign_name,

    -- ~30% get messy descriptions to test AI enrichment
    CASE
        WHEN MOD(b.campaign_id, 10) IN (0, 3, 7) THEN
            'Campaign for ' || a.artist_name || ' targeting ' || a.territory ||
            ' audience through digital and social channels, genre: ' || a.genre ||
            '. Goal: increase streams and brand visibility for upcoming release.'
        WHEN MOD(b.campaign_id, 10) = 5 THEN
            'promo stuff for ' || a.artist_name || ' idk the details yet - ask marketing'
        ELSE
            a.artist_name || '''s ' ||
            CASE MOD(b.campaign_id, 5)
                WHEN 0 THEN 'new single drop campaign with heavy social push'
                WHEN 1 THEN 'full album rollout with radio, PR, and streaming placement'
                WHEN 2 THEN 'editorial playlist pitching across Spotify, Apple Music, and Tidal'
                WHEN 3 THEN 'tour marketing package including social ads and local radio'
                ELSE 'TikTok creator campaign with sound promotion and hashtag challenge'
            END
    END AS campaign_description,

    -- ~20% have NULL or wrong campaign_type to demo AI_CLASSIFY
    CASE
        WHEN MOD(b.campaign_id, 5) = 2 THEN NULL
        WHEN MOD(b.campaign_id, 7) = 0 THEN 'Other'
        WHEN MOD(b.campaign_id, 5) = 0 THEN 'Single Launch'
        WHEN MOD(b.campaign_id, 5) = 1 THEN 'Album Cycle'
        WHEN MOD(b.campaign_id, 5) = 3 THEN 'Tour Support'
        ELSE 'TikTok Promo'
    END AS campaign_type,

    CASE MOD(b.campaign_id, 5)
        WHEN 0 THEN 'Meta/Instagram' WHEN 1 THEN 'Google Ads' WHEN 2 THEN 'TikTok'
        WHEN 3 THEN 'Radio/PR' ELSE 'Spotify Ad Studio'
    END AS channel,

    -- ~15% have NULL territory to demo AI_EXTRACT
    CASE WHEN MOD(b.campaign_id, 7) = 0 THEN NULL ELSE a.territory END AS territory,

    b.artist_id,
    b.start_date,
    DATEADD('day', UNIFORM(14, 90, RANDOM()), b.start_date) AS end_date,

    -- Messy notes field for AI_EXTRACT to parse
    CASE
        WHEN MOD(b.campaign_id, 3) = 0 THEN
            'Budget approved by ' ||
            CASE MOD(b.campaign_id, 4)
                WHEN 0 THEN 'Sarah (VP Marketing)' WHEN 1 THEN 'James (Head of Digital)'
                WHEN 2 THEN 'Maria (Campaign Ops)' ELSE 'Tom (Finance)'
            END ||
            '. Target: ' || a.territory || ' / ' || a.genre || ' audience. ' ||
            'Priority: ' || CASE WHEN MOD(b.campaign_id, 3) = 0 THEN 'HIGH' ELSE 'MEDIUM' END
        ELSE NULL
    END AS notes
FROM base b
JOIN _artist_seed a ON b.artist_id = a.artist_id;

INSERT OVERWRITE INTO RAW_CAMPAIGNS
SELECT campaign_id, campaign_name, campaign_description, campaign_type,
       channel, territory, artist_id, start_date, end_date, notes
FROM _campaign_seed;

-- ============================================================================
-- 3. Marketing Budget (allocations per campaign/channel/month)
-- ============================================================================
INSERT OVERWRITE INTO RAW_MARKETING_BUDGET
WITH months AS (
    SELECT DATEADD('month', SEQ4(), DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))) AS budget_period
    FROM TABLE(GENERATOR(ROWCOUNT => 13))
),
campaign_months AS (
    SELECT
        c.campaign_id,
        c.artist_id,
        c.channel,
        COALESCE(c.territory, a.territory) AS territory,
        m.budget_period
    FROM RAW_CAMPAIGNS c
    JOIN RAW_ARTISTS a ON c.artist_id = a.artist_id
    CROSS JOIN months m
    WHERE m.budget_period >= DATE_TRUNC('month', c.start_date)
      AND m.budget_period <= DATE_TRUNC('month', c.end_date)
)
SELECT
    ROW_NUMBER() OVER (ORDER BY campaign_id, budget_period) AS budget_id,
    artist_id,
    campaign_id,
    channel,
    territory,
    budget_period,
    ROUND(UNIFORM(500, 15000, RANDOM())::NUMBER(12,2), 2) AS allocated_amount,
    CASE MOD(ROW_NUMBER() OVER (ORDER BY campaign_id, budget_period), 5)
        WHEN 0 THEN 'Increased allocation per Q3 strategy review'
        WHEN 1 THEN 'Standard monthly allocation'
        WHEN 2 THEN NULL
        ELSE 'Budget set by campaign ops team'
    END AS notes,
    CASE MOD(ROW_NUMBER() OVER (ORDER BY campaign_id, budget_period), 4)
        WHEN 0 THEN 'sarah@apexrecords.com'  WHEN 1 THEN 'james@apexrecords.com'
        WHEN 2 THEN 'maria@apexrecords.com'  ELSE 'tom@apexrecords.com'
    END AS last_updated_by
FROM campaign_months;

-- ============================================================================
-- 4. Marketing Spend (daily actuals — sometimes over/under budget)
-- ============================================================================
INSERT OVERWRITE INTO RAW_MARKETING_SPEND
WITH date_range AS (
    SELECT DATEADD('day', SEQ4(), DATEADD('month', -12, CURRENT_DATE())) AS spend_date
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD('day', SEQ4(), DATEADD('month', -12, CURRENT_DATE())) <= CURRENT_DATE()
),
campaign_days AS (
    SELECT
        c.campaign_id,
        c.artist_id,
        c.channel,
        d.spend_date
    FROM RAW_CAMPAIGNS c
    JOIN date_range d ON d.spend_date >= c.start_date AND d.spend_date <= c.end_date
)
SELECT
    ROW_NUMBER() OVER (ORDER BY campaign_id, spend_date) AS spend_id,
    campaign_id,
    artist_id,
    channel,
    spend_date,
    ROUND(UNIFORM(20, 800, RANDOM())::NUMBER(12,2), 2) AS amount,
    UNIFORM(500, 50000, RANDOM()) AS impressions,
    UNIFORM(10, 2000, RANDOM()) AS clicks,
    UNIFORM(0, 100, RANDOM()) AS conversions
FROM campaign_days;

-- ============================================================================
-- 5. Streams (daily by artist, track, platform)
-- ============================================================================
INSERT OVERWRITE INTO RAW_STREAMS
WITH date_range AS (
    SELECT DATEADD('day', SEQ4(), DATEADD('month', -12, CURRENT_DATE())) AS stream_date
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD('day', SEQ4(), DATEADD('month', -12, CURRENT_DATE())) <= CURRENT_DATE()
),
platforms AS (
    SELECT column1 AS platform FROM VALUES
        ('Spotify'), ('Apple Music'), ('YouTube Music'), ('Tidal'), ('Amazon Music')
),
artist_tracks AS (
    SELECT
        artist_id,
        artist_name || ' - Track ' || t.track_num AS track_name,
        t.track_num
    FROM RAW_ARTISTS
    CROSS JOIN (SELECT SEQ4() + 1 AS track_num FROM TABLE(GENERATOR(ROWCOUNT => 3))) t
)
SELECT
    ROW_NUMBER() OVER (ORDER BY at.artist_id, at.track_name, p.platform, d.stream_date) AS stream_id,
    at.artist_id,
    at.track_name,
    p.platform,
    d.stream_date,
    GREATEST(0, UNIFORM(100, 50000, RANDOM()) +
        CASE WHEN EXISTS (
            SELECT 1 FROM RAW_CAMPAIGNS c
            WHERE c.artist_id = at.artist_id
              AND d.stream_date >= c.start_date AND d.stream_date <= c.end_date
        ) THEN UNIFORM(5000, 30000, RANDOM()) ELSE 0 END
    ) AS stream_count
FROM artist_tracks at
CROSS JOIN platforms p
CROSS JOIN date_range d
WHERE MOD(HASH(at.artist_id, p.platform, d.stream_date), 3) != 0;

-- ============================================================================
-- 6. Royalties (monthly by artist and source)
-- ============================================================================
INSERT OVERWRITE INTO RAW_ROYALTIES
WITH months AS (
    SELECT DATEADD('month', SEQ4(), DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))) AS royalty_period
    FROM TABLE(GENERATOR(ROWCOUNT => 13))
    WHERE DATEADD('month', SEQ4(), DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))) <= CURRENT_DATE()
),
sources AS (
    SELECT column1 AS source FROM VALUES
        ('Streaming'), ('Sync Licensing'), ('Mechanical'), ('Performance')
)
SELECT
    ROW_NUMBER() OVER (ORDER BY a.artist_id, s.source, m.royalty_period) AS royalty_id,
    a.artist_id,
    m.royalty_period,
    s.source,
    ROUND(UNIFORM(100, 25000, RANDOM())::NUMBER(12,2), 2) AS amount
FROM RAW_ARTISTS a
CROSS JOIN sources s
CROSS JOIN months m;

-- Verify counts
SELECT
    (SELECT COUNT(*) FROM RAW_ARTISTS)          AS artists,
    (SELECT COUNT(*) FROM RAW_CAMPAIGNS)        AS campaigns,
    (SELECT COUNT(*) FROM RAW_MARKETING_BUDGET) AS budget_rows,
    (SELECT COUNT(*) FROM RAW_MARKETING_SPEND)  AS spend_rows,
    (SELECT COUNT(*) FROM RAW_STREAMS)          AS stream_rows,
    (SELECT COUNT(*) FROM RAW_ROYALTIES)        AS royalty_rows;
