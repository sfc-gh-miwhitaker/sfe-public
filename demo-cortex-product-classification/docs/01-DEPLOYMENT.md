# Deployment Guide

## Prerequisites

- Snowflake account with **Enterprise** edition or higher (required for SPCS + Cortex)
- `SYSADMIN` role access
- `SFE_GIT_API_INTEGRATION` already configured (shared infrastructure)
- Cortex AI functions enabled in your region

## Quick Deploy (5 minutes)

1. Open **Snowsight**
2. Create a **New SQL Worksheet**
3. Paste the entire contents of `deploy_all.sql`
4. Click **Run All**

That's it. The script handles everything: schema creation, sample data, classification runs, agent setup, and dashboard deployment.

## What Gets Created

| Object | Type | Schema |
|--------|------|--------|
| `GLAZE_AND_CLASSIFY` | Schema | `SNOWFLAKE_EXAMPLE` |
| `SFE_GLAZE_AND_CLASSIFY_WH` | Warehouse (XS) | Account |
| `RAW_PRODUCTS` | Table | `GLAZE_AND_CLASSIFY` |
| `RAW_CATEGORY_TAXONOMY` | Table | `GLAZE_AND_CLASSIFY` |
| `RAW_KEYWORD_MAP` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_TRADITIONAL` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_CORTEX_SIMPLE` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_CORTEX_ROBUST` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_VISION` | Table | `GLAZE_AND_CLASSIFY` |
| `CLASSIFICATION_COMPARISON` | View | `GLAZE_AND_CLASSIFY` |
| `ACCURACY_SUMMARY` | View | `GLAZE_AND_CLASSIFY` |
| `SV_GLAZE_PRODUCTS` | Semantic View | `SEMANTIC_MODELS` |
| `GLAZE_CLASSIFIER_AGENT` | Agent | `GLAZE_AND_CLASSIFY` |
| `GLAZE_CLASSIFY_DASHBOARD` | Streamlit | `GLAZE_AND_CLASSIFY` |
| `GLAZE_VISION_SERVICE` | SPCS Service | `GLAZE_AND_CLASSIFY` |
| `SFE_GLAZE_VISION_POOL` | Compute Pool | Account |
| `CLASSIFY_IMAGE` | Function (SPCS) | `GLAZE_AND_CLASSIFY` |

## Expected Runtime

| Step | Duration |
|------|----------|
| Schema + tables + data | ~30 seconds |
| Traditional SQL classification | ~5 seconds |
| Cortex Simple classification | ~2 minutes |
| Cortex Robust classification | ~3 minutes |
| SPCS service startup | ~2 minutes |
| Vision classification | ~1 minute |
| Agent + Streamlit | ~30 seconds |
| **Total** | **~9 minutes** |

## SPCS Note

If SPCS is not available in your account/region, the SPCS steps will fail but the rest of the demo works fine. The comparison view will show NULL for vision results, and the dashboard handles this gracefully.

To skip SPCS entirely, comment out the SPCS `EXECUTE IMMEDIATE FROM` line in `deploy_all.sql`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `DEMO EXPIRED` error | Update `SET DEMO_EXPIRES` date in `deploy_all.sql` |
| Git fetch fails | Verify `SFE_GIT_API_INTEGRATION` exists and has access to the repo |
| Cortex functions fail | Check that Cortex AI is enabled in your region |
| SPCS service won't start | Verify SPCS is available; check compute pool status with `SHOW COMPUTE POOLS` |
