-- ============================================================================
-- Optional: Seed Real AI Usage
-- Generates actual ACCOUNT_USAGE entries by calling Cortex AI functions.
-- Run this if your account has no existing AI usage data.
-- Pair-programmed by SE Community + Cortex Code
-- ============================================================================
--
-- MODEL SELECTION RATIONALE
-- -------------------------
-- This script exists solely to populate CORTEX_AI_FUNCTIONS_USAGE_HISTORY with
-- real rows so the dashboard has data to display. The AI output quality is
-- irrelevant — we care about generating telemetry, not answers.
--
-- Selection criteria for a seed script:
--   1. GA lifecycle status (not LEGACY, not EOL, not preview)
--   2. Broadest region availability (demo must work in any account)
--   3. Lowest cost per call (smallest token footprint)
--   4. NOT a model approaching legacy_date (avoid demo rot)
--
-- As of 2026-08-25 (verify with SHOW CORTEX BASE MODELS):
--
--   llama3.1-8b   — GA, 15+ regions, cheapest completion model with full availability
--   llama3.3-70b  — GA, narrower availability but demonstrates a mid-tier cost point
--
-- We intentionally use TWO models so the dashboard's attribution view shows
-- differentiated cost tiers — teaching users that model choice directly affects
-- their credit burn rate. The 70B model costs ~8-10x more per token than 8B.
--
-- DO NOT use for seed scripts:
--   - claude-*/openai-* (expensive; burns budget demonstrating a cost tool)
--   - Any model with lifecycle_status = LEGACY or a legacy_date set
--   - Preview models (PRPR/PUPR) — may not be available in customer accounts
--
-- To verify current model availability before running:
--   SHOW CORTEX BASE MODELS;
--   SELECT "name", "lifecycle_status", "in_region_availability"
--   FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
--   WHERE "lifecycle_status" = 'GA'
--   ORDER BY "name";
-- ============================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;

-- Create sample text to process
CREATE OR REPLACE TEMPORARY TABLE seed_text AS
SELECT column1 AS text_input FROM VALUES
    ('Snowflake makes data engineering delightful with zero-copy cloning.'),
    ('The warehouse auto-suspended after 60 seconds of inactivity, saving credits.'),
    ('Our Cortex Agent answered 500 questions today without a single hallucination.'),
    ('The dashboard load time increased from 2s to 15s after the last deployment.'),
    ('Per-user quotas blocked a runaway script before it consumed our monthly budget.'),
    ('Data sharing across regions works seamlessly with replication.'),
    ('The semantic view reduced our SQL generation errors by 40 percent.'),
    ('I cannot believe how expensive our AI function calls have become this month.'),
    ('Cost attribution by agent tag finally gives us chargeback visibility.'),
    ('The new CoCo Desktop app is a massive productivity improvement for our team.');

-- ---------------------------------------------------------------------------
-- Tier 1: Cheap model (llama3.1-8b) — ~0.03 credits per call
-- This is what you SHOULD use for high-volume, low-stakes workloads.
-- ---------------------------------------------------------------------------
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'llama3.1-8b',
    'Summarize in one sentence: ' || text_input
) AS summary
FROM seed_text;

-- ---------------------------------------------------------------------------
-- Tier 2: Mid-range model (llama3.3-70b) — ~0.25 credits per call
-- Demonstrates how a single model swap changes your cost profile dramatically.
-- The dashboard will show both tiers side-by-side in attribution.
-- ---------------------------------------------------------------------------
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'llama3.3-70b',
    'Summarize in one sentence: ' || text_input
) AS summary
FROM seed_text;

-- ---------------------------------------------------------------------------
-- Built-in functions (model chosen by Snowflake, not the user)
-- These appear as separate FUNCTION_NAME entries in usage history.
-- ---------------------------------------------------------------------------
SELECT SNOWFLAKE.CORTEX.AI_SENTIMENT(text_input) AS sentiment
FROM seed_text;

SELECT SNOWFLAKE.CORTEX.AI_CLASSIFY(
    text_input,
    ['praise', 'complaint', 'neutral', 'cost-concern']
) AS classification
FROM seed_text;

-- ---------------------------------------------------------------------------
-- Result: 40 total function calls across 2 models + 2 built-in functions.
-- Usage appears in CORTEX_AI_FUNCTIONS_USAGE_HISTORY within ~1 hour.
-- The dashboard will show cost differentiation by model in the attribution page.
-- ---------------------------------------------------------------------------
SELECT 'Seed complete: 40 AI function calls across 4 function/model combinations. '
    || 'Data appears in ACCOUNT_USAGE within 1 hour. '
    || 'Run SP_REFRESH_COST_MATERIALIZATION() after data lands.' AS status;
