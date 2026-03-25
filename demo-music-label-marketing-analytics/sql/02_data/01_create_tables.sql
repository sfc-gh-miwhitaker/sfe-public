/*==============================================================================
CREATE TABLES - Music Label Marketing Analytics
Raw tables simulating Google Sheets data for "Apex Records".
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- Artists on the label roster
CREATE OR REPLACE TABLE RAW_ARTISTS (
    artist_id       INTEGER       NOT NULL PRIMARY KEY,
    artist_name     VARCHAR(200)  NOT NULL,
    genre           VARCHAR(50),
    territory       VARCHAR(50),
    roster_join_date DATE,
    label           VARCHAR(100)  DEFAULT 'Apex Records'
) COMMENT = 'DEMO: Artist roster for Apex Records (Expires: 2026-04-24)';

-- Budget allocations (the "Google Sheet" the marketing team maintains)
CREATE OR REPLACE TABLE RAW_MARKETING_BUDGET (
    budget_id       INTEGER       NOT NULL PRIMARY KEY,
    artist_id       INTEGER       NOT NULL,
    campaign_id     INTEGER,
    channel         VARCHAR(100),
    territory       VARCHAR(50),
    budget_period   DATE          NOT NULL,
    allocated_amount NUMBER(12,2) NOT NULL,
    notes           VARCHAR(1000),
    last_updated_by VARCHAR(100),
    FOREIGN KEY (artist_id) REFERENCES RAW_ARTISTS(artist_id)
) COMMENT = 'DEMO: Marketing budget allocations — simulates Google Sheets source (Expires: 2026-04-24)';

-- Actual spend transactions
CREATE OR REPLACE TABLE RAW_MARKETING_SPEND (
    spend_id        INTEGER       NOT NULL PRIMARY KEY,
    campaign_id     INTEGER       NOT NULL,
    artist_id       INTEGER       NOT NULL,
    channel         VARCHAR(100),
    spend_date      DATE          NOT NULL,
    amount          NUMBER(12,2)  NOT NULL,
    impressions     INTEGER,
    clicks          INTEGER,
    conversions     INTEGER,
    FOREIGN KEY (artist_id) REFERENCES RAW_ARTISTS(artist_id)
) COMMENT = 'DEMO: Actual marketing spend transactions (Expires: 2026-04-24)';

-- Campaign metadata (often messy — intentional gaps for AI enrichment)
CREATE OR REPLACE TABLE RAW_CAMPAIGNS (
    campaign_id     INTEGER       NOT NULL PRIMARY KEY,
    campaign_name   VARCHAR(500)  NOT NULL,
    campaign_description VARCHAR(2000),
    campaign_type   VARCHAR(100),
    channel         VARCHAR(100),
    territory       VARCHAR(50),
    artist_id       INTEGER,
    start_date      DATE,
    end_date        DATE,
    notes           VARCHAR(2000),
    FOREIGN KEY (artist_id) REFERENCES RAW_ARTISTS(artist_id)
) COMMENT = 'DEMO: Campaign metadata — intentionally messy to showcase AI enrichment (Expires: 2026-04-24)';

-- Daily streaming data by artist and track
CREATE OR REPLACE TABLE RAW_STREAMS (
    stream_id       INTEGER       NOT NULL PRIMARY KEY,
    artist_id       INTEGER       NOT NULL,
    track_name      VARCHAR(300),
    platform        VARCHAR(100),
    stream_date     DATE          NOT NULL,
    stream_count    INTEGER       NOT NULL,
    FOREIGN KEY (artist_id) REFERENCES RAW_ARTISTS(artist_id)
) COMMENT = 'DEMO: Daily streaming counts by artist, track, and platform (Expires: 2026-04-24)';

-- Monthly royalty payments
CREATE OR REPLACE TABLE RAW_ROYALTIES (
    royalty_id      INTEGER       NOT NULL PRIMARY KEY,
    artist_id       INTEGER       NOT NULL,
    royalty_period  DATE          NOT NULL,
    source          VARCHAR(100),
    amount          NUMBER(12,2)  NOT NULL,
    FOREIGN KEY (artist_id) REFERENCES RAW_ARTISTS(artist_id)
) COMMENT = 'DEMO: Monthly royalty payments by artist and source (Expires: 2026-04-24)';
