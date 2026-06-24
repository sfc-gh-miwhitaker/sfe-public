/*==============================================================================
99_OPTIONAL — Seed REAL Cortex AI usage (populates LIVE ACCOUNT_USAGE views)
Cortex AI Cost Controls demo | Expires: 2026-07-24

OPTIONAL. Run this by hand (NOT part of deploy_all.sql) when you want the live
views to show genuine AI Function activity on a low-usage account.

COST: a handful of calls over 5 short strings — a few cents of credits. Cheap.
LATENCY: ACCOUNT_USAGE views lag 45-60 min. The new rows will NOT appear in the
         dashboard immediately. Re-check in ~1 hour.
==============================================================================*/

USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

CREATE OR REPLACE TEMPORARY TABLE seed_text (comment_text VARCHAR)
  COMMENT = 'DEMO: transient seed input for AI calls (Expires: 2026-07-24)';

INSERT INTO seed_text (comment_text) VALUES
    ('The product is fantastic and the support team was quick to help.'),
    ('Terrible experience — the app was slow and crashed twice.'),
    ('It works fine, nothing special to report.'),
    ('Absolutely love the new dashboard, huge improvement!'),
    ('Billing was confusing and the invoice did not match my plan.');

-- Three different AI functions so multiple FUNCTION_NAME rows show up.
SELECT
    comment_text,
    AI_COMPLETE('llama3.1-8b',
        'Reply with one word describing the tone: ' || comment_text) AS one_word_tone,
    AI_SENTIMENT(comment_text)                                        AS sentiment,
    AI_CLASSIFY(comment_text, ['praise', 'complaint', 'neutral'])     AS category
FROM seed_text;

SELECT 'Seed complete — recheck the dashboard in ~1 hour (ACCOUNT_USAGE latency).' AS status;
