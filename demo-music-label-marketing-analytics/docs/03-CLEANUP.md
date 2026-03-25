# Cleanup Guide

## Remove All Demo Objects

Run [`teardown_all.sql`](../teardown_all.sql) in a Snowsight worksheet.

This drops:
- The `MUSIC_MARKETING` schema (cascade drops all tables, views, dynamic tables, tasks)
- The `SFE_MUSIC_MARKETING_WH` warehouse
- The `SV_MUSIC_MARKETING` semantic view from `SEMANTIC_MODELS`
- The Streamlit app and Intelligence agent

## What Is NOT Dropped

Shared infrastructure used by other projects is preserved:
- `SNOWFLAKE_EXAMPLE` database
- `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema
- `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema
- `SFE_GIT_API_INTEGRATION`
