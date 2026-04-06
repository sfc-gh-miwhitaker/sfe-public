/*==============================================================================
03 - Semantic View for Cortex Analyst
Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-06
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW SV_AGENT_MULTICONTEXT_VIEWERSHIP

  TABLES (
    viewership AS SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.VIEWERSHIP_METRICS
      PRIMARY KEY (metric_id)
      WITH SYNONYMS = ('viewership', 'ratings', 'audience data')
      COMMENT = 'Broadcast and streaming viewership metrics per program airing',

    stations AS SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.STATION_INFO
      PRIMARY KEY (station_id)
      WITH SYNONYMS = ('stations', 'TV stations', 'channels')
      COMMENT = 'TV station directory with market and region info',

    schedule AS SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.PROGRAMMING_SCHEDULE
      PRIMARY KEY (schedule_id)
      WITH SYNONYMS = ('schedule', 'programming', 'shows', 'programs')
      COMMENT = 'Program schedule with genre, air times, and premiere flags'
  )

  RELATIONSHIPS (
    viewership_to_station AS
      viewership (station_id) REFERENCES stations,
    schedule_to_station AS
      schedule (station_id) REFERENCES stations
  )

  FACTS (
    viewership.viewers_total AS viewership.viewers_total
      COMMENT = 'Total estimated viewers for the broadcast',

    viewership.viewers_18_49 AS viewership.viewers_18_49
      COMMENT = 'Viewers in the 18-49 advertising demographic',

    viewership.rating AS viewership.rating
      COMMENT = 'Nielsen rating (percentage of TV households tuned in)',

    viewership.share AS viewership.share
      COMMENT = 'Nielsen share (percentage of TVs in use tuned to this program)',

    viewership.stream_starts AS viewership.stream_starts
      COMMENT = 'Number of digital streaming sessions started',

    viewership.avg_watch_min AS viewership.avg_watch_min
      COMMENT = 'Average minutes watched per viewer',

    schedule.duration_min AS schedule.duration_min
      COMMENT = 'Scheduled program duration in minutes'
  )

  DIMENSIONS (
    viewership.station_id AS station_id
      COMMENT = 'Station identifier, e.g. STN001',

    viewership.program_title AS program_title
      WITH SYNONYMS = ('show', 'program', 'title')
      COMMENT = 'Name of the program that aired',

    viewership.air_date AS air_date
      COMMENT = 'Date the program aired',

    stations.station_name AS station_name
      WITH SYNONYMS = ('station', 'channel name')
      COMMENT = 'Full station name, e.g. WETA Washington',

    stations.call_sign AS call_sign
      COMMENT = 'Station call sign, e.g. WETA, KQED',

    stations.market AS market
      WITH SYNONYMS = ('city', 'broadcast market')
      COMMENT = 'Broadcast market city',

    stations.region AS region
      COMMENT = 'Geographic region: Northeast, Mid-Atlantic, Midwest, West',

    schedule.genre AS genre
      WITH SYNONYMS = ('category', 'program type')
      COMMENT = 'Program genre: Nature, News, Documentary, Science, Drama, etc.',

    schedule.is_premiere AS is_premiere
      COMMENT = 'Whether this was a premiere episode'
  )

  METRICS (
    viewership.broadcast_count AS COUNT(viewership.metric_id)
      COMMENT = 'Total number of broadcast airings',

    viewership.total_viewers AS SUM(viewership.viewers_total)
      COMMENT = 'Sum of total viewers across airings',

    viewership.avg_rating AS AVG(viewership.rating)
      COMMENT = 'Average Nielsen rating across airings',

    viewership.avg_share AS AVG(viewership.share)
      COMMENT = 'Average Nielsen share across airings',

    viewership.total_streams AS SUM(viewership.stream_starts)
      COMMENT = 'Sum of digital streaming sessions across airings'
  )

  COMMENT = 'DEMO: TV network viewership semantic view (Expires: 2026-07-06)';

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP
  TO ROLE PUBLIC;
