#!/usr/bin/env python3
"""SI Brand Configurator -- generate a branded Snowflake Intelligence agent
from a customer website URL.

Usage:
    python brand.py https://www.acme.com
    python brand.py https://www.acme.com --connection myconn --output-dir ./out
    python brand.py https://www.acme.com --name "Acme Corp" --color "#E4002B"
"""

import argparse
import json
import os
import re
import sys
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup
import snowflake.connector

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


# ---------------------------------------------------------------------------
# Brand extraction
# ---------------------------------------------------------------------------
def extract_brand_from_html(url: str) -> dict:
    resp = requests.get(url, timeout=15, headers={"User-Agent": "Mozilla/5.0"})
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    brand: dict = {"url": url, "colors": [], "logos": [], "favicons": []}

    title_tag = soup.find("title")
    brand["title"] = title_tag.get_text(strip=True) if title_tag else ""

    og_name = soup.find("meta", property="og:site_name")
    brand["og_site_name"] = (
        og_name["content"] if og_name and og_name.get("content") else ""
    )

    meta_desc = soup.find("meta", attrs={"name": "description"})
    brand["description"] = (
        meta_desc["content"] if meta_desc and meta_desc.get("content") else ""
    )

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
            href = f"{parsed.scheme}://{parsed.netloc}{href}"
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
                src = f"{parsed.scheme}://{parsed.netloc}{src}"
            brand["logos"].append(src)

    hex_pattern = re.compile(r"#[0-9a-fA-F]{6}")
    for style in soup.find_all("style"):
        if style.string:
            found = hex_pattern.findall(style.string)
            brand["colors"].extend(found[:10])

    return brand


# ---------------------------------------------------------------------------
# Cortex COMPLETE brand analysis
# ---------------------------------------------------------------------------
def analyze_brand_with_cortex(conn, raw_brand: dict) -> dict:
    industries_str = ", ".join(INDUSTRIES)
    avatars_str = ", ".join(set(AVATAR_MAP.values()))

    prompt = "\n".join([
        "You are a brand analyst. Given the following information scraped from a company website,",
        "produce a JSON object with these exact keys:",
        "",
        "- company_name: the company name (string)",
        f"- industry: one of [{industries_str}] (string)",
        "- primary_color: the primary brand hex color like #RRGGBB (string)",
        "- display_name: a suggested Snowflake Intelligence portal name, e.g. 'Acme Insights' (string)",
        "- welcome_message: a 1-2 sentence welcome greeting for the SI portal (string)",
        "- agent_system: system instructions for an AI data assistant at this company, 2-3 sentences (string)",
        "- sample_questions: 5 example business questions an employee might ask (array of strings)",
        f"- avatar: one of [{avatars_str}] based on industry (string)",
        "",
        "Return ONLY valid JSON, no markdown fences, no explanation.",
        "",
        "Scraped data:",
        f"  Title: {raw_brand.get('title') or 'unknown'}",
        f"  OG Site Name: {raw_brand.get('og_site_name') or 'unknown'}",
        f"  Description: {raw_brand.get('description') or 'unknown'}",
        f"  Colors found: {', '.join(raw_brand.get('colors', [])[:5])}",
        f"  Logo URLs: {', '.join(raw_brand.get('logos', [])[:3])}",
        f"  URL: {raw_brand.get('url', '')}",
    ])

    cur = conn.cursor()
    cur.execute("SELECT SNOWFLAKE.CORTEX.COMPLETE(%s, %s)", ("claude-4-sonnet", prompt))
    raw = cur.fetchone()[0]
    cur.close()

    raw = raw.strip()
    if raw.startswith("```"):
        first_nl = raw.find("\n")
        raw = raw[first_nl + 1:] if first_nl >= 0 else raw[3:]
    if raw.rstrip().endswith("```"):
        raw = raw.rstrip()[:-3].rstrip()
    return json.loads(raw)


