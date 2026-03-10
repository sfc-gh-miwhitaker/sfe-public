/*==============================================================================
Snowflake Intelligence Brand Configurator -- Deploy
Pair-programmed by SE Community + Cortex Code | Expires: 2026-06-10

Deploys a Streamlit in Snowflake tool that extracts brand signals from a
customer website, analyzes them with Cortex COMPLETE, and generates a
ready-to-run deploy script for a branded Snowflake Intelligence agent.

Prerequisites:
  - SYSADMIN and ACCOUNTADMIN access
  - Cortex COMPLETE enabled in the account (for brand analysis)
  - Network connectivity for HTTPS egress (External Access Integration)
==============================================================================*/

-- ============================================================================
-- 1. Infrastructure
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools';

CREATE WAREHOUSE IF NOT EXISTS SFE_SI_BRAND_CONFIGURATOR_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME  = TRUE
    COMMENT = 'DEMO: SI Brand Configurator compute (Expires: 2026-06-10)';

USE WAREHOUSE SFE_SI_BRAND_CONFIGURATOR_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SFE_SI_BRAND_CONFIGURATOR
    COMMENT = 'DEMO: SI Brand Configurator tool (Expires: 2026-06-10)';

CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS
    COMMENT = 'Shared schema for semantic views across SE demos';

USE SCHEMA SFE_SI_BRAND_CONFIGURATOR;

-- ============================================================================
-- 2. Network Rule (SYSADMIN-owned so the helper procedure can ALTER it)
--    Starts with a placeholder domain. The helper procedure dynamically adds
--    customer domains before each scrape attempt.
-- ============================================================================
CREATE OR REPLACE NETWORK RULE SFE_BRAND_SCRAPER_RULE
    MODE       = EGRESS
    TYPE       = HOST_PORT
    VALUE_LIST = ('example.com:443')
    COMMENT    = 'DEMO: Egress rule for SI Brand Configurator web scraping (Expires: 2026-06-10)';

-- EAI requires ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFE_BRAND_SCRAPER_EAI
    ALLOWED_NETWORK_RULES = (SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_BRAND_SCRAPER_RULE)
    ENABLED = TRUE
    COMMENT = 'DEMO: EAI for SI Brand Configurator (Expires: 2026-06-10)';

GRANT USAGE ON INTEGRATION SFE_BRAND_SCRAPER_EAI TO ROLE SYSADMIN;
USE ROLE SYSADMIN;
USE SCHEMA SFE_SI_BRAND_CONFIGURATOR;

-- ============================================================================
-- 3. Helper procedure: add a domain to the network rule before scraping
--    EXECUTE AS OWNER (SYSADMIN) which owns the network rule and can ALTER it.
-- ============================================================================
CREATE OR REPLACE PROCEDURE SFE_ADD_SCRAPER_DOMAIN(DOMAIN VARCHAR)
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'run'
    EXECUTE AS OWNER
    COMMENT = 'DEMO: Dynamically add a domain to the brand scraper network rule (Expires: 2026-06-10)'
AS $$
def run(session, domain):
    if not domain or not isinstance(domain, str):
        return "invalid domain"
    domain = domain.strip().lower()
    if "/" in domain or " " in domain:
        return "invalid domain"
    port_443 = domain + ":443"
    port_80 = domain + ":80"
    try:
        rows = session.sql(
            "SELECT SYSTEM$GET_NETWORK_RULE_TEXT("
            "'SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_BRAND_SCRAPER_RULE'"
            ") AS rule_text"
        ).collect()
        current = rows[0]["RULE_TEXT"] if rows else ""
    except Exception:
        current = ""
    if port_443 in current:
        return "already present"
    new_entries = port_443 + "," + port_80
    if current:
        new_entries = current.rstrip(")").lstrip("(") + "," + port_443 + "," + port_80
    sql = (
        "ALTER NETWORK RULE SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_BRAND_SCRAPER_RULE "
        "SET VALUE_LIST = (" + ",".join("'" + v.strip() + "'" for v in new_entries.split(",") if v.strip()) + ")"
    )
    session.sql(sql).collect()
    return "added " + domain
$$;

GRANT USAGE ON PROCEDURE SFE_ADD_SCRAPER_DOMAIN(VARCHAR) TO ROLE PUBLIC;

-- ============================================================================
-- 4. Internal stage for Streamlit app files
-- ============================================================================
CREATE OR REPLACE STAGE SFE_SI_BRAND_CONFIGURATOR_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'DEMO: Stage for SI Brand Configurator Streamlit app (Expires: 2026-06-10)';

