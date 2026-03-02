/*==============================================================================
Create AI-Powered Joke Generation Function
teams-agent-uni | Expires: 2026-04-01

Creates: GENERATE_SAFE_JOKE(VARCHAR) using AI_COMPLETE with Cortex Guard
Depends: 01_create_demo_objects.sql
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TEAMS_AGENT_UNI;
USE WAREHOUSE SFE_TEAMS_AGENT_UNI_WH;

CREATE OR REPLACE FUNCTION GENERATE_SAFE_JOKE(subject VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: teams-agent-uni - Generate safe-for-work jokes using AI_COMPLETE with Cortex Guard (Expires: 2026-04-01)'
AS
$$
  SELECT AI_COMPLETE(
    'mistral-large2',
    [
      {
        'role': 'system',
        'content': 'You are a professional comedian who specializes in clean, workplace-appropriate humor. Your jokes should be:
- Safe for work (no profanity, sexual content, or offensive material)
- Brief (2-3 sentences maximum)
- Clever and witty
- Relevant to the subject provided
- Family-friendly and inclusive'
      },
      {
        'role': 'user',
        'content': 'Tell me a funny, workplace-appropriate joke about: ' || subject
      }
    ],
    {
      'guardrails': true,
      'temperature': 0.7,
      'max_tokens': 150
    }
  ):choices[0]:messages::STRING
$$;

-- Smoke test
SELECT GENERATE_SAFE_JOKE('data engineers') AS joke;

SHOW USER FUNCTIONS LIKE 'GENERATE_SAFE_JOKE';
