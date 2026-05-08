# AP Invoice Pipeline — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

```
PDF Invoices → @RAW_INVOICE_STAGE
                    │
                    ▼
            SP_PROCESS_INVOICE
           (AI_EXTRACT → Vendor Match → Score)
                    │
              ┌─────┴─────┐
              ▼            ▼
         Score ≥ 0.75  Score < 0.75
         AUTO-APPROVE  → REVIEW_QUEUE
              │            │
              ▼            ▼
      INVOICE_HEADER   Streamlit Review Panel
      (PROCESSED)      (Human approve/reject)
              │            │
              └─────┬──────┘
                    ▼
          PROCESSED_INVOICES (view)
                    │
                    ▼
          Cortex Analyst (NL queries)
          via SV_AP_INVOICE semantic view
```

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `AP_INVOICE`
- Warehouse: `SFE_AP_INVOICE_WH` (XS, auto-suspend 60s)
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE`

## Conventions

- Validation scoring replaces confidence scores (AI_EXTRACT doesn't return per-field confidence). Score is a composite of field completeness, format checks, and vendor master matching.
- Threshold is 0.75 — below routes to REVIEW_QUEUE, above auto-approves.
- AUDIT_LOG records every AI and human decision with actor type (`AI`, `SYSTEM`, `HUMAN`).
- Line items use `GL_CODE_SUGGESTED` (AI) and `GL_CODE_CONFIRMED` (human override). Both are retained.
- Status values: `PENDING` → `PROCESSED` or `REVIEW` → `PROCESSED`/`REJECTED`.

## Key Commands

```sql
-- Deploy everything
-- Open deploy_all.sql in Snowsight → Run All

-- Process a new invoice
CALL SNOWFLAKE_EXAMPLE.AP_INVOICE.SP_PROCESS_INVOICE('invoice.pdf', 'Resort East');

-- Batch-classify unclassified line items
CALL SNOWFLAKE_EXAMPLE.AP_INVOICE.SP_CLASSIFY_ALL_PENDING();

-- Start the automated pipeline
ALTER TASK SNOWFLAKE_EXAMPLE.AP_INVOICE.VALIDATE_INVOICES_TASK RESUME;

-- Teardown
-- Open teardown_all.sql in Snowsight → Run All
```

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain: this project automates AP invoice processing using Snowflake AI functions — it extracts data from PDF invoices, classifies expenses, and provides a review dashboard
2. **Check deployment status** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy_all.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment:
   - Open the Streamlit dashboard to see the review queue
   - Try the Analytics Chat: "total spend by property this month"
   - Look at the audit trail to see AI vs. human decisions

**Assume no technical background.** Define terms when you use them.
