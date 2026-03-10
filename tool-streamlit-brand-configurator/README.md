![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--06--10-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Streamlit Brand Configurator

> DEMONSTRATION PROJECT - EXPIRES: 2026-06-10
> This tool uses Snowflake features current as of March 2026.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

A visual theme builder for Streamlit in Snowflake. Pick your brand colors, fonts, borders, and logo, see a live preview, then export a ready-to-use `.streamlit/config.toml` and starter Python code.

---

## What It Does

- **Color pickers** for primary, background, text, link, border, and sidebar colors
- **Border controls** -- radius (none through full) and widget border visibility
- **Font selector** -- built-in fonts or paste a Google Fonts URL
- **Logo input** -- full logo URL, compact icon URL, and click-through link
- **Live preview** showing headings, metrics, buttons, tables, alerts, and code blocks with your chosen theme
- **Export tab** with downloadable `config.toml`, boilerplate `streamlit_app.py`, and setup instructions

---

## Snowflake Features Demonstrated

- **Streamlit in Snowflake** -- Native Python UI framework
- **Custom Themes** -- `[theme]` and `[theme.sidebar]` in `config.toml` (Preview since Oct 2024)
- **`st.logo()`** -- Built-in branding element
- **CSS Injection** -- `st.markdown(unsafe_allow_html=True)` for live preview simulation

---

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy.sql`](deploy.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-streamlit-brand-configurator
cd sfe-public/tool-streamlit-brand-configurator && cortex
```

### Use the Tool

1. Navigate to **Projects > Streamlit** in Snowsight
2. Find **SFE_BRAND_CONFIGURATOR** in the list
3. Click to open the app
4. Adjust colors, fonts, borders, and logo in the sidebar
5. Switch to the **Export** tab to download your config

---

## Objects Created

| Object Type | Name | Purpose |
|-------------|------|---------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_BRAND_CONFIGURATOR` | Tool namespace |
| Stage | `SFE_STREAMLIT_STAGE` | Streamlit app files |
| Streamlit | `SFE_BRAND_CONFIGURATOR` | The configurator app |
| Procedure | `SFE_SETUP_APP` | Uploads Streamlit code to stage |

---

## What the Export Produces

### config.toml

```toml
[theme]
base = "light"
primaryColor = "#29B5E8"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans-serif"

[theme.sidebar]
backgroundColor = "#F0F2F6"
textColor = "#262730"
```

### streamlit_app.py starter

```python
import streamlit as st
st.set_page_config(page_title="My App", layout="wide")
st.logo("https://your-logo-url.png", size="large")
st.title("Welcome to My App")
```

---

## Cleanup

```sql
-- Copy teardown.sql into Snowsight, Run All
```

This removes:
- Schema `SFE_BRAND_CONFIGURATOR` and all contained objects
- Does NOT remove shared infrastructure (database, warehouse)

---

## Architecture

See `diagrams/` for:
- `data-flow.md` -- How the configurator generates output

---

## Customization Ideas

1. **Add dark/light dual export** -- Generate both `[theme.light]` and `[theme.dark]` sections
2. **Add chart color palette** -- Configure `chartCategoricalColors` and `chartSequentialColors`
3. **Add font face hosting** -- Generate `[[theme.fontFaces]]` entries for self-hosted fonts
4. **Add preset themes** -- One-click brand presets for common companies

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Streamlit app not visible | Navigate to Snowsight > Projects > Streamlit. Ensure `deploy.sql` ran successfully. |
| Color pickers not updating preview | Some CSS selectors may not match all Streamlit versions. Check browser console. |
| Download button does nothing | Browser may be blocking downloads. Try right-click > Save As. |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

---

*SE Community | Streamlit Brand Configurator | Last Updated: 2026-03-10*
