# Agent Config Diff

Reference guide for extracting Cortex Agent specifications for configuration management, comparison, and version control.

## Project Structure
- `extract_agent_spec.sql` -- Interactive SQL for Snowsight/SnowSQL
- `extract_agent_spec.py` -- Programmatic Python alternative (no session state needed)

## Snowflake Environment
- No persistent objects created (utility scripts only)
- Uses `DESC AGENT` and `RESULT_SCAN`

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Python: Use `datetime.now(timezone.utc)` (not deprecated `utcnow()`)

## When Helping with This Project
- `DESC AGENT` is the correct syntax (not `DESC CORTEX AGENT`)
- Agent spec is returned as YAML, not JSON
- Profile is JSON inside a string column -- use `TRY_PARSE_JSON()`
- `RESULT_SCAN` requires an interactive session; Python script is the programmatic alternative

## Related Projects
- [`demo-cortex-teams-agent`](../demo-cortex-teams-agent/) -- Agent with CREATE AGENT DDL (extract its spec)
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Agent with semantic view (extract its spec)
- [`demo-cortex-financial-agents`](../demo-cortex-financial-agents/) -- Dual-tool agent (extract its spec)
