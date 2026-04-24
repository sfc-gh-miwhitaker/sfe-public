/*==============================================================================
SHARING VIEWS - Governed views for distribution partners
Secure views that can be shared without emailing spreadsheets.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- Partner-facing campaign performance summary (no internal cost details)
CREATE OR REPLACE SECURE VIEW V_PARTNER_CAMPAIGN_SUMMARY
  COMMENT = 'DEMO: Secure view for distribution partners — campaign performance without internal cost data (Expires: 2026-04-24)'
AS
SELECT
    a.artist_name,
    a.genre,
    p.campaign_name,
    p.resolved_campaign_type AS campaign_type,
    p.resolved_territory AS territory,
    p.channel,
    f.total_streams_during_campaign AS total_streams,
    f.total_royalties_during_campaign AS total_royalties,
    f.start_date,
    f.end_date
FROM FACT_CAMPAIGN_PERFORMANCE f
JOIN DIM_ARTIST a ON f.artist_id = a.artist_id
JOIN DIM_CAMPAIGN p ON f.campaign_id = p.campaign_id;

-- Partner-facing streaming summary
CREATE OR REPLACE SECURE VIEW V_PARTNER_STREAMING_SUMMARY
  COMMENT = 'DEMO: Secure view for distribution partners — streaming data by artist and platform (Expires: 2026-04-24)'
AS
SELECT
    a.artist_name,
    a.genre,
    s.platform,
    DATE_TRUNC('month', s.stream_date) AS stream_month,
    SUM(s.stream_count) AS monthly_streams
FROM FACT_STREAMS s
JOIN DIM_ARTIST a ON s.artist_id = a.artist_id
GROUP BY a.artist_name, a.genre, s.platform, DATE_TRUNC('month', s.stream_date);
