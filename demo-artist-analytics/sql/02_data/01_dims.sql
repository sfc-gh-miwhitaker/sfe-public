/*==============================================================================
  02_data/01_dims.sql
  Artist Analytics — Dimension Tables + Seed Data
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Creates and seeds four dimension tables:
    DIM_ARTIST          — one row for the fictional artist "Jade Hollow"
    DIM_PLATFORM        — streaming platforms
    DIM_SOCIAL_PLATFORM — social media platforms
    DIM_SHOW            — upcoming and past performances
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

-- ── DIM_ARTIST ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_ARTIST (
    ARTIST_ID     NUMBER(4)    NOT NULL,
    ARTIST_NAME   VARCHAR(100) NOT NULL,
    GENRE         VARCHAR(50),
    HOME_CITY     VARCHAR(50),
    CAREER_START  DATE,
    LABEL         VARCHAR(100),
    CONSTRAINT PK_DIM_ARTIST PRIMARY KEY (ARTIST_ID)
)
COMMENT = 'Fictional artist profile — Jade Hollow';

INSERT INTO DIM_ARTIST (ARTIST_ID, ARTIST_NAME, GENRE, HOME_CITY, CAREER_START, LABEL)
VALUES (1, 'Jade Hollow', 'Indie Pop', 'Nashville', '2021-03-01', 'Independent');

-- ── DIM_PLATFORM ───────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PLATFORM (
    PLATFORM_ID   NUMBER(4)    NOT NULL,
    PLATFORM_NAME VARCHAR(50)  NOT NULL,
    PLATFORM_TYPE VARCHAR(30),
    ROYALTY_RATE  NUMBER(8,6)  COMMENT 'Approx USD per stream',
    CONSTRAINT PK_DIM_PLATFORM PRIMARY KEY (PLATFORM_ID)
)
COMMENT = 'Streaming distribution platforms';

INSERT INTO DIM_PLATFORM (PLATFORM_ID, PLATFORM_NAME, PLATFORM_TYPE, ROYALTY_RATE)
VALUES
    (1, 'Spotify',      'Subscription',  0.004),
    (2, 'Apple Music',  'Subscription',  0.008),
    (3, 'Amazon Music', 'Subscription',  0.004),
    (4, 'YouTube',      'Ad-Supported',  0.001);

-- ── DIM_SOCIAL_PLATFORM ────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_SOCIAL_PLATFORM (
    SOCIAL_PLATFORM_ID   NUMBER(4)    NOT NULL,
    PLATFORM_NAME        VARCHAR(50)  NOT NULL,
    PRIMARY_CONTENT_TYPE VARCHAR(50),
    CONSTRAINT PK_DIM_SOCIAL_PLATFORM PRIMARY KEY (SOCIAL_PLATFORM_ID)
)
COMMENT = 'Social media platforms tracked for artist engagement';

INSERT INTO DIM_SOCIAL_PLATFORM (SOCIAL_PLATFORM_ID, PLATFORM_NAME, PRIMARY_CONTENT_TYPE)
VALUES
    (1, 'TikTok',          'Short Video'),
    (2, 'Instagram',       'Photo / Reels'),
    (3, 'YouTube Shorts',  'Short Video'),
    (4, 'X',               'Text / Video');

SELECT
    (SELECT COUNT(*) FROM DIM_ARTIST)          AS artists,
    (SELECT COUNT(*) FROM DIM_PLATFORM)        AS platforms,
    (SELECT COUNT(*) FROM DIM_SOCIAL_PLATFORM) AS social_platforms;
