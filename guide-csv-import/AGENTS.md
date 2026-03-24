# Load CSV Files into Snowflake

Step-by-step guide for loading CSV files into Snowflake using Snowsight. Covers one-time setup, a repeatable import process, and optional automation with Snowpipe and scheduled tasks.

## Project Structure

- `README.md` -- Complete guide (3 parts + troubleshooting + quick reference)

## Content Principles

- Audience is brand-new to Snowflake -- no prior experience assumed
- All SQL runs in Snowsight worksheets (no CLI required)
- VARCHAR-first loading strategy avoids type-conversion errors at import time
- Three-part progression: setup (once) -> import (repeatable) -> automation (optional)
- Inline SQL examples use generic names (`MY_DATABASE`, `MY_SCHEMA`) for user customization
- Links to official Snowflake docs for COPY INTO, stages, file formats, Snowpipe, tasks

## Key Patterns Covered

- Named file formats (`CREATE FILE FORMAT`) for reusable CSV config
- Internal stages with directory tables (`CREATE STAGE ... DIRECTORY = (ENABLE = TRUE)`)
- `INFER_SCHEMA` for automatic column detection from CSV headers
- `COPY INTO` with `ON_ERROR = 'CONTINUE'` for fault-tolerant loading
- `VALIDATE()` function for inspecting load errors
- Snowpipe with `AUTO_INGEST = TRUE` for hands-off ingestion
- Scheduled tasks with `USING CRON` for batch loading cadence

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL is embedded in README.md (no separate .sql files)
- Encourage users to replace example names with their own database/schema/table names
- The VARCHAR-for-everything approach is intentional -- cast in queries after loading
- If users ask about automation, Part 3 covers Snowpipe and scheduled tasks
- COPY INTO deduplication is built-in (tracks loaded files by name + checksum)

## Helping New Users

If the user seems confused or asks basic questions:

1. **Start with Part 1** -- ensure they have a Snowflake account and can open a Snowsight worksheet
2. **Check their CSV** -- suggest opening it in a text editor to count columns and check the delimiter
3. **Walk through setup** -- database, schema, file format, stage, table creation
4. **First load** -- guide them through upload via Snowsight UI, then COPY INTO
5. **Verify** -- row count and preview to confirm data landed correctly

## Related Projects

- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Next step: automated API ingestion with medallion architecture and quality monitoring
- [`demo-dataquality-metrics`](../demo-dataquality-metrics/) -- Add Data Metric Functions to monitor loaded data quality over time
