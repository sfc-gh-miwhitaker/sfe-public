![Tool](https://img.shields.io/badge/Type-Tool-purple)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Intelligence Brand Configurator

> **No support provided.** This code is for reference only.

**Pair-programmed by:** SE Community + Cortex Code

---

**Brand a Snowflake Intelligence experience in minutes -- paste a customer URL, get a deploy script.**

---

## Quick Start

```bash
pip install -r requirements.txt
python brand.py https://www.acme.com
```

This scrapes the customer site, analyzes the brand with Cortex COMPLETE, and writes three files to the current directory:

- `deploy_acme.sql` -- Run All in Snowsight to create a branded agent
- `teardown_acme.sql` -- Clean removal of all generated objects
- `ui_guide_acme.md` -- Copy-paste values for SI interface settings

## Prerequisites

- Python 3.9+
- A Snowflake connection configured in `~/.snowflake/connections.toml` (same config used by `snow` CLI)
- Cortex COMPLETE enabled in the target account

## Usage

```bash
# Basic -- scrape URL, analyze with Cortex, write files
python brand.py https://www.acme.com

# Use a specific Snowflake connection
python brand.py https://www.acme.com --connection myconn

# Write output to a specific directory
python brand.py https://www.acme.com --output-dir ./branded

# Override auto-detected values
python brand.py https://www.acme.com --name "Acme Corp" --color "#E4002B" --industry "Financial Services"
```

### Options

| Flag | Short | Description |
|---|---|---|
| `url` | | Customer website URL (required) |
| `--connection` | `-c` | Snowflake connection name (default: `default`) |
| `--output-dir` | `-o` | Output directory (default: current) |
| `--name` | | Override company name |
| `--color` | | Override brand color (hex) |
| `--industry` | | Override industry detection |

## What It Does

1. **Scrape** -- Fetches the customer homepage, extracts colors (theme-color meta, CSS), logos (og:image, favicons, header images), company name (title, og:site_name), and description
2. **Analyze** -- Sends extracted signals to Cortex COMPLETE which returns structured brand data: company name, industry, primary color, display name, welcome message, agent instructions, sample questions
3. **Generate** -- Produces self-contained SQL that creates sample data, a semantic view, a branded agent with PROFILE, and registers it with Snowflake Intelligence

## Two Branding Layers

### Layer 1: Agent PROFILE (automated in generated SQL)

```sql
PROFILE = '{"display_name": "Acme Insights", "avatar": "chart-line", "color": "#E4002B"}'
```

### Layer 2: SI Interface Settings (manual, tool provides exact values)

The `ui_guide_<company>.md` file contains copy-paste values for:

| Setting | Source |
|---------|--------|
| Display name | Auto-generated from company name |
| Welcome message | LLM-generated greeting |
| Color theme | Primary brand hex from website |
| Full-length logo | URL from og:image or header logo |
| Compact logo | Favicon URL from link tags |

## Industry Detection

| Industry | Avatar | Example Focus |
|---|---|---|
| Financial Services | `chart-line` | Risk, compliance, portfolio |
| Retail / CPG | `shopping-cart` | Sales, inventory, segments |
| Healthcare | `heart-pulse` | Volumes, operations, quality |
| Technology / SaaS | `cpu` | ARR, churn, product usage |
| Manufacturing | `wrench` | Production, defects, supply chain |
| Media / Entertainment | `film` | Content, audience metrics |
| Generic | `message-square` | Revenue, customers, business |

## Development

```bash
pip install -r requirements.txt
python brand.py --help
```

**AGENTS.md** contains project instructions for AI-pair development tools.