# ---------------------------------------------------------------------------
# SQL generation
# ---------------------------------------------------------------------------
def generate_deploy_sql(bp: dict) -> str:
    company = bp.get("company_name", "Demo Company")
    safe_name = re.sub(r"[^A-Za-z0-9]", "_", company).upper().strip("_")
    schema_name = f"SFE_{safe_name[:40]}"
    wh_name = f"{schema_name}_WH"
    agent_name = f"{safe_name[:40]}_AGENT"
    sv_name = f"SV_{safe_name[:40]}"
    color = bp.get("primary_color", "#29B5E8")
    display_name = bp.get("display_name", f"{company} Insights")
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
        sq_yaml_lines.append(f'      - question: "{sq}"')
        sq_yaml_lines.append(f'        answer: "I will analyze the data to answer that."')
    sq_yaml = "\n".join(sq_yaml_lines)

    return f"""\
-- ============================================================================
-- BRANDED SNOWFLAKE INTELLIGENCE AGENT: {company}
-- Generated by SI Brand Configurator
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools';

CREATE WAREHOUSE IF NOT EXISTS {wh_name}
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'DEMO: {company} branded agent compute';

USE WAREHOUSE {wh_name};
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS {schema_name}
    COMMENT = 'DEMO: {company} branded SI agent';

USE SCHEMA {schema_name};

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================
CREATE OR REPLACE TABLE PRODUCTS (
    product_id INT,
    product_name VARCHAR(100),
    category VARCHAR(50),
    unit_price NUMBER(10,2)
) COMMENT = 'DEMO: Sample product catalog';

INSERT INTO PRODUCTS VALUES
    (1, 'Enterprise Platform', 'Software', 15000.00),
    (2, 'Professional Suite', 'Software', 8500.00),
    (3, 'Starter Package', 'Software', 2500.00),
    (4, 'Consulting Services', 'Services', 25000.00),
    (5, 'Training Program', 'Services', 5000.00),
    (6, 'Support Premium', 'Support', 12000.00),
    (7, 'Support Standard', 'Support', 4000.00),
    (8, 'Data Add-on', 'Add-ons', 3000.00);

CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id INT,
    customer_name VARCHAR(100),
    segment VARCHAR(30),
    region VARCHAR(30),
    lifetime_value NUMBER(12,2)
) COMMENT = 'DEMO: Sample customer data';

INSERT INTO CUSTOMERS VALUES
    (1, 'Northwind Industries', 'Enterprise', 'North America', 450000.00),
    (2, 'Contoso Ltd', 'Enterprise', 'Europe', 380000.00),
    (3, 'Fabrikam Inc', 'Mid-Market', 'North America', 125000.00),
    (4, 'Tailspin Toys', 'Mid-Market', 'Asia Pacific', 98000.00),
    (5, 'Alpine Ski House', 'SMB', 'Europe', 42000.00),
    (6, 'Bellows College', 'SMB', 'North America', 35000.00);

CREATE OR REPLACE TABLE ORDERS (
    order_id INT,
    order_date DATE,
    customer_id INT,
    product_id INT,
    quantity INT,
    revenue NUMBER(12,2),
    region VARCHAR(30)
) COMMENT = 'DEMO: Sample order transactions';

INSERT INTO ORDERS VALUES
    (1, '2025-01-15', 1, 1, 2, 30000.00, 'North America'),
    (2, '2025-01-22', 2, 2, 3, 25500.00, 'Europe'),
    (3, '2025-02-10', 3, 3, 5, 12500.00, 'North America'),
    (4, '2025-02-18', 1, 4, 1, 25000.00, 'North America'),
    (5, '2025-03-05', 4, 1, 1, 15000.00, 'Asia Pacific'),
    (6, '2025-03-12', 5, 7, 2, 8000.00, 'Europe'),
    (7, '2025-04-01', 2, 6, 1, 12000.00, 'Europe'),
    (8, '2025-04-15', 6, 3, 3, 7500.00, 'North America'),
    (9, '2025-05-02', 1, 8, 4, 12000.00, 'North America'),
    (10, '2025-05-20', 3, 5, 2, 10000.00, 'North America'),
    (11, '2025-06-10', 4, 2, 2, 17000.00, 'Asia Pacific'),
    (12, '2025-06-25', 5, 3, 1, 2500.00, 'Europe'),
    (13, '2025-07-08', 2, 1, 1, 15000.00, 'Europe'),
    (14, '2025-07-22', 6, 5, 1, 5000.00, 'North America'),
    (15, '2025-08-14', 1, 6, 1, 12000.00, 'North America');

-- ============================================================================
-- SEMANTIC VIEW
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS;
USE SCHEMA SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW {sv_name}

  TABLES (
    products AS SNOWFLAKE_EXAMPLE.{schema_name}.PRODUCTS
      PRIMARY KEY (product_id)
      COMMENT = 'Product catalog with pricing',

    customers AS SNOWFLAKE_EXAMPLE.{schema_name}.CUSTOMERS
      PRIMARY KEY (customer_id)
      COMMENT = 'Customer profiles with segmentation',

    orders AS SNOWFLAKE_EXAMPLE.{schema_name}.ORDERS
      PRIMARY KEY (order_id)
      COMMENT = 'Order transactions with revenue'
  )

  RELATIONSHIPS (
    orders_to_customers AS orders (customer_id) REFERENCES customers,
    orders_to_products AS orders (product_id) REFERENCES products
  )

  FACTS (
    orders.revenue AS revenue COMMENT = 'Order revenue in dollars',
    orders.quantity AS quantity COMMENT = 'Units ordered',
    products.unit_price AS unit_price COMMENT = 'List price per unit',
    customers.lifetime_value AS lifetime_value COMMENT = 'Customer lifetime value in dollars'
  )

  DIMENSIONS (
    products.product_name AS product_name COMMENT = 'Product name',
    products.category AS category COMMENT = 'Product category: Software, Services, Support, Add-ons',
    customers.customer_name AS customer_name COMMENT = 'Customer company name',
    customers.segment AS segment COMMENT = 'Customer segment: Enterprise, Mid-Market, SMB',
    customers.region AS customer_region COMMENT = 'Customer region',
    orders.order_date AS order_date COMMENT = 'Date of order',
    orders.region AS order_region COMMENT = 'Region where order was placed'
  )

  METRICS (
    orders.total_revenue AS SUM(orders.revenue) COMMENT = 'Total revenue',
    orders.order_count AS COUNT(orders.order_id) COMMENT = 'Number of orders',
    orders.avg_order_value AS AVG(orders.revenue) COMMENT = 'Average order value',
    customers.customer_count AS COUNT(DISTINCT customers.customer_id) COMMENT = 'Unique customers'
  )

  COMMENT = 'DEMO: {company} sales analytics semantic view'

  AI_SQL_GENERATION
    'This semantic view covers sales data for {company}. It has three tables: PRODUCTS (catalog),
     CUSTOMERS (profiles with segment and region), and ORDERS (transactions with revenue).
     Orders link to customers via customer_id and to products via product_id.
     For revenue analysis, use the revenue column in orders.
     For customer analysis, join orders to customers.
     For product performance, join orders to products.';

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.{sv_name} TO ROLE PUBLIC;

-- ============================================================================
-- AGENT
-- ============================================================================
USE SCHEMA {schema_name};

CREATE OR REPLACE AGENT {agent_name}
  COMMENT = 'DEMO: {company} branded Intelligence agent'
  PROFILE = '{profile_json.replace("'", "''")}'
  FROM SPECIFICATION
  $$
  orchestration:
    budget:
      seconds: 30
      tokens: 16000

  instructions:
    system: >
      {system_instr.replace(chr(10), " ")}
      All data in this system is synthetic and for demonstration only.

    response: >
      Format data in clear Markdown tables. Round dollar amounts appropriately.
      When comparing across categories, sort by highest value first.

{"    sample_questions:" + chr(10) + sq_yaml + chr(10) if sq_yaml else ""}\
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "DataAnalyst"
        description: >
          Converts natural language into SQL queries against {company} sales data.
          Covers products, customers (segments and regions), and order transactions
          with revenue and quantity. Use for revenue trends, product performance,
          customer analysis, and regional breakdowns.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates charts from query results."

  tool_resources:
    DataAnalyst:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.{sv_name}"
  $$;

-- Grants
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.{schema_name} TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.{schema_name} TO ROLE PUBLIC;
GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.{schema_name}.{agent_name} TO ROLE PUBLIC;

-- Register with Snowflake Intelligence
USE ROLE ACCOUNTADMIN;
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  ADD AGENT SNOWFLAKE_EXAMPLE.{schema_name}.{agent_name};
USE ROLE SYSADMIN;

SELECT 'DEPLOYMENT COMPLETE -- {company} agent is ready' AS status;
"""


