/*==============================================================================
CREATE TABLES
Generated from prompt: "Create the four core tables for the casino campaign
  recommendation engine: players, activity, campaigns, responses."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE TABLE RAW_PLAYERS (
    player_id       NUMBER(38,0)    NOT NULL,
    name            VARCHAR(100)    NOT NULL,
    email           VARCHAR(200),
    age_band        VARCHAR(10)     NOT NULL,
    loyalty_tier    VARCHAR(10)     NOT NULL,
    registration_date DATE          NOT NULL,
    home_property   VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_players PRIMARY KEY (player_id)
) COMMENT = 'DEMO: Casino player demographics and loyalty info (Expires: 2026-04-01)';

CREATE OR REPLACE TABLE RAW_PLAYER_ACTIVITY (
    activity_id         NUMBER(38,0)    NOT NULL,
    player_id           NUMBER(38,0)    NOT NULL,
    activity_date       DATE            NOT NULL,
    game_type           VARCHAR(20)     NOT NULL,
    game_name           VARCHAR(50)     NOT NULL,
    session_duration_min NUMBER(38,0)   NOT NULL,
    total_wagered       NUMBER(38,2)    NOT NULL,
    total_won           NUMBER(38,2)    NOT NULL,
    device              VARCHAR(10)     NOT NULL,
    CONSTRAINT pk_activity PRIMARY KEY (activity_id),
    CONSTRAINT fk_activity_player FOREIGN KEY (player_id) REFERENCES RAW_PLAYERS(player_id)
) COMMENT = 'DEMO: Player game session events across game types and devices (Expires: 2026-04-01)';

CREATE OR REPLACE TABLE RAW_CAMPAIGNS (
    campaign_id     NUMBER(38,0)    NOT NULL,
    campaign_name   VARCHAR(200)    NOT NULL,
    campaign_type   VARCHAR(20)     NOT NULL,
    target_segment  VARCHAR(50)     NOT NULL,
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL,
    offer_description VARCHAR(500)  NOT NULL,
    CONSTRAINT pk_campaigns PRIMARY KEY (campaign_id)
) COMMENT = 'DEMO: Marketing campaign definitions (Expires: 2026-04-01)';

CREATE OR REPLACE TABLE RAW_CAMPAIGN_RESPONSES (
    response_id       NUMBER(38,0)    NOT NULL,
    campaign_id       NUMBER(38,0)    NOT NULL,
    player_id         NUMBER(38,0)    NOT NULL,
    responded         BOOLEAN         NOT NULL,
    response_date     DATE,
    redemption_amount NUMBER(38,2)    DEFAULT 0,
    CONSTRAINT pk_responses PRIMARY KEY (response_id),
    CONSTRAINT fk_response_campaign FOREIGN KEY (campaign_id) REFERENCES RAW_CAMPAIGNS(campaign_id),
    CONSTRAINT fk_response_player FOREIGN KEY (player_id) REFERENCES RAW_PLAYERS(player_id)
) COMMENT = 'DEMO: Historical campaign response data for ML training (Expires: 2026-04-01)';
