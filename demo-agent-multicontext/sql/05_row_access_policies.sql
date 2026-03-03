/*==============================================================================
05 - Row Access Policies for Station-Scoped Data
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-02

These RAPs demonstrate how station-scoped data can be filtered at the
database level. In this demo, the actual filtering is done via the
Cortex Search filter parameter and the semantic view — the RAPs here
show the pattern for production deployments where Snowflake users map
to stations.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA AGENT_MULTICONTEXT;

-- Mapping table: links Snowflake users to stations and authorization tiers
CREATE OR REPLACE TABLE USER_STATION_MAPPING (
  snowflake_user  VARCHAR(100),
  station_id      VARCHAR(10),
  auth_tier       VARCHAR(20),
  display_name    VARCHAR(100)
) COMMENT = 'DEMO: Maps users to stations and auth tiers (Expires: 2026-04-02)';

INSERT INTO USER_STATION_MAPPING VALUES
  ('DEMO_VIEWER_WETA',  'STN001', 'low',  'WETA Viewer'),
  ('DEMO_ADMIN_WETA',   'STN001', 'full', 'WETA Admin'),
  ('DEMO_VIEWER_KQED',  'STN002', 'low',  'KQED Viewer'),
  ('DEMO_ADMIN_KQED',   'STN002', 'full', 'KQED Admin'),
  ('DEMO_VIEWER_WGBH',  'STN003', 'low',  'WGBH Viewer'),
  ('DEMO_ADMIN_WGBH',   'STN003', 'full', 'WGBH Admin');

-- Helper function: get the station_id for the current user
CREATE OR REPLACE FUNCTION get_user_station_id()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  SELECT station_id
  FROM USER_STATION_MAPPING
  WHERE snowflake_user = CURRENT_USER()
  LIMIT 1
$$;

-- RAP: viewership metrics scoped to station
CREATE OR REPLACE ROW ACCESS POLICY station_viewership_policy
  AS (row_station_id VARCHAR) RETURNS BOOLEAN ->
    row_station_id = get_user_station_id()
    OR CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN');

ALTER TABLE VIEWERSHIP_METRICS
  ADD ROW ACCESS POLICY station_viewership_policy ON (station_id);

-- RAP: member accounts scoped to station
CREATE OR REPLACE ROW ACCESS POLICY station_member_policy
  AS (row_station_id VARCHAR) RETURNS BOOLEAN ->
    row_station_id = get_user_station_id()
    OR CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN');

ALTER TABLE MEMBER_ACCOUNTS
  ADD ROW ACCESS POLICY station_member_policy ON (station_id);
