/*==============================================================================
03 - Semantic View for Cortex Analyst
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-02
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW SV_AGENT_MULTICONTEXT_VIEWERSHIP
  COMMENT = 'DEMO: TV network viewership semantic view (Expires: 2026-04-02)'
AS
  SELECT
    vm.metric_id,
    vm.station_id,
    si.station_name,
    si.call_sign,
    si.market,
    si.region,
    vm.program_title,
    vm.air_date,
    vm.viewers_total,
    vm.viewers_18_49,
    vm.rating,
    vm.share,
    vm.stream_starts,
    vm.avg_watch_min,
    ps.genre,
    ps.is_premiere,
    ps.duration_min
  FROM SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.VIEWERSHIP_METRICS vm
  JOIN SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.STATION_INFO si
    ON vm.station_id = si.station_id
  LEFT JOIN SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.PROGRAMMING_SCHEDULE ps
    ON vm.station_id = ps.station_id
    AND vm.program_title = ps.program_title
    AND vm.air_date = ps.air_date
  ANNOTATE (
    vm.metric_id IS 'Unique identifier for each viewership record',
    vm.station_id IS 'Station identifier, e.g. STN001',
    si.station_name IS 'Full station name, e.g. WETA Washington',
    si.call_sign IS 'Station call sign, e.g. WETA, KQED',
    si.market IS 'Broadcast market city',
    si.region IS 'Geographic region: Northeast, Mid-Atlantic, Midwest, West',
    vm.program_title IS 'Name of the program that aired',
    vm.air_date IS 'Date the program aired',
    vm.viewers_total IS 'Total estimated viewers for the broadcast',
    vm.viewers_18_49 IS 'Viewers in the 18-49 advertising demographic',
    vm.rating IS 'Nielsen rating (percentage of TV households tuned in)',
    vm.share IS 'Nielsen share (percentage of TVs in use tuned to this program)',
    vm.stream_starts IS 'Number of digital streaming sessions started',
    vm.avg_watch_min IS 'Average minutes watched per viewer',
    ps.genre IS 'Program genre: Nature, News, Documentary, Science, Drama, etc.',
    ps.is_premiere IS 'Whether this was a premiere episode',
    ps.duration_min IS 'Scheduled program duration in minutes'
  );

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP
  TO ROLE PUBLIC;
