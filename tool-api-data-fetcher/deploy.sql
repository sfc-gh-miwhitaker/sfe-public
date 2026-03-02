/******************************************************************************
 * Tool: API Data Fetcher
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-10
 * Expires: 2026-01-09
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
-- EXPIRATION CHECK (MANDATORY)
-- ============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-01-09';
    tool_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-01-09. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE tool_expired;
    END IF;
    RETURN 'Expiration check passed. Tool valid until ' || v_expiration_date::STRING;
END;
$$;

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
    COMMENT = 'TOOL: API Data Fetcher demo | Author: SE Community | Expires: 2026-01-09';

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
COMMENT = 'TOOL: Users fetched from JSONPlaceholder API | Author: SE Community | Expires: 2026-01-09';

-- ============================================================================
-- CREATE EXTERNAL ACCESS INTEGRATION
-- ============================================================================

-- Network rule for JSONPlaceholder API
CREATE OR REPLACE NETWORK RULE SFE_API_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('jsonplaceholder.typicode.com:443')
    COMMENT = 'TOOL: Allow egress to JSONPlaceholder API | Author: SE Community | Expires: 2026-01-09';

-- External access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFE_API_ACCESS
    ALLOWED_NETWORK_RULES = (SFE_API_NETWORK_RULE)
    ENABLED = TRUE
    COMMENT = 'TOOL: External access for JSONPlaceholder API | Author: SE Community | Expires: 2026-01-09';

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
    COMMENT = 'TOOL: Fetches user data from JSONPlaceholder API | Author: SE Community | Expires: 2026-01-09'
AS
$$
import requests
from snowflake.snowpark import Session
from datetime import datetime

def fetch_users(session: Session):
    """
    Fetches user data from JSONPlaceholder API and stores in Snowflake.

    API: https://jsonplaceholder.typicode.com/users
    Returns: Table of fetched user data
    """
    # Fetch from API
    response = requests.get(
        'https://jsonplaceholder.typicode.com/users',
        timeout=30
    )
    response.raise_for_status()
    users = response.json()

    # Clear existing data first
    session.sql("DELETE FROM SFE_USERS").collect()

    # Insert each user using SQL (handles DEFAULT columns properly)
    for user in users:
        # Escape single quotes for SQL safety
        name = user['name'].replace("'", "''")
        username = user['username'].replace("'", "''")
        email = user['email'].replace("'", "''")
        phone = user['phone'].replace("'", "''")
        website = user['website'].replace("'", "''")
        company_name = user.get('company', {}).get('name', '').replace("'", "''")
        city = user.get('address', {}).get('city', '').replace("'", "''")

        insert_sql = f"""
        INSERT INTO SFE_USERS (user_id, name, username, email, phone, website, company_name, city)
        VALUES ({user['id']}, '{name}', '{username}', '{email}', '{phone}', '{website}', '{company_name}', '{city}')
        """
        session.sql(insert_sql).collect()

    # Return results
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
    '2026-01-09' AS expires,
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
