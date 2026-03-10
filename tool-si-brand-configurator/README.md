![Tool](https://img.shields.io/badge/Type-Tool-purple)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--06--10-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Intelligence Brand Configurator

> **DEMONSTRATION PROJECT - EXPIRES: 2026-06-10**
> This tool uses Snowflake features current as of March 2026.
> After expiration, a warning banner will be added to this README and deploy.sql.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Pair-programmed by:** SE Community + Cortex Code
**Last Updated:** 2026-03-10 | **Expires:** 2026-06-10 | **Status:** ACTIVE

---

**Brand a Snowflake Intelligence experience in minutes -- paste a customer URL, get a deploy script.**

---

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy.sql`](deploy.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-si-brand-configurator
cd sfe-public/tool-si-brand-configurator && cortex
```

## What It Does

1. **Extract** -- Paste a customer website URL; the tool scrapes brand signals (colors, logos, name, description) using `requests` + `BeautifulSoup` via External Access Integration
2. **Analyze** -- Cortex COMPLETE interprets the raw signals and returns structured brand data (company name, industry, colors, suggested portal name, welcome message, agent instructions)
3. **Preview & Edit** -- Review the auto-detected brand with editable overrides for every field
4. **Generate** -- Produces three outputs:
   - **Deploy SQL** -- Self-contained script that creates sample data, semantic view, branded agent, and registers it with Snowflake Intelligence
   - **Teardown SQL** -- Matching cleanup script
   - **UI Branding Guide** -- Step-by-step instructions with copy-paste values for the SI interface settings (display name, welcome message, hex color, logo URLs)

## Two Branding Layers

### Layer 1: Agent PROFILE (automated in generated SQL)

```sql
PROFILE = '{"display_name": "Acme Insights", "avatar": "chart-line", "color": "#E4002B"}'
```

- `display_name` -- Agent handle in SI conversations
- `avatar` -- Icon identifier mapped from industry
- `color` -- Agent accent color in chat UI

### Layer 2: SI Interface Settings (manual, tool provides exact values)

Cannot be set via SQL today. The tool outputs ready-to-paste values:

| Setting | Source |
|---------|--------|
| Display name | Auto-generated from company name |
| Welcome message | LLM-generated greeting tailored to the company |
| Color theme | Primary brand hex extracted from website |
| Full-length logo | URL extracted from og:image or header logo |
| Compact logo | Favicon URL extracted from link tags |

## Snowflake Capabilities Demonstrated

| Capability | How It's Used |
|---|---|
| Streamlit in Snowflake | Interactive brand extraction and SQL generation UI |
| External Access Integration | HTTPS egress to fetch arbitrary customer websites |
| Network Rules (dynamic) | Helper procedure adds customer domains on-the-fly |
| Cortex COMPLETE | LLM-powered brand signal analysis |
| CREATE AGENT | Generated SQL uses the DDL agent pattern |
| Semantic Views | Generated SQL includes a complete semantic view |
| Snowflake Intelligence | Generated SQL registers agents with SI |

## What Gets Created

| Object Type | Name | Purpose |
|---|---|---|
| Schema | `SFE_SI_BRAND_CONFIGURATOR` | Tool schema |
| Warehouse | `SFE_SI_BRAND_CONFIGURATOR_WH` | Compute for the tool |
| Network Rule | `SFE_BRAND_SCRAPER_RULE` | HTTPS egress for web scraping |
| EAI | `SFE_BRAND_SCRAPER_EAI` | External access integration |
| Procedure | `SFE_ADD_SCRAPER_DOMAIN` | Dynamically adds domains to the network rule |
| Procedure | `SFE_SETUP_APP` | Uploads Streamlit code to stage |
| Stage | `SFE_SI_BRAND_CONFIGURATOR_STAGE` | App file storage |
| Streamlit | `SFE_SI_BRAND_CONFIGURATOR` | The brand configurator app |

## Manual Input Fallback

If the External Access Integration is unavailable or web scraping fails, switch to the **Manual input** tab and enter brand details directly:

- Company name
- Primary brand color (hex picker)
- Industry (dropdown)
- Logo URL
- SI display name

The SQL generation and UI branding guide work identically in both modes.

## Cleanup

Copy [`teardown.sql`](teardown.sql) into Snowsight and click **Run All**.

This removes the configurator tool itself. It does **not** remove any branded agents the tool generated -- each generated agent includes its own teardown script.

## Industry Templates

The tool detects industry from the customer website and customizes:

| Industry | Avatar | Agent Personality |
|---|---|---|
| Financial Services | `chart-line` | Risk, compliance, portfolio focus |
| Retail / CPG | `shopping-cart` | Sales trends, inventory, segments |
| Healthcare | `heart-pulse` | Patient volumes, operational metrics |
| Technology / SaaS | `cpu` | ARR, churn, product usage |
| Manufacturing | `wrench` | Production, defect rates, supply chain |
| Media / Entertainment | `film` | Content performance, audience metrics |
| Generic | `message-square` | Revenue, customers, business metrics |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
