/******************************************************************************
 * Tool: Contact Form (Streamlit in Snowflake)
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
 *   - Schema: SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM
 *   - Table: SFE_SUBMISSIONS
 *   - Streamlit App: SFE_CONTACT_FORM
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
CREATE SCHEMA IF NOT EXISTS SFE_CONTACT_FORM
    COMMENT = 'TOOL: Streamlit contact form demo | Author: SE Community | Expires: 2026-01-09';

USE SCHEMA SFE_CONTACT_FORM;

-- ============================================================================
-- CREATE TABLE
-- ============================================================================
CREATE OR REPLACE TABLE SFE_SUBMISSIONS (
    submission_id INT AUTOINCREMENT,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(320) NOT NULL,
    address VARCHAR(500),
    submitted_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (submission_id)
)
COMMENT = 'TOOL: Contact form submissions | Author: SE Community | Expires: 2026-01-09';

-- ============================================================================
-- CREATE STREAMLIT STAGE AND APP
-- ============================================================================
CREATE OR REPLACE STAGE SFE_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'TOOL: Stage for Streamlit app files | Author: SE Community | Expires: 2026-01-09';

CREATE OR REPLACE STREAMLIT SFE_CONTACT_FORM
    FROM '@SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM.SFE_STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    COMMENT = 'TOOL: Contact form Streamlit app | Author: SE Community | Expires: 2026-01-09';

-- ============================================================================
-- UPLOAD STREAMLIT APP CODE
-- ============================================================================
CREATE OR REPLACE PROCEDURE SFE_SETUP_APP()
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'setup_app'
    COMMENT = 'TOOL: Sets up Streamlit app files | Author: SE Community | Expires: 2026-01-09'
AS
$$
from io import BytesIO

def setup_app(session):
    """Creates the Streamlit app file in the stage."""

    streamlit_code = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Contact Form",
    page_icon="📝",
    layout="centered"
)

# Get Snowflake session
session = get_active_session()

# Header
st.title("📝 Contact Form")
st.markdown("---")

# Info
st.info("**Streamlit in Snowflake Demo** | Form data writes directly to a Snowflake table.")

# Form
with st.form("contact_form", clear_on_submit=True):
    st.subheader("Submit Your Information")

    col1, col2 = st.columns(2)

    with col1:
        full_name = st.text_input("Full Name *", placeholder="Jane Smith")

    with col2:
        email = st.text_input("Email Address *", placeholder="jane@example.com")

    address = st.text_area("Address", placeholder="123 Main Street\\nCity, State 12345")

    submitted = st.form_submit_button("Submit", use_container_width=True)

    if submitted:
        if not full_name or not email:
            st.error("Please fill in all required fields (Name and Email)")
        elif "@" not in email or "." not in email:
            st.error("Please enter a valid email address")
        else:
            try:
                safe_name = full_name.replace("'", "''")
                safe_email = email.replace("'", "''")
                safe_address = address.replace("'", "''") if address else ""

                insert_sql = f"""
                INSERT INTO SFE_SUBMISSIONS (full_name, email, address)
                VALUES ('{safe_name}', '{safe_email}', '{safe_address}')
                """
                session.sql(insert_sql).collect()

                st.success(f"Thank you, {full_name}! Your submission has been saved.")
                st.balloons()
            except Exception as e:
                st.error(f"Error saving submission: {str(e)}")

st.markdown("---")

# Recent submissions
st.subheader("📊 Recent Submissions")

try:
    df = session.sql("""
        SELECT
            submission_id,
            full_name,
            email,
            LEFT(address, 50) || CASE WHEN LENGTH(address) > 50 THEN '...' ELSE '' END AS address_preview,
            submitted_at
        FROM SFE_SUBMISSIONS
        ORDER BY submitted_at DESC
        LIMIT 10
    """).to_pandas()

    if len(df) > 0:
        st.dataframe(df, use_container_width=True)
        total_count = session.sql("SELECT COUNT(*) AS cnt FROM SFE_SUBMISSIONS").collect()[0]["CNT"]
        st.metric("Total Submissions", total_count)
    else:
        st.info("No submissions yet. Be the first to submit!")

except Exception as e:
    st.error(f"Error loading submissions: {str(e)}")

# Footer
st.markdown("---")
st.caption("Streamlit in Snowflake | SE Community | Expires: 2026-01-09")
'''

    # Wrap bytes in BytesIO for put_stream
    file_stream = BytesIO(streamlit_code.encode('utf-8'))

    session.file.put_stream(
        input_stream=file_stream,
        stage_location='@SFE_STREAMLIT_STAGE/streamlit_app.py',
        auto_compress=False,
        overwrite=True
    )

    return "Streamlit app file created successfully"
$$;

-- Run setup
CALL SFE_SETUP_APP();

-- Refresh stage
ALTER STAGE SFE_STREAMLIT_STAGE REFRESH;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Contact Form (Streamlit)' AS tool,
    '2026-01-09' AS expires,
    'Navigate to Projects -> Streamlit -> SFE_CONTACT_FORM' AS next_step;
