/*******************************************************************************
 * SNOWFLAKE TOOL: Semantic View Enhancer - Complete Cleanup
 *
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * Author: SE Community | Expires: 2026-01-15
 *
 * NOTE: NO EXPIRATION CHECK (intentional - cleanup must work even after expiration)
 *
 * PURPOSE:
 *   Complete teardown of the semantic view enhancement tool
 *
 * WARNING: This will permanently delete:
 *   - Schema SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS (CASCADE)
 *   - All semantic views in the schema
 *   - SFE_ENHANCE_SEMANTIC_VIEW procedure
 *   - SFE_ESTIMATE_ENHANCEMENT_COST function
 *   - SFE_DIAGNOSE_ENVIRONMENT procedure
 *   - SFE_ENHANCEMENT_WH warehouse
 *
 * PRESERVED (Intentional):
 *   - SNOWFLAKE_EXAMPLE database (may contain other demo projects)
 *
 * SAFETY:
 *   - Uses IF EXISTS for safe re-execution
 *   - Preserves shared infrastructure
 ******************************************************************************/

USE WAREHOUSE SFE_ENHANCEMENT_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: Drop Schema (CASCADE removes all objects within)
-- ═══════════════════════════════════════════════════════════════════════════

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: Drop Warehouse
-- ═══════════════════════════════════════════════════════════════════════════

DROP WAREHOUSE IF EXISTS SFE_ENHANCEMENT_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- ✅ CLEANUP COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ CLEANUP COMPLETE' AS STATUS,
       'All semantic-view-enhancer tool objects have been removed' AS MESSAGE,
       'Protected: SNOWFLAKE_EXAMPLE database' AS PRESERVED_OBJECTS;
