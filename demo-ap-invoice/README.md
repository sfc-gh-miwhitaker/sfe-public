# AP Invoice Pipeline

![Expires](https://img.shields.io/badge/Expires-2026--05--08-orange)

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-08
> This demo uses Snowflake features current as of April 2026.

Automated accounts payable invoice processing using Snowflake AI functions. PDF invoices land on a stage, AI_EXTRACT pulls structured fields, a Task + Stream pipeline validates and routes them, and a Streamlit dashboard provides human review and CFO-level analytics.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-04-08 | **Expires:** 2026-05-08 | **Status:** ACTIVE

## Brand New to GitHub or Cortex Code?

Start with the [Getting Started Guide](../guide-coco-setup/) -- it walks you through downloading the code and installing Cortex Code (the AI assistant that will help you with everything else).

## First Time Here?

1. **Deploy** - Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Open the dashboard** - Find `AP_INVOICE_DASHBOARD` under Streamlit in Snowsight
3. **Explore the Review Queue** - See 4 flagged invoices that need human decisions
4. **Ask questions** - Use the Analytics Chat panel: "total spend by property"
5. **Cleanup** - Run `teardown_all.sql` when done

## What Gets Created

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.AP_INVOICE` | Schema | All project objects |
| `SFE_AP_INVOICE_WH` | Warehouse (XS) | Compute for queries and AI functions |
| `RAW_INVOICE_STAGE` | Stage | Landing zone for PDF invoices |
| `VENDOR_MASTER` | Table | Canonical vendor list for fuzzy matching |
| `GL_CODES` | Table | GL account taxonomy for AI_CLASSIFY |
| `INVOICE_HEADER` | Table | Extracted invoice headers with validation scores |
| `INVOICE_LINE_ITEMS` | Table | Line items with AI-classified GL codes |
| `REVIEW_QUEUE` | Table | Human-in-the-loop review queue |
| `AUDIT_LOG` | Table | Complete audit trail for every decision |
| `PROCESSED_INVOICES` | View | Joined analytics view |
| `V_REVIEW_QUEUE` | View | Review queue with invoice context |
| `V_LINE_ITEMS_ENRICHED` | View | Line items with GL descriptions |
| `V_PIPELINE_METRICS` | View | Pipeline KPIs |
| `V_SPEND_ANALYSIS` | View | Spend by property/vendor/GL |
| `INVOICE_HEADER_STREAM` | Stream | Tracks new extractions |
| `VALIDATE_INVOICES_TASK` | Task | Auto-validates new invoices |
| `SP_PROCESS_INVOICE` | Procedure | End-to-end invoice processing |
| `SP_VALIDATE_AND_ROUTE` | Procedure | Validation and routing logic |
| `SP_CLASSIFY_LINE_ITEM` | Procedure | Single line item GL classification |
| `SP_CLASSIFY_ALL_PENDING` | Procedure | Batch GL classification |
| `SV_AP_INVOICE` | Semantic View | Cortex Analyst NL analytics |
| `AP_INVOICE_DASHBOARD` | Streamlit | 3-panel dashboard |

## Key Features

- **AI_EXTRACT** - Structured field extraction from PDF invoices
- **AI_CLASSIFY** - GL account code suggestion from line item descriptions
- **Validation scoring** - Composite score from field completeness, format checks, vendor matching
- **Human-in-the-loop** - Low-scoring invoices route to review queue with approve/reject actions
- **Full audit trail** - Every AI and human decision is logged with timestamps
- **Cortex Analyst** - Natural language analytics over processed invoices
- **Task + Stream** - Automated pipeline triggered by new data

## Trust & Auditability

This demo prominently surfaces trust signals at every layer:

- Validation scores shown inline, never hidden
- Every AI decision is labeled "AI suggested" vs. "Human confirmed"
- Override log is permanent and queryable
- No invoice reaches PROCESSED status without either high validation or human sign-off

## Estimated Demo Costs

| Component | Size | Est. Credits/Hour |
|-----------|------|-------------------|
| Warehouse | XS | 1 credit/hour (active only) |
| AI_EXTRACT | Per-page billing | ~0.001 credits/page |
| AI_CLASSIFY | Per-call billing | ~0.001 credits/call |
| Cortex Analyst | Per-query | ~0.01 credits/query |
| Storage | < 1 MB sample data | Negligible |

**Total estimated cost for demo session:** < 1 credit (assumes XS warehouse active for ~30 minutes + sample data queries). Auto-suspend at 60 seconds minimizes idle costs.

**Edition required:** Enterprise or higher (AI functions, Cortex Analyst, Streamlit in Snowflake)

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skill teaching the AI this project's patterns
- **Cortex Code in Snowsight** -- Open in a Workspace for AI-assisted development
- **Cursor** -- Open locally for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