-- ============================================================================
-- 5. Setup procedure: writes the Streamlit app to the stage
-- ============================================================================
CREATE OR REPLACE PROCEDURE SFE_SETUP_APP()
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'run'
    COMMENT = 'DEMO: Upload SI Brand Configurator Streamlit code to stage (Expires: 2026-06-10)'
AS $$
import io

def run(session):
    streamlit_code = '''import streamlit as st
import json
import re
from snowflake.snowpark.context import get_active_session
from urllib.parse import urlparse

session = get_active_session()

SCRAPING_AVAILABLE = False
try:
    import requests
    from bs4 import BeautifulSoup
    SCRAPING_AVAILABLE = True
except ImportError:
    pass

st.set_page_config(
    page_title="SI Brand Configurator",
    page_icon=":briefcase:",
    layout="wide",
)

INDUSTRIES = [
    "Financial Services",
    "Retail / CPG",
    "Healthcare",
    "Technology / SaaS",
    "Manufacturing",
    "Media / Entertainment",
    "Generic",
]

AVATAR_MAP = {
    "Financial Services": "chart-line",
    "Retail / CPG": "shopping-cart",
    "Healthcare": "heart-pulse",
    "Technology / SaaS": "cpu",
    "Manufacturing": "wrench",
    "Media / Entertainment": "film",
    "Generic": "message-square",
}

NL = chr(10)
DQ = chr(34)
DOLLAR = chr(36)


def extract_brand_from_html(url):
    resp = requests.get(url, timeout=15, headers={"User-Agent": "Mozilla/5.0"})
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    brand = {"url": url, "colors": [], "logos": [], "favicons": []}

    title_tag = soup.find("title")
    brand["title"] = title_tag.get_text(strip=True) if title_tag else ""

    og_name = soup.find("meta", property="og:site_name")
    brand["og_site_name"] = og_name["content"] if og_name and og_name.get("content") else ""

    meta_desc = soup.find("meta", attrs={"name": "description"})
    brand["description"] = meta_desc["content"] if meta_desc and meta_desc.get("content") else ""

    og_desc = soup.find("meta", property="og:description")
    if not brand["description"] and og_desc and og_desc.get("content"):
        brand["description"] = og_desc["content"]

    theme_color = soup.find("meta", attrs={"name": "theme-color"})
    if theme_color and theme_color.get("content"):
        brand["colors"].append(theme_color["content"])

    og_image = soup.find("meta", property="og:image")
    if og_image and og_image.get("content"):
        brand["logos"].append(og_image["content"])

    for link in soup.find_all("link", rel=True):
        rel = " ".join(link.get("rel", []))
        href = link.get("href", "")
        if not href:
            continue
        if href.startswith("/"):
            parsed = urlparse(url)
            href = parsed.scheme + "://" + parsed.netloc + href
        if "apple-touch-icon" in rel:
            brand["logos"].append(href)
        elif "icon" in rel:
            brand["favicons"].append(href)

    for img in soup.find_all("img", src=True):
        src = img.get("src", "")
        alt = img.get("alt", "").lower()
        cls = " ".join(img.get("class", [])).lower()
        if "logo" in src.lower() or "logo" in alt or "logo" in cls:
            if src.startswith("/"):
                parsed = urlparse(url)
                src = parsed.scheme + "://" + parsed.netloc + src
            brand["logos"].append(src)

    hex_pattern = re.compile(r"#[0-9a-fA-F]{6}")
    for style in soup.find_all("style"):
        if style.string:
            found = hex_pattern.findall(style.string)
            brand["colors"].extend(found[:10])

    return brand


def analyze_brand_with_cortex(raw_brand):
    industries_str = ", ".join(INDUSTRIES)
    avatars_str = ", ".join(set(AVATAR_MAP.values()))

    prompt_lines = [
        "You are a brand analyst. Given the following information scraped from a company website,",
        "produce a JSON object with these exact keys:",
        "",
        "- company_name: the company name (string)",
        "- industry: one of [" + industries_str + "] (string)",
        "- primary_color: the primary brand hex color like #RRGGBB (string)",
        "- display_name: a suggested Snowflake Intelligence portal name, e.g. 'Acme Insights' (string)",
        "- welcome_message: a 1-2 sentence welcome greeting for the SI portal (string)",
        "- agent_system: system instructions for an AI data assistant at this company, 2-3 sentences (string)",
        "- sample_questions: 5 example business questions an employee might ask (array of strings)",
        "- avatar: one of [" + avatars_str + "] based on industry (string)",
        "",
        "Return ONLY valid JSON, no markdown fences, no explanation.",
        "",
        "Scraped data:",
        "  Title: " + (raw_brand.get("title") or "unknown"),
        "  OG Site Name: " + (raw_brand.get("og_site_name") or "unknown"),
        "  Description: " + (raw_brand.get("description") or "unknown"),
        "  Colors found: " + ", ".join(raw_brand.get("colors", [])[:5]),
        "  Logo URLs: " + ", ".join(raw_brand.get("logos", [])[:3]),
        "  URL: " + raw_brand.get("url", ""),
    ]
    prompt = NL.join(prompt_lines)

    result = session.sql(
        "SELECT SNOWFLAKE.CORTEX.COMPLETE(?, ?) AS result",
        params=["claude-4-sonnet", prompt],
    ).collect()

    raw = result[0]["RESULT"]
    raw = raw.strip()
    if raw.startswith("```"):
        first_nl = raw.find(NL)
        raw = raw[first_nl + 1:] if first_nl >= 0 else raw[3:]
    if raw.rstrip().endswith("```"):
        raw = raw.rstrip()[:-3].rstrip()
    return json.loads(raw)


def generate_deploy_sql(bp):
    company = bp.get("company_name", "Demo Company")
    safe_name = re.sub(r"[^A-Za-z0-9]", "_", company).upper().strip("_")
    schema_name = "SFE_" + safe_name[:40]
    wh_name = schema_name + "_WH"
    agent_name = safe_name[:40] + "_AGENT"
    sv_name = "SV_" + safe_name[:40]
    color = bp.get("primary_color", "#29B5E8")
    display_name = bp.get("display_name", company + " Insights")
    avatar = bp.get("avatar", "message-square")
    system_instr = bp.get("agent_system", "You are a helpful data assistant.")
    sample_qs = bp.get("sample_questions", [])

    profile_json = json.dumps({
        "display_name": display_name,
        "avatar": avatar,
        "color": color,
    })

    sq_yaml_lines = []
    for sq in sample_qs[:5]:
        sq_yaml_lines.append("      - question: " + DQ + sq.replace(DQ, "'") + DQ)
        sq_yaml_lines.append("        answer: " + DQ + "I will analyze the data to answer that." + DQ)
    sq_yaml = NL.join(sq_yaml_lines)

    lines = []
    lines.append("-- ============================================================================")
    lines.append("-- BRANDED SNOWFLAKE INTELLIGENCE AGENT: " + company)
    lines.append("-- Generated by SI Brand Configurator")
    lines.append("-- ============================================================================")
    lines.append("")
    lines.append("USE ROLE SYSADMIN;")
    lines.append("")
    lines.append("CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE")
    lines.append("    COMMENT = 'Shared database for SE demonstration projects and tools';")
    lines.append("")
    lines.append("CREATE WAREHOUSE IF NOT EXISTS " + wh_name)
    lines.append("    WAREHOUSE_SIZE = 'X-SMALL'")
    lines.append("    AUTO_SUSPEND = 60")
    lines.append("    AUTO_RESUME = TRUE")
    lines.append("    COMMENT = 'DEMO: " + company + " branded agent compute';")
    lines.append("")
    lines.append("USE WAREHOUSE " + wh_name + ";")
    lines.append("USE DATABASE SNOWFLAKE_EXAMPLE;")
    lines.append("")
    lines.append("CREATE SCHEMA IF NOT EXISTS " + schema_name)
    lines.append("    COMMENT = 'DEMO: " + company + " branded SI agent';")
    lines.append("")
    lines.append("USE SCHEMA " + schema_name + ";")
    lines.append("")
    lines.append("-- ============================================================================")
    lines.append("-- SAMPLE DATA")
    lines.append("-- ============================================================================")
    lines.append("CREATE OR REPLACE TABLE PRODUCTS (")
    lines.append("    product_id INT,")
    lines.append("    product_name VARCHAR(100),")
    lines.append("    category VARCHAR(50),")
    lines.append("    unit_price NUMBER(10,2)")
    lines.append(") COMMENT = 'DEMO: Sample product catalog';")
    lines.append("")
    lines.append("INSERT INTO PRODUCTS VALUES")
    lines.append("    (1, 'Enterprise Platform', 'Software', 15000.00),")
    lines.append("    (2, 'Professional Suite', 'Software', 8500.00),")
    lines.append("    (3, 'Starter Package', 'Software', 2500.00),")
    lines.append("    (4, 'Consulting Services', 'Services', 25000.00),")
    lines.append("    (5, 'Training Program', 'Services', 5000.00),")
    lines.append("    (6, 'Support Premium', 'Support', 12000.00),")
    lines.append("    (7, 'Support Standard', 'Support', 4000.00),")
    lines.append("    (8, 'Data Add-on', 'Add-ons', 3000.00);")
    lines.append("")
    lines.append("CREATE OR REPLACE TABLE CUSTOMERS (")
    lines.append("    customer_id INT,")
    lines.append("    customer_name VARCHAR(100),")
    lines.append("    segment VARCHAR(30),")
    lines.append("    region VARCHAR(30),")
    lines.append("    lifetime_value NUMBER(12,2)")
    lines.append(") COMMENT = 'DEMO: Sample customer data';")
    lines.append("")
    lines.append("INSERT INTO CUSTOMERS VALUES")
    lines.append("    (1, 'Northwind Industries', 'Enterprise', 'North America', 450000.00),")
    lines.append("    (2, 'Contoso Ltd', 'Enterprise', 'Europe', 380000.00),")
    lines.append("    (3, 'Fabrikam Inc', 'Mid-Market', 'North America', 125000.00),")
    lines.append("    (4, 'Tailspin Toys', 'Mid-Market', 'Asia Pacific', 98000.00),")
    lines.append("    (5, 'Alpine Ski House', 'SMB', 'Europe', 42000.00),")
    lines.append("    (6, 'Bellows College', 'SMB', 'North America', 35000.00);")
    lines.append("")
    lines.append("CREATE OR REPLACE TABLE ORDERS (")
    lines.append("    order_id INT,")
    lines.append("    order_date DATE,")
    lines.append("    customer_id INT,")
    lines.append("    product_id INT,")
    lines.append("    quantity INT,")
    lines.append("    revenue NUMBER(12,2),")
    lines.append("    region VARCHAR(30)")
    lines.append(") COMMENT = 'DEMO: Sample order transactions';")
    lines.append("")
    lines.append("INSERT INTO ORDERS VALUES")
    lines.append("    (1, '2025-01-15', 1, 1, 2, 30000.00, 'North America'),")
    lines.append("    (2, '2025-01-22', 2, 2, 3, 25500.00, 'Europe'),")
    lines.append("    (3, '2025-02-10', 3, 3, 5, 12500.00, 'North America'),")
    lines.append("    (4, '2025-02-18', 1, 4, 1, 25000.00, 'North America'),")
    lines.append("    (5, '2025-03-05', 4, 1, 1, 15000.00, 'Asia Pacific'),")
    lines.append("    (6, '2025-03-12', 5, 7, 2, 8000.00, 'Europe'),")
    lines.append("    (7, '2025-04-01', 2, 6, 1, 12000.00, 'Europe'),")
    lines.append("    (8, '2025-04-15', 6, 3, 3, 7500.00, 'North America'),")
    lines.append("    (9, '2025-05-02', 1, 8, 4, 12000.00, 'North America'),")
    lines.append("    (10, '2025-05-20', 3, 5, 2, 10000.00, 'North America'),")
    lines.append("    (11, '2025-06-10', 4, 2, 2, 17000.00, 'Asia Pacific'),")
    lines.append("    (12, '2025-06-25', 5, 3, 1, 2500.00, 'Europe'),")
    lines.append("    (13, '2025-07-08', 2, 1, 1, 15000.00, 'Europe'),")
    lines.append("    (14, '2025-07-22', 6, 5, 1, 5000.00, 'North America'),")
    lines.append("    (15, '2025-08-14', 1, 6, 1, 12000.00, 'North America');")
    lines.append("")
    lines.append("-- ============================================================================")
    lines.append("-- SEMANTIC VIEW")
    lines.append("-- ============================================================================")
    lines.append("CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS;")
    lines.append("USE SCHEMA SEMANTIC_MODELS;")
    lines.append("")
    lines.append("CREATE OR REPLACE SEMANTIC VIEW " + sv_name)
    lines.append("")
    lines.append("  TABLES (")
    lines.append("    products AS SNOWFLAKE_EXAMPLE." + schema_name + ".PRODUCTS")
    lines.append("      PRIMARY KEY (product_id)")
    lines.append("      COMMENT = 'Product catalog with pricing',")
    lines.append("")
    lines.append("    customers AS SNOWFLAKE_EXAMPLE." + schema_name + ".CUSTOMERS")
    lines.append("      PRIMARY KEY (customer_id)")
    lines.append("      COMMENT = 'Customer profiles with segmentation',")
    lines.append("")
    lines.append("    orders AS SNOWFLAKE_EXAMPLE." + schema_name + ".ORDERS")
    lines.append("      PRIMARY KEY (order_id)")
    lines.append("      COMMENT = 'Order transactions with revenue'")
    lines.append("  )")
    lines.append("")
    lines.append("  RELATIONSHIPS (")
    lines.append("    orders_to_customers AS orders (customer_id) REFERENCES customers,")
    lines.append("    orders_to_products AS orders (product_id) REFERENCES products")
    lines.append("  )")
    lines.append("")
    lines.append("  FACTS (")
    lines.append("    orders.revenue AS revenue COMMENT = 'Order revenue in dollars',")
    lines.append("    orders.quantity AS quantity COMMENT = 'Units ordered',")
    lines.append("    products.unit_price AS unit_price COMMENT = 'List price per unit',")
    lines.append("    customers.lifetime_value AS lifetime_value COMMENT = 'Customer lifetime value in dollars'")
    lines.append("  )")
    lines.append("")
    lines.append("  DIMENSIONS (")
    lines.append("    products.product_name AS product_name COMMENT = 'Product name',")
    lines.append("    products.category AS category COMMENT = 'Product category: Software, Services, Support, Add-ons',")
    lines.append("    customers.customer_name AS customer_name COMMENT = 'Customer company name',")
    lines.append("    customers.segment AS segment COMMENT = 'Customer segment: Enterprise, Mid-Market, SMB',")
    lines.append("    customers.region AS customer_region COMMENT = 'Customer region',")
    lines.append("    orders.order_date AS order_date COMMENT = 'Date of order',")
    lines.append("    orders.region AS order_region COMMENT = 'Region where order was placed'")
    lines.append("  )")
    lines.append("")
    lines.append("  METRICS (")
    lines.append("    orders.total_revenue AS SUM(orders.revenue) COMMENT = 'Total revenue',")
    lines.append("    orders.order_count AS COUNT(orders.order_id) COMMENT = 'Number of orders',")
    lines.append("    orders.avg_order_value AS AVG(orders.revenue) COMMENT = 'Average order value',")
    lines.append("    customers.customer_count AS COUNT(DISTINCT customers.customer_id) COMMENT = 'Unique customers'")
    lines.append("  )")
    lines.append("")
    lines.append("  COMMENT = 'DEMO: " + company + " sales analytics semantic view'")
    lines.append("")
    lines.append("  AI_SQL_GENERATION")
    lines.append("    'This semantic view covers sales data for " + company + ". It has three tables: PRODUCTS (catalog),")
    lines.append("     CUSTOMERS (profiles with segment and region), and ORDERS (transactions with revenue).")
    lines.append("     Orders link to customers via customer_id and to products via product_id.")
    lines.append("     For revenue analysis, use the revenue column in orders.")
    lines.append("     For customer analysis, join orders to customers.")
    lines.append("     For product performance, join orders to products.';")
    lines.append("")
    lines.append("GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS." + sv_name + " TO ROLE PUBLIC;")
    lines.append("")
    lines.append("-- ============================================================================")
    lines.append("-- AGENT")
    lines.append("-- ============================================================================")
    lines.append("USE SCHEMA " + schema_name + ";")
    lines.append("")
    lines.append("CREATE OR REPLACE AGENT " + agent_name)
    lines.append("  COMMENT = 'DEMO: " + company + " branded Intelligence agent'")
    lines.append("  PROFILE = '" + profile_json.replace("'", "''") + "'")
    lines.append("  FROM SPECIFICATION")
    lines.append("  " + DOLLAR + DOLLAR)
    lines.append("  orchestration:")
    lines.append("    budget:")
    lines.append("      seconds: 30")
    lines.append("      tokens: 16000")
    lines.append("")
    lines.append("  instructions:")
    lines.append("    system: >")
    lines.append("      " + system_instr.replace(NL, " "))
    lines.append("      All data in this system is synthetic and for demonstration only.")
    lines.append("")
    lines.append("    response: >")
    lines.append("      Format data in clear Markdown tables. Round dollar amounts appropriately.")
    lines.append("      When comparing across categories, sort by highest value first.")
    lines.append("")
    if sq_yaml:
        lines.append("    sample_questions:")
        lines.append(sq_yaml)
        lines.append("")
    lines.append("  tools:")
    lines.append("    - tool_spec:")
    lines.append("        type: " + DQ + "cortex_analyst_text_to_sql" + DQ)
    lines.append("        name: " + DQ + "DataAnalyst" + DQ)
    lines.append("        description: >")
    lines.append("          Converts natural language into SQL queries against " + company + " sales data.")
    lines.append("          Covers products, customers (segments and regions), and order transactions")
    lines.append("          with revenue and quantity. Use for revenue trends, product performance,")
    lines.append("          customer analysis, and regional breakdowns.")
    lines.append("    - tool_spec:")
    lines.append("        type: " + DQ + "data_to_chart" + DQ)
    lines.append("        name: " + DQ + "data_to_chart" + DQ)
    lines.append("        description: " + DQ + "Generates charts from query results." + DQ)
    lines.append("")
    lines.append("  tool_resources:")
    lines.append("    DataAnalyst:")
    lines.append("      semantic_view: " + DQ + "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS." + sv_name + DQ)
    lines.append("  " + DOLLAR + DOLLAR + ";")
    lines.append("")
    lines.append("-- Grants")
    lines.append("GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE." + schema_name + " TO ROLE PUBLIC;")
    lines.append("GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS TO ROLE PUBLIC;")
    lines.append("GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE." + schema_name + " TO ROLE PUBLIC;")
    lines.append("GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE." + schema_name + "." + agent_name + " TO ROLE PUBLIC;")
    lines.append("")
    lines.append("-- Register with Snowflake Intelligence")
    lines.append("USE ROLE ACCOUNTADMIN;")
    lines.append("CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;")
    lines.append("GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;")
    lines.append("ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT")
    lines.append("  ADD AGENT SNOWFLAKE_EXAMPLE." + schema_name + "." + agent_name + ";")
    lines.append("USE ROLE SYSADMIN;")
    lines.append("")
    lines.append("SELECT 'DEPLOYMENT COMPLETE -- " + company + " agent is ready' AS status;")

    return NL.join(lines)


def generate_teardown_sql(bp):
    company = bp.get("company_name", "Demo Company")
    safe_name = re.sub(r"[^A-Za-z0-9]", "_", company).upper().strip("_")
    schema_name = "SFE_" + safe_name[:40]
    wh_name = schema_name + "_WH"
    sv_name = "SV_" + safe_name[:40]
    agent_name = safe_name[:40] + "_AGENT"

    lines = []
    lines.append("-- TEARDOWN: " + company + " branded agent")
    lines.append("USE ROLE ACCOUNTADMIN;")
    lines.append("ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT")
    lines.append("  DROP AGENT SNOWFLAKE_EXAMPLE." + schema_name + "." + agent_name + ";")
    lines.append("USE ROLE SYSADMIN;")
    lines.append("DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS." + sv_name + ";")
    lines.append("DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE." + schema_name + " CASCADE;")
    lines.append("DROP WAREHOUSE IF EXISTS " + wh_name + ";")
    lines.append("SELECT 'TEARDOWN COMPLETE -- " + company + " agent removed' AS status;")
    return NL.join(lines)


def generate_ui_guide(bp):
    company = bp.get("company_name", "Demo Company")
    display_name = bp.get("display_name", company + " Insights")
    welcome = bp.get("welcome_message", "Welcome! Ask me anything about our data.")
    color = bp.get("primary_color", "#29B5E8")
    logos = bp.get("logos", [])
    favicons = bp.get("favicons", [])

    lines = []
    lines.append("# Snowflake Intelligence UI Branding Guide")
    lines.append("")
    lines.append("After running the deploy SQL above, follow these steps to brand the SI interface.")
    lines.append("")
    lines.append("## Step-by-step")
    lines.append("")
    lines.append("1. Sign in to **Snowsight**")
    lines.append("2. In the left navigation, click **AI & ML** then **Agents**")
    lines.append("3. Click **Open settings** (upper right)")
    lines.append("4. Under **Snowflake Intelligence**, set the following:")
    lines.append("")
    lines.append("## Values to paste")
    lines.append("")
    lines.append("| Setting | Value |")
    lines.append("|---------|-------|")
    lines.append("| Display name | `" + display_name + "` |")
    lines.append("| Welcome message | `" + welcome.replace("|", "-") + "` |")
    lines.append("| Color theme | `" + color + "` |")

    if logos:
        lines.append("| Full-length logo | Download from: `" + logos[0] + "` then upload |")
    else:
        lines.append("| Full-length logo | _(not detected -- upload customer logo manually)_ |")

    if favicons:
        lines.append("| Compact logo | Download from: `" + favicons[0] + "` then upload |")
    elif len(logos) > 1:
        lines.append("| Compact logo | Download from: `" + logos[1] + "` then upload |")
    else:
        lines.append("| Compact logo | _(use a square version of the company logo)_ |")

    lines.append("")
    lines.append("5. Click **Save**")
    lines.append("")
    lines.append("## Access the branded experience")
    lines.append("")
    lines.append("Navigate to **https://ai.snowflake.com** or click")
    lines.append("**Preview in Snowflake Intelligence** from the Agents page.")
    lines.append("The interface will show the customer branding with their")
    lines.append("logo, colors, and welcome message.")

    return NL.join(lines)


st.title("Snowflake Intelligence Brand Configurator")
st.caption("Paste a customer website URL to auto-extract their brand, then generate a deployable SI agent.")

if "brand" not in st.session_state:
    st.session_state.brand = None

tab_auto, tab_manual = st.tabs(["Auto-extract from URL", "Manual input"])

with tab_auto:
    if not SCRAPING_AVAILABLE:
        st.warning(
            "Web scraping libraries not available. "
            "Ensure the Streamlit app has an External Access Integration attached "
            "and that requests and beautifulsoup4 are importable. "
            "Use the Manual input tab as a fallback."
        )
    else:
        url_input = st.text_input(
            "Customer website URL",
            placeholder="https://www.acme.com",
            key="url_input",
        )
        if st.button("Extract Brand", type="primary", disabled=not url_input):
            hostname = urlparse(url_input).hostname
            if hostname:
                try:
                    session.sql(
                        "CALL SFE_ADD_SCRAPER_DOMAIN(?)", [hostname]
                    ).collect()
                except Exception:
                    pass
            with st.spinner("Fetching website and extracting brand signals..."):
                try:
                    raw = extract_brand_from_html(url_input)
                    st.success("Brand signals extracted. Analyzing with Cortex...")
                except Exception as e:
                    st.error(
                        "Could not fetch website. The domain may need to be "
                        "added to the network rule. Error: " + str(e)
                    )
                    raw = None

            if raw:
                with st.spinner("Analyzing brand with Cortex COMPLETE..."):
                    try:
                        analyzed = analyze_brand_with_cortex(raw)
                        analyzed["logos"] = raw.get("logos", [])
                        analyzed["favicons"] = raw.get("favicons", [])
                        analyzed["url"] = url_input
                        st.session_state.brand = analyzed
                        st.success("Brand analysis complete!")
                    except Exception as e:
                        st.error("Cortex analysis failed: " + str(e))

with tab_manual:
    st.write("Enter brand details manually:")
    col1, col2 = st.columns(2)
    with col1:
        m_name = st.text_input("Company name", key="m_name")
        m_color = st.color_picker("Primary brand color", "#29B5E8", key="m_color")
        m_industry = st.selectbox("Industry", INDUSTRIES, key="m_industry")
    with col2:
        m_logo = st.text_input("Logo URL", key="m_logo", placeholder="https://...")
        m_favicon = st.text_input("Favicon / compact logo URL", key="m_fav", placeholder="https://...")
        m_display = st.text_input("SI display name", key="m_display", placeholder="Acme Insights")

    if st.button("Use manual input", type="primary", disabled=not m_name):
        avatar = AVATAR_MAP.get(m_industry, "message-square")
        display = m_display if m_display else m_name + " Insights"
        welcome = "Welcome to " + display + ". Ask me about sales, customers, and business performance."
        system_instr = (
            "You are the " + display + " assistant for " + m_name + ". "
            "You help business users analyze sales performance, customer trends, "
            "and product metrics using natural language."
        )
        st.session_state.brand = {
            "company_name": m_name,
            "industry": m_industry,
            "primary_color": m_color,
            "display_name": display,
            "welcome_message": welcome,
            "agent_system": system_instr,
            "sample_questions": [
                "What is our total revenue by region?",
                "Which products generated the most revenue?",
                "Show me our top customers by lifetime value.",
                "How are sales trending month over month?",
                "What is the average order value by customer segment?",
            ],
            "avatar": avatar,
            "logos": [m_logo] if m_logo else [],
            "favicons": [m_favicon] if m_favicon else [],
        }
        st.success("Brand profile ready!")

if st.session_state.brand:
    bp = st.session_state.brand
    st.divider()
    st.header("Brand Preview")

    pc1, pc2, pc3 = st.columns([1, 1, 2])
    with pc1:
        st.markdown(
            '<div style="width:60px;height:60px;border-radius:8px;background-color:'
            + bp.get("primary_color", "#29B5E8")
            + ';"></div>',
            unsafe_allow_html=True,
        )
        st.caption("Primary color: " + bp.get("primary_color", ""))
    with pc2:
        if bp.get("logos"):
            st.image(bp["logos"][0], width=120)
        else:
            st.info("No logo detected")
    with pc3:
        st.markdown("**Company:** " + bp.get("company_name", ""))
        st.markdown("**Industry:** " + bp.get("industry", ""))
        st.markdown("**Display name:** " + bp.get("display_name", ""))

    st.subheader("Editable fields")
    st.caption("Override any auto-detected value before generating.")

    e1, e2 = st.columns(2)
    with e1:
        bp["company_name"] = st.text_input("Company name", value=bp.get("company_name", ""), key="e_name")
        bp["primary_color"] = st.color_picker("Brand color", value=bp.get("primary_color", "#29B5E8"), key="e_color")
        bp["industry"] = st.selectbox(
            "Industry",
            INDUSTRIES,
            index=INDUSTRIES.index(bp["industry"]) if bp.get("industry") in INDUSTRIES else len(INDUSTRIES) - 1,
            key="e_industry",
        )
    with e2:
        bp["display_name"] = st.text_input("SI display name", value=bp.get("display_name", ""), key="e_display")
        bp["welcome_message"] = st.text_area("Welcome message", value=bp.get("welcome_message", ""), key="e_welcome", height=80)
        bp["avatar"] = AVATAR_MAP.get(bp["industry"], "message-square")

    bp["agent_system"] = st.text_area("Agent system instructions", value=bp.get("agent_system", ""), key="e_system", height=80)

    sq_text = NL.join(bp.get("sample_questions", []))
    edited_sq = st.text_area("Sample questions (one per line)", value=sq_text, key="e_sq", height=120)
    bp["sample_questions"] = [q.strip() for q in edited_sq.split(NL) if q.strip()]

    st.divider()

    if st.button("Generate Branded Agent", type="primary", use_container_width=True):
        st.session_state.generated = True

    if st.session_state.get("generated"):
        deploy_sql = generate_deploy_sql(bp)
        teardown_sql = generate_teardown_sql(bp)
        ui_guide = generate_ui_guide(bp)

        out1, out2, out3 = st.tabs(["Deploy SQL", "Teardown SQL", "UI Branding Guide"])

        with out1:
            st.code(deploy_sql, language="sql")
            st.download_button(
                "Download deploy.sql",
                data=deploy_sql,
                file_name="deploy_" + re.sub(r"[^a-z0-9]", "_", bp["company_name"].lower()) + ".sql",
                mime="text/plain",
                use_container_width=True,
            )

        with out2:
            st.code(teardown_sql, language="sql")
            st.download_button(
                "Download teardown.sql",
                data=teardown_sql,
                file_name="teardown_" + re.sub(r"[^a-z0-9]", "_", bp["company_name"].lower()) + ".sql",
                mime="text/plain",
                use_container_width=True,
            )

        with out3:
            st.markdown(ui_guide)

st.markdown("---")
st.caption("SI Brand Configurator | SE Community | Expires: 2026-06-10")'''

    buf = io.BytesIO(streamlit_code.encode("utf-8"))
    session.file.put_stream(
        buf,
        "@SFE_SI_BRAND_CONFIGURATOR_STAGE/streamlit_app.py",
        auto_compress=False,
        overwrite=True,
    )
    return "streamlit_app.py uploaded"
$$;

CALL SFE_SETUP_APP();

-- ============================================================================
-- 6. Create the Streamlit application with EAI for web scraping
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STREAMLIT SFE_SI_BRAND_CONFIGURATOR
    ROOT_LOCATION  = '@SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_SI_BRAND_CONFIGURATOR_STAGE'
    MAIN_FILE      = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_SI_BRAND_CONFIGURATOR_WH
    EXTERNAL_ACCESS_INTEGRATIONS = (SFE_BRAND_SCRAPER_EAI)
    COMMENT = 'DEMO: SI Brand Configurator -- generate branded SI agents from customer websites (Expires: 2026-06-10)';

GRANT USAGE ON STREAMLIT SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_SI_BRAND_CONFIGURATOR
    TO ROLE PUBLIC;

USE ROLE SYSADMIN;

-- ============================================================================
-- Done
-- ============================================================================
SELECT 'SI Brand Configurator deployed -- open the Streamlit app to get started' AS status;
