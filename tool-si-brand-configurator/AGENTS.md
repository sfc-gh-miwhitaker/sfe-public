# Snowflake Intelligence Brand Configurator

Local Python CLI that scrapes a customer website, analyzes brand signals with
Cortex COMPLETE, and generates a deployable branded SI agent.

## Project Structure
- `brand.py` -- Single-file CLI tool
- `requirements.txt` -- Python dependencies
- `diagrams/` -- Architecture diagrams (Mermaid)

## How It Works
1. `requests` + `BeautifulSoup` scrape the customer URL locally
2. `snowflake-connector-python` calls Cortex COMPLETE for brand analysis
3. Generates `deploy_<company>.sql`, `teardown_<company>.sql`, `ui_guide_<company>.md`

## Snowflake Connection
- Uses `~/.snowflake/connections.toml` (same config as `snow` CLI)
- Default connection name: `default` (override with `--connection`)
- Only needs SELECT privilege for Cortex COMPLETE -- no schema or object creation

## Development Standards
- SQL output: Explicit columns, COMMENT with expiration on all objects
- Agent generation: CREATE AGENT DDL with YAML specification
- Generated SQL is self-contained -- no dependencies on the tool
- SFE naming conventions (SFE_ prefix) in generated output

## When Helping with This Project
- `brand.py` is a standalone script -- no Snowflake deployment infrastructure
- The tool runs locally; web scraping needs no EAI or network rules
- Connection to Snowflake is only for Cortex COMPLETE (brand analysis step)
- Generated files go to `--output-dir` (default: current directory)
- Avatar icons are mapped from industry: chart-line, shopping-cart, heart-pulse, cpu, wrench, film, message-square
