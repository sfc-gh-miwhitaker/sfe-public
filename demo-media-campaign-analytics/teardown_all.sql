/*==============================================================================
TEARDOWN ALL - Media Campaign Analytics
Pair-programmed by SE Community + Cortex Code

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"

WHAT GETS DROPPED:
  Agent, Semantic View, Tables, Views, Project Schema, Warehouse

WHAT IS PRESERVED (shared infrastructure):
  SNOWFLAKE_EXAMPLE database, GIT_REPOS schema, SEMANTIC_MODELS schema,
  SFE_DEMOS_REPO, SFE_GIT_API_INTEGRATION
==============================================================================*/

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/99_cleanup/teardown.sql';

SELECT 'Media Campaign Analytics — teardown complete' AS status;