def generate_teardown_sql(bp: dict) -> str:
    company = bp.get("company_name", "Demo Company")
    safe_name = re.sub(r"[^A-Za-z0-9]", "_", company).upper().strip("_")
    schema_name = f"SFE_{safe_name[:40]}"
    wh_name = f"{schema_name}_WH"
    sv_name = f"SV_{safe_name[:40]}"
    agent_name = f"{safe_name[:40]}_AGENT"

    return f"""\
-- TEARDOWN: {company} branded agent
USE ROLE ACCOUNTADMIN;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  DROP AGENT SNOWFLAKE_EXAMPLE.{schema_name}.{agent_name};
USE ROLE SYSADMIN;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.{sv_name};
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.{schema_name} CASCADE;
DROP WAREHOUSE IF EXISTS {wh_name};
SELECT 'TEARDOWN COMPLETE -- {company} agent removed' AS status;
"""


def generate_ui_guide(bp: dict) -> str:
    company = bp.get("company_name", "Demo Company")
    display_name = bp.get("display_name", f"{company} Insights")
    welcome = bp.get("welcome_message", "Welcome! Ask me anything about our data.")
    color = bp.get("primary_color", "#29B5E8")
    logos = bp.get("logos", [])
    favicons = bp.get("favicons", [])

    logo_row = (
        f"| Full-length logo | Download from: `{logos[0]}` then upload |"
        if logos
        else "| Full-length logo | _(not detected -- upload customer logo manually)_ |"
    )

    if favicons:
        compact_row = f"| Compact logo | Download from: `{favicons[0]}` then upload |"
    elif len(logos) > 1:
        compact_row = f"| Compact logo | Download from: `{logos[1]}` then upload |"
    else:
        compact_row = "| Compact logo | _(use a square version of the company logo)_ |"

    return f"""\
# Snowflake Intelligence UI Branding Guide -- {company}

After running the deploy SQL, follow these steps to brand the SI interface.

## Step-by-step

1. Sign in to **Snowsight**
2. In the left navigation, click **AI & ML** then **Agents**
3. Click **Open settings** (upper right)
4. Under **Snowflake Intelligence**, set the following:

## Values to paste

| Setting | Value |
|---------|-------|
| Display name | `{display_name}` |
| Welcome message | `{welcome.replace("|", "-")}` |
| Color theme | `{color}` |
{logo_row}
{compact_row}

5. Click **Save**

## Access the branded experience

Navigate to **https://ai.snowflake.com** or click
**Preview in Snowflake Intelligence** from the Agents page.
The interface will show the customer branding with their
logo, colors, and welcome message.
"""


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Generate a branded Snowflake Intelligence agent from a customer website.",
    )
    parser.add_argument("url", help="Customer website URL (e.g. https://www.acme.com)")
    parser.add_argument(
        "-c", "--connection",
        default="default",
        help="Snowflake connection name from ~/.snowflake/connections.toml (default: 'default')",
    )
    parser.add_argument(
        "-o", "--output-dir",
        default=".",
        help="Directory to write output files (default: current directory)",
    )
    parser.add_argument("--name", help="Override detected company name")
    parser.add_argument("--color", help="Override detected brand color (hex, e.g. #E4002B)")
    parser.add_argument("--industry", choices=INDUSTRIES, help="Override detected industry")
    args = parser.parse_args()

    # --- Scrape ---
    print(f"Fetching {args.url} ...")
    try:
        raw_brand = extract_brand_from_html(args.url)
    except Exception as e:
        print(f"Error fetching URL: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"  Title:  {raw_brand.get('title', '')}")
    print(f"  Colors: {', '.join(raw_brand.get('colors', [])[:5]) or '(none)'}")
    print(f"  Logos:  {len(raw_brand.get('logos', []))} found")

    # --- Cortex COMPLETE ---
    print(f"\nConnecting to Snowflake (connection: {args.connection}) ...")
    try:
        conn = snowflake.connector.connect(connection_name=args.connection)
    except Exception as e:
        print(f"Snowflake connection failed: {e}", file=sys.stderr)
        sys.exit(1)

    print("Analyzing brand with Cortex COMPLETE ...")
    try:
        brand = analyze_brand_with_cortex(conn, raw_brand)
    except Exception as e:
        print(f"Cortex COMPLETE failed: {e}", file=sys.stderr)
        conn.close()
        sys.exit(1)

    conn.close()

    brand["logos"] = raw_brand.get("logos", [])
    brand["favicons"] = raw_brand.get("favicons", [])

    # --- Apply overrides ---
    if args.name:
        brand["company_name"] = args.name
    if args.color:
        brand["primary_color"] = args.color
    if args.industry:
        brand["industry"] = args.industry
        brand["avatar"] = AVATAR_MAP.get(args.industry, "message-square")

    company = brand.get("company_name", "unknown")
    safe = re.sub(r"[^a-z0-9]", "_", company.lower()).strip("_")

    print(f"\n  Company:      {brand.get('company_name')}")
    print(f"  Industry:     {brand.get('industry')}")
    print(f"  Color:        {brand.get('primary_color')}")
    print(f"  Display name: {brand.get('display_name')}")
    print(f"  Avatar:       {brand.get('avatar')}")

    # --- Generate output ---
    os.makedirs(args.output_dir, exist_ok=True)

    deploy_path = os.path.join(args.output_dir, f"deploy_{safe}.sql")
    teardown_path = os.path.join(args.output_dir, f"teardown_{safe}.sql")
    guide_path = os.path.join(args.output_dir, f"ui_guide_{safe}.md")

    with open(deploy_path, "w") as f:
        f.write(generate_deploy_sql(brand))

    with open(teardown_path, "w") as f:
        f.write(generate_teardown_sql(brand))

    with open(guide_path, "w") as f:
        f.write(generate_ui_guide(brand))

    print(f"\nFiles written:")
    print(f"  {deploy_path}")
    print(f"  {teardown_path}")
    print(f"  {guide_path}")
    print(f"\nCopy deploy_{safe}.sql into Snowsight and Run All.")


if __name__ == "__main__":
    main()
