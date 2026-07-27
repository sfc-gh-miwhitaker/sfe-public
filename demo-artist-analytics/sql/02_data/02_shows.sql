/*==============================================================================
  02_data/02_shows.sql
  Artist Analytics — Show / Tour Schedule
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Seeds DIM_SHOW with 5 upcoming shows across major markets.
  The venue_city values intentionally match the regions used in FACT_SOCIAL_METRICS
  so the momentum score join works.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE TABLE DIM_SHOW (
    SHOW_ID         NUMBER(6)    NOT NULL,
    SHOW_NAME       VARCHAR(200) NOT NULL,
    VENUE_NAME      VARCHAR(200),
    VENUE_CITY      VARCHAR(50)  NOT NULL COMMENT 'Matches region values in FACT_SOCIAL_METRICS',
    SHOW_DATE       DATE         NOT NULL,
    TICKET_CAPACITY NUMBER(8),
    TICKET_PRICE    NUMBER(8,2),
    CONSTRAINT PK_DIM_SHOW PRIMARY KEY (SHOW_ID)
)
COMMENT = 'Tour dates — city values join to FACT_SOCIAL_METRICS.REGION for momentum scoring';

-- Show dates staggered so the first 2-3 are inside the 14-day momentum window at deploy time.
-- This ensures the demo always shows realistic momentum scores immediately.
-- Nashville: +5d (full 14d window available), Austin: +10d, Chicago: +21d (partial),
-- LA: +35d (outside window), NY: +49d (outside window — shows "Insufficient data" label).
INSERT INTO DIM_SHOW (SHOW_ID, SHOW_NAME, VENUE_NAME, VENUE_CITY, SHOW_DATE, TICKET_CAPACITY, TICKET_PRICE)
VALUES
    (1, 'Jade Hollow Live — Nashville',     'The Ryman Auditorium',       'Nashville',   DATEADD('day',   5, CURRENT_DATE()), 2362,  35.00),
    (2, 'Jade Hollow Live — Austin',        'Stubb''s Waller Creek',      'Austin',      DATEADD('day',  10, CURRENT_DATE()), 2750,  32.00),
    (3, 'Jade Hollow Live — Chicago',       'Schubas Tavern',             'Chicago',     DATEADD('day',  21, CURRENT_DATE()),  400,  28.00),
    (4, 'Jade Hollow Live — Los Angeles',   'El Rey Theatre',             'Los Angeles', DATEADD('day',  35, CURRENT_DATE()),  770,  40.00),
    (5, 'Jade Hollow Live — New York',      'Bowery Ballroom',            'New York',    DATEADD('day',  49, CURRENT_DATE()),  575,  45.00);

SELECT SHOW_ID, SHOW_NAME, VENUE_CITY, SHOW_DATE, TICKET_CAPACITY FROM DIM_SHOW ORDER BY SHOW_DATE;
