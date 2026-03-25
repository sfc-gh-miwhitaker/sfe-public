/*==============================================================================
DYNAMIC TABLES - Dimensions
Auto-refreshing dimensional model for marketing analytics.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- Artist dimension
CREATE OR REPLACE DYNAMIC TABLE DIM_ARTIST
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Artist dimension — auto-refreshed from RAW_ARTISTS (Expires: 2026-04-24)'
AS
SELECT
    artist_id,
    artist_name,
    genre,
    territory,
    roster_join_date,
    label,
    DATEDIFF('day', roster_join_date, CURRENT_DATE()) AS days_on_roster
FROM RAW_ARTISTS;

-- Channel dimension
CREATE OR REPLACE DYNAMIC TABLE DIM_CHANNEL
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Marketing channel dimension (Expires: 2026-04-24)'
AS
SELECT DISTINCT
    channel AS channel_name,
    CASE channel
        WHEN 'Meta/Instagram' THEN 'Social'
        WHEN 'Google Ads'     THEN 'Search'
        WHEN 'TikTok'         THEN 'Social'
        WHEN 'Radio/PR'       THEN 'Traditional'
        WHEN 'Spotify Ad Studio' THEN 'Streaming'
        ELSE 'Other'
    END AS channel_category,
    CASE channel
        WHEN 'Meta/Instagram' THEN 'Digital'
        WHEN 'Google Ads'     THEN 'Digital'
        WHEN 'TikTok'         THEN 'Digital'
        WHEN 'Radio/PR'       THEN 'Offline'
        WHEN 'Spotify Ad Studio' THEN 'Digital'
        ELSE 'Unknown'
    END AS channel_type
FROM RAW_MARKETING_SPEND
WHERE channel IS NOT NULL;

-- Time period dimension
CREATE OR REPLACE DYNAMIC TABLE DIM_TIME_PERIOD
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Time period dimension (Expires: 2026-04-24)'
AS
WITH date_spine AS (
    SELECT DATEADD('day', SEQ4(),
        (SELECT MIN(spend_date) FROM RAW_MARKETING_SPEND)
    ) AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 400))
    QUALIFY date_day <= CURRENT_DATE()
)
SELECT
    date_day,
    DATE_TRUNC('week', date_day)    AS week_start,
    DATE_TRUNC('month', date_day)   AS month_start,
    DATE_TRUNC('quarter', date_day) AS quarter_start,
    YEAR(date_day)                  AS year_num,
    MONTH(date_day)                 AS month_num,
    QUARTER(date_day)               AS quarter_num,
    DAYOFWEEK(date_day)             AS day_of_week,
    TO_CHAR(date_day, 'YYYY-Q')    AS year_quarter,
    TO_CHAR(date_day, 'YYYY-MM')   AS year_month
FROM date_spine;
