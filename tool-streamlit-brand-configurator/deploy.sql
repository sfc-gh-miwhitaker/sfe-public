/******************************************************************************
 * Tool: Streamlit Brand Configurator
 * File: deploy.sql
 * Author: SE Community
 * Created: 2026-03-10
 * Last Updated: 2026-03-10
 * Expires: 2026-06-10
 *
 * Prerequisites:
 *   1. SYSADMIN role access
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Schema: SNOWFLAKE_EXAMPLE.SFE_BRAND_CONFIGURATOR
 *   - Streamlit App: SFE_BRAND_CONFIGURATOR
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (Informational -- warns but does not block deployment)
-- ============================================================================
SELECT
    '2026-06-10'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-06-10'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-10'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-10'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-10'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-10'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools | Author: SE Community';

CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- CREATE TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SFE_BRAND_CONFIGURATOR
    COMMENT = 'TOOL: Streamlit brand configurator -- visual theme builder with config.toml export | Author: SE Community | Expires: 2026-06-10';

USE SCHEMA SFE_BRAND_CONFIGURATOR;

-- ============================================================================
-- STAGE STREAMLIT APP CODE (must happen BEFORE CREATE STREAMLIT)
-- ============================================================================
CREATE OR REPLACE STAGE SFE_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'TOOL: Stage for Streamlit brand configurator files | Author: SE Community | Expires: 2026-06-10';

CREATE OR REPLACE PROCEDURE SFE_SETUP_APP()
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'setup_app'
    COMMENT = 'TOOL: Uploads Streamlit brand configurator app files to stage | Author: SE Community | Expires: 2026-06-10'
AS
$$
from io import BytesIO

def setup_app(session):
    streamlit_code = '''import streamlit as st
import pandas as pd

st.set_page_config(
    page_title="Brand Configurator",
    page_icon=":art:",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ---------------------------------------------------------------------------
# Sidebar -- brand controls
# ---------------------------------------------------------------------------
st.sidebar.title("Brand Controls")

base_theme = st.sidebar.radio("Base theme", ["light", "dark"], horizontal=True)
is_dark = base_theme == "dark"

DEFAULTS_LIGHT = {
    "primary": "#29B5E8",
    "bg": "#FFFFFF",
    "secondary_bg": "#F0F2F6",
    "text": "#262730",
    "link": "#29B5E8",
    "border": "#D3DAE8",
    "sidebar_bg": "#F0F2F6",
    "sidebar_text": "#262730",
    "sidebar_primary": "#29B5E8",
}
DEFAULTS_DARK = {
    "primary": "#29B5E8",
    "bg": "#0E1117",
    "secondary_bg": "#262730",
    "text": "#FAFAFA",
    "link": "#29B5E8",
    "border": "#4A4E5A",
    "sidebar_bg": "#1A1C23",
    "sidebar_text": "#FAFAFA",
    "sidebar_primary": "#29B5E8",
}
defaults = DEFAULTS_DARK if is_dark else DEFAULTS_LIGHT

st.sidebar.subheader("Colors")
primary_color = st.sidebar.color_picker("Primary", defaults["primary"], key="pk")
bg_color = st.sidebar.color_picker("Background", defaults["bg"], key="bg")
secondary_bg = st.sidebar.color_picker("Secondary background", defaults["secondary_bg"], key="sbg")
text_color = st.sidebar.color_picker("Text", defaults["text"], key="tc")
link_color = st.sidebar.color_picker("Link", defaults["link"], key="lc")
border_color = st.sidebar.color_picker("Border", defaults["border"], key="bc")

st.sidebar.subheader("Sidebar overrides")
sidebar_bg = st.sidebar.color_picker("Sidebar background", defaults["sidebar_bg"], key="sdbg")
sidebar_text = st.sidebar.color_picker("Sidebar text", defaults["sidebar_text"], key="sdtc")
sidebar_primary = st.sidebar.color_picker("Sidebar primary", defaults["sidebar_primary"], key="sdpk")

st.sidebar.subheader("Borders & Radius")
RADIUS_OPTIONS = ["none", "sm", "md", "lg", "xl", "full"]
base_radius = st.sidebar.select_slider("Border radius", options=RADIUS_OPTIONS, value="md")
show_widget_border = st.sidebar.checkbox("Show widget borders", value=False)
show_sidebar_border = st.sidebar.checkbox("Show sidebar border", value=True)

st.sidebar.subheader("Fonts")
FONT_BUILTIN = ["sans-serif", "serif", "monospace"]
font_choice = st.sidebar.selectbox("Body font", FONT_BUILTIN, index=0)
heading_font_choice = st.sidebar.selectbox("Heading font", FONT_BUILTIN, index=0)
google_font_url = st.sidebar.text_input(
    "Google Fonts URL (optional)",
    placeholder="https://fonts.googleapis.com/css2?family=Inter&display=swap",
)
google_font_name = st.sidebar.text_input(
    "Google Font family name",
    placeholder="Inter",
    help="If using Google Fonts, type the font family name exactly.",
)

st.sidebar.subheader("Logo")
logo_url = st.sidebar.text_input("Logo URL", placeholder="https://example.com/logo.png")
logo_icon_url = st.sidebar.text_input(
    "Compact logo URL (optional)",
    placeholder="https://example.com/icon.png",
    help="Square icon shown when sidebar is collapsed.",
)
logo_link = st.sidebar.text_input("Logo click URL", placeholder="https://example.com")

st.sidebar.subheader("Extras")
bg_image_url = st.sidebar.text_input(
    "Background image URL (optional)", placeholder="https://..."
)


# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------
def effective_font(builtin, gurl, gname):
    if gurl and gname:
        return gname + ":" + gurl
    return builtin


body_font_value = effective_font(font_choice, google_font_url, google_font_name)
heading_font_value = effective_font(heading_font_choice, google_font_url, google_font_name)

RADIUS_CSS = {
    "none": "0px",
    "sm": "0.25rem",
    "md": "0.5rem",
    "lg": "0.75rem",
    "xl": "1rem",
    "full": "9999px",
}
radius_css = RADIUS_CSS[base_radius]


# ---------------------------------------------------------------------------
# CSS injection for live preview
# ---------------------------------------------------------------------------
def build_preview_css():
    rules = []
    rules.append('[data-testid="stAppViewContainer"] { background-color: ' + bg_color + "; }")
    rules.append('[data-testid="stMainBlockContainer"] { background-color: ' + bg_color + "; }")
    rules.append('section[data-testid="stSidebar"] { background-color: ' + sidebar_bg + "; }")
    rules.append('section[data-testid="stSidebar"] * { color: ' + sidebar_text + " !important; }")
    rules.append(".main h1,.main h2,.main h3,.main h4,.main h5,.main h6 { color: " + text_color + " !important; }")
    rules.append(".main p,.main span,.main li,.main td,.main th,.main label,.main div { color: " + text_color + "; }")
    rules.append(".main a { color: " + link_color + " !important; }")
    rules.append('.main .stButton>button[kind="primary"],.main .stButton>button[data-testid="stBaseButton-primary"] { background-color: ' + primary_color + " !important; border-color: " + primary_color + " !important; color: white !important; }")
    rules.append('.main .stButton>button[kind="secondary"],.main .stButton>button[data-testid="stBaseButton-secondary"] { border-color: ' + primary_color + " !important; color: " + primary_color + " !important; }")
    rules.append(".main .stTextInput>div>div,.main .stSelectbox>div>div,.main .stMultiSelect>div>div { border-color: " + border_color + " !important; border-radius: " + radius_css + " !important; }")
    rules.append('[data-testid="stMetric"] { background-color: ' + secondary_bg + "; border-radius: " + radius_css + "; padding: 0.75rem; }")
    if bg_image_url:
        rules.append('[data-testid="stAppViewContainer"] { background-image: url("' + bg_image_url + '") !important; background-size: cover !important; background-repeat: no-repeat !important; }')
    NL = chr(10)
    return "<style>" + NL + NL.join(rules) + NL + "</style>"


st.markdown(build_preview_css(), unsafe_allow_html=True)


# ---------------------------------------------------------------------------
# Main content -- live preview
# ---------------------------------------------------------------------------
st.title("Streamlit Brand Configurator")
st.caption("Adjust the sidebar controls and watch the preview update in real time.")

preview_tab, export_tab = st.tabs(["Live Preview", "Export"])

with preview_tab:
    st.header("Preview: Headings & Text")
    st.subheader("This is a subheader")
    st.write(
        "Body text renders in your chosen font and text color. "
        "[This is a sample link](#) styled with your link color."
    )
    st.markdown(
        '<span style="color:' + primary_color + '; font-weight:600;">Primary accent text</span>',
        unsafe_allow_html=True,
    )

    st.divider()
    st.header("Preview: Metrics")
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Revenue", "$1.24M", "+12%")
    m2.metric("Users", "8,421", "+3.2%")
    m3.metric("Latency", "42ms", "-8ms")
    m4.metric("Uptime", "99.97%", "+0.02%")

    st.divider()
    st.header("Preview: Interactive Widgets")
    w1, w2 = st.columns(2)
    with w1:
        st.text_input("Sample text input", placeholder="Type something...")
        st.selectbox("Sample select", ["Option A", "Option B", "Option C"])
    with w2:
        st.multiselect("Sample multi-select", ["Alpha", "Beta", "Gamma"], default=["Alpha"])
        st.slider("Sample slider", 0, 100, 50)

    st.divider()
    st.header("Preview: Buttons")
    b1, b2, b3, _ = st.columns([1, 1, 1, 3])
    with b1:
        st.button("Primary", type="primary", use_container_width=True)
    with b2:
        st.button("Secondary", use_container_width=True)
    with b3:
        st.button("Tertiary", use_container_width=True)

    st.divider()
    st.header("Preview: Data Table")
    sample_df = pd.DataFrame(
        {
            "Product": ["Widget A", "Widget B", "Widget C", "Widget D"],
            "Q1 Revenue": [125000, 89000, 203000, 67000],
            "Q2 Revenue": [134000, 95000, 198000, 72000],
            "Growth": ["7.2%", "6.7%", "-2.5%", "7.5%"],
        }
    )
    st.dataframe(sample_df, use_container_width=True)

    if logo_url:
        st.divider()
        st.header("Preview: Logo")
        st.image(logo_url, width=200)

    st.divider()
    st.header("Preview: Alerts & Status")
    st.success("This is a success message with your palette.")
    st.warning("This is a warning message with your palette.")
    st.info("This is an info message with your palette.")
    st.error("This is an error message with your palette.")

    st.divider()
    st.header("Preview: Code Block")
    sql_sample = "SELECT product, SUM(revenue) AS total" + chr(10)
    sql_sample += "FROM sales" + chr(10)
    sql_sample += "GROUP BY product" + chr(10)
    sql_sample += "ORDER BY total DESC;"
    st.code(sql_sample, language="sql")


# ---------------------------------------------------------------------------
# config.toml generation
# ---------------------------------------------------------------------------
NL = chr(10)
DQ = chr(34)


def build_config_toml():
    lines = []
    lines.append("[theme]")
    lines.append("base = " + DQ + base_theme + DQ)
    lines.append("primaryColor = " + DQ + primary_color + DQ)
    lines.append("backgroundColor = " + DQ + bg_color + DQ)
    lines.append("secondaryBackgroundColor = " + DQ + secondary_bg + DQ)
    lines.append("textColor = " + DQ + text_color + DQ)
    lines.append("linkColor = " + DQ + link_color + DQ)
    lines.append("borderColor = " + DQ + border_color + DQ)
    lines.append("baseRadius = " + DQ + base_radius + DQ)
    lines.append("showWidgetBorder = " + ("true" if show_widget_border else "false"))
    lines.append("showSidebarBorder = " + ("true" if show_sidebar_border else "false"))
    lines.append("font = " + DQ + body_font_value + DQ)
    if heading_font_value != body_font_value:
        lines.append("headingFont = " + DQ + heading_font_value + DQ)
    lines.append("")
    lines.append("[theme.sidebar]")
    lines.append("backgroundColor = " + DQ + sidebar_bg + DQ)
    lines.append("textColor = " + DQ + sidebar_text + DQ)
    lines.append("primaryColor = " + DQ + sidebar_primary + DQ)
    return NL.join(lines)


def build_boilerplate_py():
    parts = []
    parts.append("import streamlit as st")
    parts.append("")
    parts.append('st.set_page_config(page_title="My App", layout="wide")')
    parts.append("")
    if logo_url:
        logo_args = [DQ + logo_url + DQ, 'size="large"']
        if logo_icon_url:
            logo_args.append('icon_image="' + logo_icon_url + '"')
        if logo_link:
            logo_args.append('link="' + logo_link + '"')
        parts.append("st.logo(" + ", ".join(logo_args) + ")")
        parts.append("")
    if bg_image_url:
        TQ = DQ * 3
        parts.append("st.markdown(")
        parts.append("    " + TQ)
        parts.append("    <style>")
        parts.append("    [data-testid=stAppViewContainer] {")
        parts.append('        background-image: url("' + bg_image_url + '");')
        parts.append("        background-size: cover;")
        parts.append("        background-repeat: no-repeat;")
        parts.append("    }")
        parts.append("    </style>")
        parts.append("    " + TQ + ",")
        parts.append("    unsafe_allow_html=True,")
        parts.append(")")
        parts.append("")
    parts.append('st.title("Welcome to My App")')
    parts.append('st.write("Your branded Streamlit app is ready.")')
    return NL.join(parts)


def build_instructions():
    ins = []
    ins.append("## How to apply this brand to your Streamlit app")
    ins.append("")
    ins.append("### 1. Add the config.toml file")
    ins.append("")
    ins.append("Create a `.streamlit/` folder at the root of your app directory")
    ins.append("and save the generated `config.toml` inside it:")
    ins.append("")
    ins.append("```")
    ins.append("your-app/")
    ins.append("  .streamlit/")
    ins.append("    config.toml       <-- paste here")
    ins.append("  streamlit_app.py")
    ins.append("```")
    ins.append("")
    ins.append("### 2. Upload to your Streamlit stage")
    ins.append("")
    ins.append("When deploying to Snowflake, include the `.streamlit/` directory")
    ins.append("in your stage alongside `streamlit_app.py`. The directory structure")
    ins.append("on the stage must mirror the local layout.")
    ins.append("")
    ins.append("### 3. Add the logo (optional)")
    ins.append("")
    if logo_url:
        ins.append("Add this near the top of your `streamlit_app.py`:")
        ins.append("")
        ins.append("```python")
        logo_args = [DQ + logo_url + DQ, 'size="large"']
        if logo_icon_url:
            logo_args.append('icon_image="' + logo_icon_url + '"')
        if logo_link:
            logo_args.append('link="' + logo_link + '"')
        ins.append("st.logo(" + ", ".join(logo_args) + ")")
        ins.append("```")
    else:
        ins.append("No logo URL was provided. You can add one later with `st.logo()`.")
    ins.append("")
    ins.append("### 4. Supported runtimes")
    ins.append("")
    ins.append("The `[theme]` section of `config.toml` is supported in both")
    ins.append("**warehouse** and **container** Streamlit runtimes in Snowflake.")
    ins.append("")
    ins.append("### 5. Preview dark and light modes")
    ins.append("")
    ins.append("To support both modes, add `[theme.light]` and `[theme.dark]` sections.")
    ins.append("The config above uses a single theme. Users can still toggle via the")
    ins.append("Streamlit settings menu.")
    return NL.join(ins)


with export_tab:
    toml_output = build_config_toml()
    py_output = build_boilerplate_py()
    instructions_output = build_instructions()

    st.subheader("config.toml")
    st.code(toml_output, language="toml")
    st.download_button(
        "Download config.toml",
        data=toml_output,
        file_name="config.toml",
        mime="text/plain",
        use_container_width=True,
    )

    st.divider()
    st.subheader("streamlit_app.py starter")
    st.code(py_output, language="python")
    st.download_button(
        "Download streamlit_app.py",
        data=py_output,
        file_name="streamlit_app.py",
        mime="text/plain",
        use_container_width=True,
    )

    st.divider()
    st.subheader("Setup instructions")
    st.markdown(instructions_output)


# ---------------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------------
st.markdown("---")
st.caption("Streamlit Brand Configurator | SE Community | Expires: 2026-06-10")
'''

    file_stream = BytesIO(streamlit_code.encode('utf-8'))

    session.file.put_stream(
        input_stream=file_stream,
        stage_location='@SFE_STREAMLIT_STAGE/streamlit_app.py',
        auto_compress=False,
        overwrite=True
    )

    return "Streamlit app file created successfully"
$$;

CALL SFE_SETUP_APP();

ALTER STAGE SFE_STREAMLIT_STAGE REFRESH;

-- ============================================================================
-- CREATE STREAMLIT APP (after file is staged)
-- ============================================================================
CREATE OR REPLACE STREAMLIT SFE_BRAND_CONFIGURATOR
    FROM '@SNOWFLAKE_EXAMPLE.SFE_BRAND_CONFIGURATOR.SFE_STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    TITLE = 'Brand Configurator'
    COMMENT = 'TOOL: Visual Streamlit theme builder with config.toml export | Author: SE Community | Expires: 2026-06-10';

ALTER STREAMLIT SFE_BRAND_CONFIGURATOR ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    'DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Streamlit Brand Configurator' AS tool,
    '2026-06-10' AS expires,
    'Navigate to Projects -> Streamlit -> SFE_BRAND_CONFIGURATOR' AS next_step;
