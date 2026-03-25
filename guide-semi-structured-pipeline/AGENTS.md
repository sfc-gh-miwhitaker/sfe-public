# Semi-Structured Data Pipeline Architecture Guide

Validated architecture patterns for building bronze-to-gold pipelines with Dynamic Tables, TRY_CAST, LATERAL FLATTEN, schema evolution, and Data Metric Functions. Covers three ingestion paths (Snowpipe, Snowpipe Streaming, OpenFlow) and the architectural decision of where transformations live.

## Project Structure

- `README.md` -- Main guide: Problem -> Progression (4 steps) -> Architecture -> Deep Dives -> Quick Reference
- `01_bronze_setup.sql` -- Stage, file formats, bronze table with all 5 metadata columns, Snowpipe, sample data
- `02_silver_dynamic_table.sql` -- Silver DT with TRY_CAST + _raw columns, LATERAL FLATTEN, dedup with QUALIFY
- `03_gold_dynamic_table.sql` -- Three gold DTs (daily sales, customer 360, product performance) with TARGET_LAG
- `04_schema_evolution.sql` -- Key detection (INFER_SCHEMA + FLATTEN/TYPEOF), audit log, DT chain rebuild
- `05_operational_queries.sql` -- DT refresh history, cast failure investigation, DMFs, pipeline health

## Content Principles

- README follows the glaze-and-classify progression model: Problem -> Progression -> Architecture -> Deep Dives
- Each progression step shows what breaks and why you need the next one
- Every technical claim is backed by a Snowflake documentation link
- SQL workbooks are self-contained -- paste into Snowsight and run step-by-step
- DMF content is brief; full patterns live in guide-data-quality-governance

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects created by default
- SQL workbooks are numbered and sequential: 01 must run before 02, etc.
- TRY_CAST and VARIANT `::` both return NULL on conversion failure from VARIANT data. The value is the _raw column pattern that makes failures detectable, not different NULL behavior.
- `TARGET_LAG = DOWNSTREAM` means refresh is driven by downstream consumers. If no downstream DT defines a concrete lag, a DOWNSTREAM DT will NOT refresh at all.
- Bronze uses all 5 METADATA$ columns (FILENAME, FILE_ROW_NUMBER, FILE_CONTENT_KEY, FILE_LAST_MODIFIED, START_SCAN_TIME)
- Schema evolution detection works from stage (INFER_SCHEMA) or from VARIANT data (FLATTEN + TYPEOF)
- DMFs require Enterprise Edition
- OpenFlow can do ETL (transform before load), not just ELT -- NiFi processors can collapse pipeline layers

## Related Projects

- [`guide-data-quality-governance`](../guide-data-quality-governance/) -- Full DMF patterns, tagging, masking, anomaly detection
- [`guide-csv-import`](../guide-csv-import/) -- Data loading fundamentals
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Working medallion architecture demo
- [`demo-dataquality-metrics`](../demo-dataquality-metrics/) -- Deployable DMF demo with Streamlit
