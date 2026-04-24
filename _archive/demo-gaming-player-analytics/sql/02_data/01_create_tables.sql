/*==============================================================================
TABLES - Gaming Player Analytics
Raw source tables for player telemetry, purchases, and feedback.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE TABLE RAW_PLAYERS (
    player_id       INTEGER       NOT NULL,
    username        VARCHAR(100)  NOT NULL,
    signup_date     DATE          NOT NULL,
    platform        VARCHAR(20)   NOT NULL,
    country         VARCHAR(50)   NOT NULL,
    acquisition_source VARCHAR(30) NOT NULL,
    CONSTRAINT pk_raw_players PRIMARY KEY (player_id)
) COMMENT = 'DEMO: Player profiles with signup and platform data (Expires: 2026-04-24)';

CREATE OR REPLACE TABLE RAW_PLAYER_EVENTS (
    event_id        INTEGER       NOT NULL,
    player_id       INTEGER       NOT NULL,
    event_type      VARCHAR(30)   NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    event_date      DATE          NOT NULL,
    session_id      VARCHAR(36)   NOT NULL,
    level_id        INTEGER,
    duration_seconds INTEGER,
    metadata        VARIANT,
    CONSTRAINT pk_raw_player_events PRIMARY KEY (event_id),
    CONSTRAINT fk_events_player FOREIGN KEY (player_id) REFERENCES RAW_PLAYERS (player_id)
) COMMENT = 'DEMO: Player telemetry events -- sessions, levels, purchases, ad views (Expires: 2026-04-24)';

CREATE OR REPLACE TABLE RAW_IN_APP_PURCHASES (
    purchase_id     INTEGER       NOT NULL,
    player_id       INTEGER       NOT NULL,
    item_name       VARCHAR(100)  NOT NULL,
    item_category   VARCHAR(30)   NOT NULL,
    amount_usd      NUMBER(10,2)  NOT NULL,
    currency        VARCHAR(3)    DEFAULT 'USD',
    purchase_timestamp TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_raw_iap PRIMARY KEY (purchase_id),
    CONSTRAINT fk_iap_player FOREIGN KEY (player_id) REFERENCES RAW_PLAYERS (player_id)
) COMMENT = 'DEMO: In-app purchase transactions (Expires: 2026-04-24)';

CREATE OR REPLACE TABLE RAW_PLAYER_FEEDBACK (
    feedback_id     INTEGER       NOT NULL,
    player_id       INTEGER       NOT NULL,
    feedback_text   VARCHAR(2000) NOT NULL,
    feedback_source VARCHAR(30)   NOT NULL,
    submitted_at    TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_raw_feedback PRIMARY KEY (feedback_id),
    CONSTRAINT fk_feedback_player FOREIGN KEY (player_id) REFERENCES RAW_PLAYERS (player_id)
) COMMENT = 'DEMO: Free-text player feedback from reviews, support tickets, and surveys (Expires: 2026-04-24)';
