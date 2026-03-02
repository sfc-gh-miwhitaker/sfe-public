/******************************************************************************
 * Tool: API Data Fetcher
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-10
 * Last Updated: 2026-03-02
 * Expires: 2026-05-01
 *
 * Prerequisites:
 *   1. Run shared/sql/00_shared_setup.sql first
 *   2. SYSADMIN role access
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Schema: SNOWFLAKE_EXAMPLE.SFE_API_FETCHER
 *   - Table: SFE_USERS
 *   - Network Rule: SFE_API_NETWORK_RULE
 *   - External Access Integration: SFE_API_ACCESS
 *   - Stored Procedure: SFE_FETCH_USERS
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (Informational — warns but does not block deployment)
-- ============================================================================
SELECT
    '2026-05-01'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;

-- Create shared warehouse if it doesn't exist
CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- CREATE TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SFE_API_FETCHER
    COMMENT = 'TOOL: API Data Fetcher demo | Author: SE Community | Expires: 2026-05-01';

USE SCHEMA SFE_API_FETCHER;

-- ============================================================================
-- CREATE TABLE
-- ============================================================================
CREATE OR REPLACE TABLE SFE_USERS (
    user_id INT,
    name VARCHAR(200),
    username VARCHAR(100),
    email VARCHAR(320),
    phone VARCHAR(50),
    website VARCHAR(200),
    company_name VARCHAR(200),
    city VARCHAR(100),
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (user_id)
)
COMMENT = 'TOOL: Users fetched from JSONPlaceholder API | Author: SE Community | Expires: 2026-05-01';

-- ============================================================================
-- CREATE EXTERNAL ACCESS INTEGRATION
-- ============================================================================

-- Network rule for JSONPlaceholder API
CREATE OR REPLACE NETWORK RULE SFE_API_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('jsonplaceholder.typicode.com:443')
    COMMENT = 'TOOL: Allow egress to JSONPlaceholder API | Author: SE Community | Expires: 2026-05-01';

-- External access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFE_API_ACCESS
    ALLOWED_NETWORK_RULES = (SFE_API_NETWORK_RULE)
    ENABLED = TRUE
    COMMENT = 'TOOL: External access for JSONPlaceholder API | Author: SE Community | Expires: 2026-05-01';

-- ============================================================================
-- CREATE STORED PROCEDURE
-- ============================================================================
CREATE OR REPLACE PROCEDURE SFE_FETCH_USERS()
    RETURNS TABLE(user_id INT, name VARCHAR, username VARCHAR, email VARCHAR, phone VARCHAR, website VARCHAR, company_name VARCHAR, city VARCHAR)
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python', 'requests')
    HANDLER = 'fetch_users'
    EXTERNAL_ACCESS_INTEGRATIONS = (SFE_API_ACCESS)
    COMMENT = 'TOOL: Fetches user data from JSONPlaceholder API | Author: SE Community | Expires: 2026-05-01'
AS
$$
import requests
from snowflake.snowpark import Session
from snowflake.snowpark.types import StructType, StructField, IntegerType, StringType

def fetch_users(session: Session):
    """
    Fetches user data from JSONPlaceholder API and stores in Snowflake.

    API: https://jsonplaceholder.typicode.com/users
    Returns: Table of fetched user data
    """
    response = requests.get(
        'https://jsonplaceholder.typicode.com/users',
        timeout=30
    )
    response.raise_for_status()
    users = response.json()

    rows = []
    for user in users:
        rows.append([
            user['id'],
            user['name'],
            user['username'],
            user['email'],
            user['phone'],
            user['website'],
            user.get('company', {}).get('name', ''),
            user.get('address', {}).get('city', '')
        ])

    schema = StructType([
        StructField("USER_ID", IntegerType()),
        StructField("NAME", StringType()),
        StructField("USERNAME", StringType()),
        StructField("EMAIL", StringType()),
        StructField("PHONE", StringType()),
        StructField("WEBSITE", StringType()),
        StructField("COMPANY_NAME", StringType()),
        StructField("CITY", StringType())
    ])

    session.sql("DELETE FROM SFE_USERS").collect()

    df = session.create_dataframe(rows, schema=schema)
    df.write.mode("append").save_as_table("SFE_USERS")

    return session.table("SFE_USERS").select(
        "USER_ID", "NAME", "USERNAME", "EMAIL",
        "PHONE", "WEBSITE", "COMPANY_NAME", "CITY"
    )
$$;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'API Data Fetcher' AS tool,
    '2026-05-01' AS expires,
    'Run: CALL SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_FETCH_USERS();' AS next_step;

-- =============================================================================
-- VERIFICATION (Run individually after deployment)
-- =============================================================================

/*
 * -- Test the procedure
 * CALL SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_FETCH_USERS();
 *
 * -- View fetched data
 * SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_USERS;
 *
 * -- Check external access integration
 * SHOW INTEGRATIONS LIKE 'SFE_API_ACCESS';
 */
