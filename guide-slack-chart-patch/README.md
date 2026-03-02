# Cortex Agent + Slack Visualization Fix

This patch adds chart/visualization support to the [sfguide-integrate-snowflake-cortex-agents-with-slack](https://github.com/Snowflake-Labs/sfguide-integrate-snowflake-cortex-agents-with-slack) quickstart.

## Problem

The original quickstart handles text, SQL queries, and citations but **does not render visualizations**. When Cortex Agent returns Vega-Lite chart specs, they are silently ignored.

```
                          BEFORE PATCH
┌─────────────┐     ┌────────────────┐     ┌─────────────┐
│    Slack    │────▶│   Slack Bot    │────▶│   Cortex    │
│    User     │     │    (app.py)    │     │   Agent     │
└─────────────┘     └────────────────┘     └─────────────┘
                           │                      │
                           │◀─────────────────────┘
                           │   Response contains:
                           │   • Text ✓
                           │   • SQL ✓
                           │   • Citations ✓
                           │   • Vega-Lite Chart ✗ (ignored!)
                           ▼
                    ┌─────────────┐
                    │    Slack    │  Only text/SQL shown
                    │   Channel   │  Charts are lost!
                    └─────────────┘
```

## Solution

This patch:
1. Extracts Vega-Lite chart specs from Cortex Agent responses
2. Renders charts to PNG using `vl-convert-python`
3. Uploads chart images to Slack via the Files API

```
                           AFTER PATCH
┌─────────────┐     ┌────────────────┐     ┌─────────────┐
│    Slack    │────▶│   Slack Bot    │────▶│   Cortex    │
│    User     │     │    (app.py)    │     │   Agent     │
└─────────────┘     └────────────────┘     └─────────────┘
                           │                      │
                           │◀─────────────────────┘
                           │   Response contains:
                           │   • Text ✓
                           │   • SQL ✓
                           │   • Citations ✓
                           │   • Vega-Lite Chart ✓
                           ▼
                    ┌────────────────┐
                    │ chart_renderer │  Vega-Lite spec
                    │     .py        │  converted to PNG
                    └────────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │    Slack    │  Full response with
                    │   Channel   │  embedded chart image!
                    └─────────────┘
```

## Installation

### 1. Install additional dependency

```bash
pip install vl-convert-python
```

### 2. Apply the patches

Copy these files to your existing quickstart project:

- `chart_renderer.py` - New file for chart rendering
- `cortex_response_parser_patch.py` - Additions to cortex_response_parser.py
- `app_patch.py` - Additions to app.py

Or use the complete modified files:

- `cortex_response_parser_modified.py` → rename to `cortex_response_parser.py`
- `app_modified.py` → rename to `app.py`

## Usage

Once patched, visualizations returned by Cortex Agent will automatically be rendered and uploaded to Slack as images.

## Files

| File | Description |
|------|-------------|
| `chart_renderer.py` | Standalone chart rendering module |
| `cortex_response_parser_patch.py` | Code to add to the parser |
| `app_patch.py` | Code to add to app.py |
| `requirements_additions.txt` | Additional pip dependencies |
