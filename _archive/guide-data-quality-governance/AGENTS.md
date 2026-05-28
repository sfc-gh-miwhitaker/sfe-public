# Data Quality Governance Guide

Reusable patterns for data quality governance using Snowflake-native features: Data Metric Functions, object tagging, tag-based masking, anomaly detection, and notifications. Extracted from working demos in this repository.

## Project Structure

- `README.md` -- Complete guide (6 parts + decision tree)

## Content Principles

- Extract patterns proven in demo-dataquality-metrics and demo-api-quickbooks-medallion
- Six-part progression: DMFs, scheduling, tagging, masking, anomaly detection, notifications
- Generic SQL examples using placeholder names (not demo-specific schemas)
- Every pattern links back to a working demo for full context

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL is embedded in README.md (no separate .sql files)
- DMF schedule: prefer TRIGGER_ON_CHANGES over cron for most tables
- Allow ~10 minutes after setting a schedule for first DMF results to appear
- Teardown order: UNSET masking policy from tag BEFORE dropping tags or policies
- TOKENS_GRANULAR and TAG_REFERENCES patterns use INFORMATION_SCHEMA, not ACCOUNT_USAGE
- Anomaly detection requires ANOMALY_DETECTION = TRUE on the DMF assignment

## Related Projects

- [`demo-dataquality-metrics`](../demo-dataquality-metrics/) -- Full demo with DMFs, tagging, masking, Streamlit dashboard
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Medallion architecture with DMFs, anomaly detection, notifications
- [`guide-csv-import`](../guide-csv-import/) -- Data loading fundamentals (prerequisite)
