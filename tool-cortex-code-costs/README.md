![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--03-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex Code CLI — Usage & Cost Tool

Two artifacts for surfacing Cortex Code CLI costs from your Snowflake account:

- **`notebook.ipynb`** — grab-and-run Snowflake Notebook with 8 SQL + Python cells
- **`streamlit_app.py`** — interactive Streamlit in Snowflake dashboard (4 tabs)

No Snowflake objects are created. Both artifacts read directly from `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY`.

**Author:** SE Community  
**Created:** 2026-04-03 | **Expires:** 2026-05-03 | **Status:** ACTIVE

> **No support provided.** Review, test, and validate before any customer use.

---

## Quick Start

### Step 1 — Grant access

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
```

### Step 2a — Run the Notebook

1. In Snowsight: **Projects → Notebooks → + Notebook → Import .ipynb**
2. Upload `notebook.ipynb`
3. Select a warehouse and run all cells

### Step 2b — Deploy the Streamlit App

1. In Snowsight: **Projects → Streamlit → + Streamlit App**
2. Choose a warehouse and database/schema
3. Paste the contents of `streamlit_app.py` into the editor
4. Click **Run**

---

## What It Shows

| Section | Description |
|---------|-------------|
| Daily Usage | Requests, tokens, credits, estimated USD — last 30/60/90 days |
| Weekly Trend | Week-over-week adoption and spend |
| Top Users | Ranked by credit consumption |
| Hourly Pattern | Peak usage hours |
| Usage by Model | Per-model credit breakdown (cache read/write split) |
| Cost Projections | Min/mean/max day → week → month → year extrapolations |
| Model Pricing | Official Table 6(e) rates (April 1, 2026) |

---

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    ↓
notebook.ipynb           streamlit_app.py
(8 cells, static)        (4 tabs, interactive)
  1. Configuration         Overview  → daily trend, hourly pattern
  2. Daily summary         Users     → top 25 by credits
  3. Weekly trend          Models    → per-model breakdown + pricing ref
  4. Top users             Projections → min/mean/max extrapolations
  5. Hourly pattern
  6. Usage by model
  7. Cost projections
  8. Model pricing ref
```

---

## Pricing Reference

Source: [Snowflake Service Consumption Table, Table 6(e) — Cortex Code](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf) (effective April 1, 2026)

| Model | Input | Output | Cache Write | Cache Read |
|-------|------:|-------:|------------:|-----------:|
| claude-4-sonnet | 1.50 | 7.50 | 1.88 | 0.15 |
| claude-opus-4-5/4-6 | 2.75 | 13.75 | 3.44 | 0.28 |
| claude-sonnet-4-5/4-6 | 1.65 | 8.25 | 2.07 | 0.17 |
| openai-gpt-5.2 | 0.97 | 7.70 | — | 0.10 |
| openai-gpt-5.4 | 1.38 | 8.25 | — | 0.14 |

_All rates are AI Credits per 1M tokens. On-demand global AI Credit price: **$2.00/credit**._

---

## Cleanup

No Snowflake objects were created. Delete the notebook and/or Streamlit app from Snowsight when done.
