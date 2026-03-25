# Data Model -- Gaming Player Analytics

Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-24

```mermaid
erDiagram
    RAW_PLAYERS {
        INTEGER player_id PK
        VARCHAR username
        DATE signup_date
        VARCHAR platform
        VARCHAR country
        VARCHAR acquisition_source
    }

    RAW_PLAYER_EVENTS {
        INTEGER event_id PK
        INTEGER player_id FK
        VARCHAR event_type
        TIMESTAMP_NTZ event_timestamp
        DATE event_date
        VARCHAR session_id
        INTEGER level_id
        INTEGER duration_seconds
        VARIANT metadata
    }

    RAW_IN_APP_PURCHASES {
        INTEGER purchase_id PK
        INTEGER player_id FK
        VARCHAR item_name
        VARCHAR item_category
        NUMBER amount_usd
        TIMESTAMP_NTZ purchase_timestamp
    }

    RAW_PLAYER_FEEDBACK {
        INTEGER feedback_id PK
        INTEGER player_id FK
        VARCHAR feedback_text
        VARCHAR feedback_source
        TIMESTAMP_NTZ submitted_at
    }

    DT_PLAYER_PROFILES {
        INTEGER player_id PK
        VARCHAR ai_player_cohort
        NUMBER total_spent
        INTEGER total_sessions
        DATE last_active_date
        INTEGER days_since_last_active
    }

    DT_SESSION_METRICS {
        INTEGER player_id FK
        DATE event_date
        INTEGER session_count
        NUMBER total_playtime_minutes
        INTEGER levels_completed
        INTEGER ads_viewed
    }

    DT_ENGAGEMENT_FEATURES {
        INTEGER player_id PK
        INTEGER active_days_last_30
        NUMBER avg_daily_playtime_minutes
        NUMBER dau_mau_ratio
        VARCHAR churn_risk_level
    }

    DT_FEEDBACK_ENRICHED {
        INTEGER feedback_id PK
        INTEGER player_id FK
        VARCHAR ai_sentiment
        VARCHAR feedback_topic
        VARCHAR feedback_urgency
        VARCHAR feature_request
    }

    DIM_PLAYERS {
        INTEGER player_id PK
        VARCHAR ai_player_cohort
        VARCHAR churn_risk_level
        NUMBER dau_mau_ratio
    }

    FACT_PLAYER_LIFETIME {
        INTEGER player_id PK
        NUMBER lifetime_spend
        INTEGER lifetime_sessions
        VARCHAR churn_risk_level
        VARCHAR value_risk_segment
    }

    FACT_DAILY_ENGAGEMENT {
        DATE event_date PK
        VARCHAR ai_player_cohort PK
        INTEGER daily_active_players
        NUMBER daily_revenue
    }

    DIM_DATES {
        DATE date_key PK
        VARCHAR day_of_week
        INTEGER month_num
        INTEGER quarter_num
    }

    RAW_PLAYERS ||--o{ RAW_PLAYER_EVENTS : "generates"
    RAW_PLAYERS ||--o{ RAW_IN_APP_PURCHASES : "makes"
    RAW_PLAYERS ||--o{ RAW_PLAYER_FEEDBACK : "writes"
    RAW_PLAYERS ||--|| DT_PLAYER_PROFILES : "enriched into"
    RAW_PLAYER_EVENTS ||--o{ DT_SESSION_METRICS : "aggregated into"
    RAW_PLAYER_FEEDBACK ||--|| DT_FEEDBACK_ENRICHED : "AI enriched"
    DT_SESSION_METRICS ||--|| DT_ENGAGEMENT_FEATURES : "rolled up"
    DT_PLAYER_PROFILES ||--|| DIM_PLAYERS : "dimension"
    DT_PLAYER_PROFILES ||--|| FACT_PLAYER_LIFETIME : "lifetime stats"
    DT_ENGAGEMENT_FEATURES ||--|| FACT_PLAYER_LIFETIME : "engagement join"
    DT_SESSION_METRICS ||--o{ FACT_DAILY_ENGAGEMENT : "daily aggregate"
    DIM_DATES ||--o{ FACT_DAILY_ENGAGEMENT : "date join"
```
