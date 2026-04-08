---
name: ap-invoice
description: "AP Invoice Pipeline demo using AI_EXTRACT, AI_CLASSIFY, Task+Stream automation, and Cortex Analyst. Use when working with invoice processing, document extraction, GL classification, or AP automation in Snowflake."
---

# AP Invoice Pipeline

## Purpose

Demonstrates end-to-end AP invoice automation in Snowflake: AI_EXTRACT for PDF field extraction, AI_CLASSIFY for GL code suggestion, Task+Stream for automated processing, validation-based routing to a human review queue, and Cortex Analyst for CFO-level NL analytics.

## Architecture

```
PDF → @RAW_INVOICE_STAGE → SP_PROCESS_INVOICE (AI_EXTRACT + vendor match + score)
  → Score ≥ 0.75: auto-approve → INVOICE_HEADER (PROCESSED)
  → Score < 0.75: REVIEW_QUEUE → Streamlit review → human approve/reject
  → All paths → AUDIT_LOG + PROCESSED_INVOICES view → SV_AP_INVOICE → Cortex Analyst
```

AI_EXTRACT does not return per-field confidence. Validation score is computed from: field completeness (non-null, non-empty), format validity (dates, amounts), and vendor master fuzzy matching (JAROWINKLER_SIMILARITY).

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `teardown_all.sql` | Complete cleanup (preserves shared infra) |
| `sql/01_setup/01_create_schema.sql` | Schema, tables, stage |
| `sql/02_data/01_load_sample_data.sql` | 27 synthetic invoices, 8 vendors, 20 GL codes |
| `sql/03_transformations/01_create_views.sql` | Analytics views (PROCESSED_INVOICES, V_REVIEW_QUEUE, etc.) |
| `sql/03_transformations/02_create_stream_and_task.sql` | Stream, task, SP_PROCESS_INVOICE, SP_VALIDATE_AND_ROUTE |
| `sql/04_cortex/01_ai_extract_patterns.sql` | AI_EXTRACT usage patterns (commented, for reference) |
| `sql/04_cortex/02_ai_classify_gl_codes.sql` | SP_CLASSIFY_LINE_ITEM, SP_CLASSIFY_ALL_PENDING |
| `sql/04_cortex/03_create_semantic_view.sql` | SV_AP_INVOICE in SEMANTIC_MODELS schema |
| `sql/05_streamlit/01_create_dashboard.sql` | CREATE STREAMLIT from Git repo |
| `streamlit/streamlit_app.py` | 3-panel dashboard (status, review queue, analytics chat) |

## Adding a New Vendor

1. Insert into `VENDOR_MASTER` with `VENDOR_ALIASES` array for fuzzy matching variants
2. The aliases array is checked by `SP_PROCESS_INVOICE` during vendor matching
3. No schema changes needed — the fuzzy match uses JAROWINKLER_SIMILARITY as fallback
4. Test: `CALL SP_PROCESS_INVOICE('new_vendor_invoice.pdf', 'Resort East');`

## Adding a New GL Code

1. Insert into `GL_CODES` with `GL_CODE`, `GL_DESCRIPTION`, and `CATEGORY`
2. AI_CLASSIFY automatically picks up new codes — the category array is built dynamically
3. Update the `SV_AP_INVOICE` semantic view if the new category needs specific synonyms
4. Test: `CALL SP_CLASSIFY_LINE_ITEM(<line_id>);`

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `AP_INVOICE`
- Warehouse: `SFE_AP_INVOICE_WH` (XS)
- Stage: `RAW_INVOICE_STAGE`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE`
- All objects have `COMMENT = 'DEMO: ... (Expires: 2026-05-08)'`

## Gotchas

- **AI_EXTRACT has no confidence scores.** The plan assumed per-field confidence; the actual API returns `{error, response}` only. Validation scoring is computed post-extraction instead.
- **VALIDATE_INVOICES_TASK starts suspended.** Must `ALTER TASK ... RESUME` to enable automated processing. This is intentional for demo safety.
- **Vendor matching has two paths:** exact match against `VENDOR_ALIASES` array, then JAROWINKLER_SIMILARITY fallback. The `QUALIFY ROW_NUMBER()` pattern picks the best match.
- **deploy_all.sql requires ACCOUNTADMIN** for the API integration step, then drops to SYSADMIN. If the user lacks ACCOUNTADMIN, the integration must be pre-created.
- **Streamlit FROM clause** uses Git repo path. The app won't work until code is pushed to the repo and `ALTER GIT REPOSITORY ... FETCH` runs.
