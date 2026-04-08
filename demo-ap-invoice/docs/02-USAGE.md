# Usage Guide

## Dashboard Panels

### Pipeline Status

Shows overall pipeline health and ROI metrics:

- **Total invoices, auto-approved count, review count** — real-time from `INVOICE_HEADER`
- **Average validation score** — composite quality metric for extractions
- **ROI comparison** — manual (12 min/invoice) vs. automated processing time
- **Spend by property** — bar chart from processed invoices
- **Top vendors** — ranked by total spend

### Review Queue

Human-in-the-loop interface for low-scoring invoices:

- Invoices with validation score < 0.75 appear here
- Each card shows: source file, vendor, amount, flagged fields
- **Approve** — marks as PROCESSED, logs to audit trail
- **Reject** — marks as REJECTED, logs to audit trail
- Line items display AI-suggested GL codes with classification status
- Audit trail at bottom shows all recent decisions

### Analytics Chat

Natural language queries over processed invoices via Cortex Analyst:

- Powered by `SV_AP_INVOICE` semantic view
- Sample questions included for quick starts
- Returns live data — no cached reports

## Processing Your Own Invoices

### Single Invoice

```sql
-- Upload a PDF to the stage
PUT file:///path/to/invoice.pdf @SNOWFLAKE_EXAMPLE.AP_INVOICE.RAW_INVOICE_STAGE;

-- Process it
CALL SNOWFLAKE_EXAMPLE.AP_INVOICE.SP_PROCESS_INVOICE('invoice.pdf', 'Resort East');
```

### Batch Processing

```sql
-- Upload multiple PDFs
PUT file:///path/to/invoices/*.pdf @SNOWFLAKE_EXAMPLE.AP_INVOICE.RAW_INVOICE_STAGE;

-- Process all unprocessed files
SELECT
    relative_path,
    SNOWFLAKE_EXAMPLE.AP_INVOICE.SP_PROCESS_INVOICE(relative_path, 'Resort East')
FROM DIRECTORY(@SNOWFLAKE_EXAMPLE.AP_INVOICE.RAW_INVOICE_STAGE)
WHERE relative_path LIKE '%.pdf';
```

### Automated Processing

Enable the task to process new files automatically:

```sql
ALTER TASK SNOWFLAKE_EXAMPLE.AP_INVOICE.VALIDATE_INVOICES_TASK RESUME;
```

## Validation Scoring

Since AI_EXTRACT does not return per-field confidence scores, the pipeline computes a composite validation score:

| Check | Weight | Condition |
|-------|--------|-----------|
| Vendor name present | +0.15 | Non-null, non-empty |
| Invoice number valid | +0.15 | Non-null, > 2 characters |
| Date parseable | +0.15 | Valid date format |
| Amount positive | +0.15 | Non-null, > 0 |
| PO reference present | +0.10 | Non-null, non-empty |
| Vendor matched | +0.20 | Found in VENDOR_MASTER |
| No extraction errors | +0.10 | AI_EXTRACT error field is null |

**Threshold:** 0.75 — invoices scoring below are routed to the review queue.
