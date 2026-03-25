/*==============================================================================
AI ENRICHMENT - Feedback with AI_EXTRACT + AI_CLASSIFY Sentiment
AI_EXTRACT pulls structured metadata from free-text feedback.
AI_CLASSIFY assigns sentiment (SNOWFLAKE.CORTEX.SENTIMENT doesn't work in DTs).
CTE ensures each AI function is called exactly once per row.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE DYNAMIC TABLE DT_FEEDBACK_ENRICHED
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Player feedback with AI_EXTRACT metadata and AI_CLASSIFY sentiment (Expires: 2026-04-24)'
AS
WITH ai_enriched AS (
    SELECT
        f.feedback_id,
        f.player_id,
        f.feedback_text,
        f.feedback_source,
        f.submitted_at,

        AI_CLASSIFY(
            f.feedback_text,
            ['Positive', 'Negative', 'Neutral'],
            {'task_description': 'Classify the sentiment of this mobile game player feedback'}
        ):labels[0]::VARCHAR AS ai_sentiment,

        AI_EXTRACT(
            text => f.feedback_text,
            responseFormat => {
                'topic': 'What game feature or aspect is the player discussing? Examples: gameplay, monetization, bugs, graphics, matchmaking, events, customer support',
                'urgency': 'Is this feedback urgent requiring immediate action? Answer HIGH, MEDIUM, or LOW',
                'feature_request': 'Is the player requesting a specific feature? If yes, what feature? If no, say None'
            }
        ):response AS ai_extracted_metadata

    FROM RAW_PLAYER_FEEDBACK f
)
SELECT
    feedback_id,
    player_id,
    feedback_text,
    feedback_source,
    submitted_at,
    ai_sentiment,
    ai_extracted_metadata,
    ai_extracted_metadata:topic::VARCHAR AS feedback_topic,
    ai_extracted_metadata:urgency::VARCHAR AS feedback_urgency,
    ai_extracted_metadata:feature_request::VARCHAR AS feature_request
FROM ai_enriched;
