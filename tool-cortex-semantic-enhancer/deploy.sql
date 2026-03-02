/*******************************************************************************
 * SNOWFLAKE TOOL: Semantic View Enhancer
 *
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * EXPIRES: 2026-01-15 (30 days from creation)
 * Author: SE Community
 * Status: ACTIVE
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * USAGE IN SNOWSIGHT (FASTEST PATH):
 * ═══════════════════════════════════════════════════════════════════════════
 *   1. Copy this ENTIRE script (Ctrl+A / Cmd+A)
 *   2. Open Snowsight → New Worksheet
 *   3. Paste the script
 *   4. Click "Run All" (top right)
 *   5. Wait ~2 minutes for complete deployment
 *
 * WHAT THIS TOOL DOES:
 *   Enhances Snowflake semantic views with AI-improved dimension and fact
 *   descriptions using Cortex AI. Creates enhanced copies of your semantic
 *   views with business-aware descriptions optimized for Cortex Analyst.
 *
 * OBJECTS CREATED:
 *   Account-Level:
 *     - SFE_ENHANCEMENT_WH (Warehouse, X-SMALL, 60s auto-suspend)
 *
 *   Database Objects (in SNOWFLAKE_EXAMPLE):
 *     - SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS schema
 *     - SFE_ESTIMATE_ENHANCEMENT_COST function
 *     - SFE_DIAGNOSE_ENVIRONMENT procedure
 *     - SFE_ENHANCE_SEMANTIC_VIEW stored procedure (Python 3.11)
 *
 * CLEANUP:
 *   See teardown.sql in this folder
 *
 * ESTIMATED TIME: ~2 minutes
 * ESTIMATED COST: < $0.01 (one-time setup)
 ******************************************************************************/

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 0: Expiration Check (MANDATORY)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT
    CASE
        WHEN CURRENT_DATE > '2026-01-15'::DATE
        THEN 1 / 0  -- Force error: "Division by zero"
        ELSE 1
    END AS expiration_check,
    '✓ Tool is active (expires: 2026-01-15)' AS status,
    DATEDIFF(DAY, CURRENT_DATE, '2026-01-15'::DATE) AS days_remaining;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: Create Database and Schema
-- ═══════════════════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS
  COMMENT = 'DEMO: semantic-view-enhancer - Cortex AI semantic view enhancement | Author: SE Community | Expires: 2026-01-15';

USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: Create Dedicated Warehouse
-- ═══════════════════════════════════════════════════════════════════════════

CREATE WAREHOUSE IF NOT EXISTS SFE_ENHANCEMENT_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: semantic-view-enhancer - Dedicated warehouse for semantic view enhancement | Author: SE Community | Expires: 2026-01-15';

USE WAREHOUSE SFE_ENHANCEMENT_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: Create Cost Estimation Function
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION SFE_ESTIMATE_ENHANCEMENT_COST(
    P_VIEW_NAME STRING,
    P_SCHEMA_NAME STRING DEFAULT CURRENT_SCHEMA(),
    P_DATABASE_NAME STRING DEFAULT CURRENT_DATABASE(),
    P_MODEL STRING DEFAULT 'snowflake-llama-3.3-70b'
)
RETURNS STRING
AS
$$
    SELECT
        COUNT(*) as dimension_count,
        CASE P_MODEL
            WHEN 'llama3.1-8b' THEN COUNT(*) * 0.0015
            WHEN 'llama3.3-70b' THEN COUNT(*) * 0.002
            WHEN 'snowflake-llama-3.3-70b' THEN COUNT(*) * 0.0005
            WHEN 'mistral-large2' THEN COUNT(*) * 0.005
            ELSE COUNT(*) * 0.0005
        END as estimated_cost_usd,
        CONCAT(
            'View has ', COUNT(*), ' dimensions/facts. ',
            'Estimated cost: $',
            TO_CHAR(
                CASE P_MODEL
                    WHEN 'llama3.1-8b' THEN COUNT(*) * 0.0015
                    WHEN 'llama3.3-70b' THEN COUNT(*) * 0.002
                    WHEN 'snowflake-llama-3.3-70b' THEN COUNT(*) * 0.0005
                    WHEN 'mistral-large2' THEN COUNT(*) * 0.005
                    ELSE COUNT(*) * 0.0005
                END,
                '0.00'
            ),
            ' (using model: ', P_MODEL, ')'
        ) as summary
    FROM (
        DESCRIBE SEMANTIC VIEW IDENTIFIER(CONCAT(P_DATABASE_NAME, '.', P_SCHEMA_NAME, '.', P_VIEW_NAME))
    )
    WHERE object_kind IN ('DIMENSION', 'FACT')
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 4: Create Diagnostic Procedure
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE PROCEDURE SFE_DIAGNOSE_ENVIRONMENT()
RETURNS TABLE(check_name STRING, status STRING, message STRING, fix_command STRING)
LANGUAGE SQL
AS
$$
DECLARE
    checks RESULTSET DEFAULT (
        SELECT 'Starting diagnostics...' as check_name, 'INFO' as status, '' as message, '' as fix_command
    );
BEGIN
    LET result RESULTSET := (
        WITH checks AS (
            SELECT 'Cortex AI Access' as check_name,
                   TRY_CAST(AI_COMPLETE('snowflake-llama-3.3-70b', 'Reply with: OK') AS STRING) as test_result,
                   'SELECT AI_COMPLETE(...)' as fix_command
            UNION ALL
            SELECT 'SFE Warehouse Exists' as check_name,
                   (SELECT COUNT(*) FROM INFORMATION_SCHEMA.WAREHOUSES WHERE WAREHOUSE_NAME = 'SFE_ENHANCEMENT_WH')::STRING as test_result,
                   'CREATE WAREHOUSE SFE_ENHANCEMENT_WH...' as fix_command
            UNION ALL
            SELECT 'Enhancement Procedure Exists' as check_name,
                   (SELECT COUNT(*) FROM INFORMATION_SCHEMA.PROCEDURES
                    WHERE PROCEDURE_SCHEMA = 'SEMANTIC_ENHANCEMENTS'
                    AND PROCEDURE_NAME = 'SFE_ENHANCE_SEMANTIC_VIEW')::STRING as test_result,
                   'Run deploy.sql' as fix_command
            UNION ALL
            SELECT 'Sample Data Access' as check_name,
                   TRY_CAST((SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS LIMIT 1) AS STRING) as test_result,
                   'CREATE DATABASE SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA' as fix_command
        )
        SELECT
            check_name,
            CASE
                WHEN check_name = 'Cortex AI Access' AND test_result LIKE '%OK%' THEN '✓ PASS'
                WHEN check_name = 'SFE Warehouse Exists' AND test_result::INT > 0 THEN '✓ PASS'
                WHEN check_name = 'Enhancement Procedure Exists' AND test_result::INT > 0 THEN '✓ PASS'
                WHEN check_name = 'Sample Data Access' AND test_result IS NOT NULL THEN '✓ PASS'
                ELSE '✗ FAIL'
            END as status,
            COALESCE(test_result, 'Error accessing resource') as message,
            CASE
                WHEN status = '✗ FAIL' THEN fix_command
                ELSE ''
            END as fix_command
        FROM checks
    );
    RETURN TABLE(result);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 5: Create Enhancement Procedure (Main Tool)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE PROCEDURE SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME STRING,
    P_BUSINESS_CONTEXT_PROMPT STRING,
    P_OUTPUT_VIEW_NAME STRING DEFAULT NULL,
    P_SCHEMA_NAME STRING DEFAULT CURRENT_SCHEMA(),
    P_DATABASE_NAME STRING DEFAULT CURRENT_DATABASE(),
    P_DRY_RUN BOOLEAN DEFAULT FALSE,
    P_MODEL STRING DEFAULT 'snowflake-llama-3.3-70b',
    P_MAX_COMMENT_LENGTH INTEGER DEFAULT 200,
    P_MAX_RETRIES INTEGER DEFAULT 3
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'enhance_view'
COMMENT = 'DEMO: semantic-view-enhancer - Creates enhanced copy of semantic view with AI-improved comments | Author: SE Community | Expires: 2026-01-15'
AS
$$
import re
import time

def enhance_view(session, p_source_view_name, p_business_context_prompt, p_output_view_name, p_schema_name, p_database_name, p_dry_run, p_model, p_max_comment_length, p_max_retries):
    """
    Creates an enhanced copy of a semantic view with AI-improved dimension/fact comments.

    Since ALTER SEMANTIC VIEW doesn't support modifying dimension/fact comments,
    this procedure:
    1. Gets the DDL of the source semantic view
    2. Enhances all dimension/fact comments using Cortex AI
    3. Recreates the view with a new name and enhanced comments
    """

    MAX_ERROR_MESSAGE_LENGTH = 150
    MAX_DDL_PREVIEW_LENGTH = 2000
    MAX_PROMPT_TOKENS = 8000
    PROGRESS_LOG_INTERVAL = 10
    RETRY_BACKOFF_SECONDS = 2

    def validate_identifier(name):
        if not name or not re.match(r'^[A-Za-z0-9_]{1,255}$', name):
            raise ValueError(f"Invalid identifier: {name}")
        reserved_words = ['SELECT', 'DROP', 'DELETE', 'INSERT', 'UPDATE', 'TRUNCATE']
        if name.upper() in reserved_words:
            raise ValueError(f"Reserved word not allowed: {name}")
        return True

    def estimate_tokens(text):
        return len(text) // 4

    def is_valid_enhancement(text):
        if not text or len(text) < 10:
            return False
        invalid_patterns = ["i cannot", "as an ai", "error:", "sorry", "i'm unable", "i can't"]
        text_lower = text.lower()
        if any(pattern in text_lower for pattern in invalid_patterns):
            return False
        if not any(c.isalnum() for c in text):
            return False
        return True

    def log_progress(session, message):
        try:
            escaped_msg = message.replace("'", "''")
            session.sql(f"SELECT SYSTEM$LOG('INFO', '{escaped_msg}')").collect()
        except:
            pass

    validate_identifier(p_source_view_name)
    validate_identifier(p_schema_name)
    validate_identifier(p_database_name)
    if p_output_view_name:
        validate_identifier(p_output_view_name)

    if p_max_comment_length < 50 or p_max_comment_length > 1000:
        return "Error: P_MAX_COMMENT_LENGTH must be between 50 and 1000"

    estimated_prompt_tokens = estimate_tokens(p_business_context_prompt)
    if estimated_prompt_tokens > MAX_PROMPT_TOKENS:
        excess_chars = (estimated_prompt_tokens - MAX_PROMPT_TOKENS) * 4
        return f"Error: Business context too long (~{estimated_prompt_tokens} tokens, limit {MAX_PROMPT_TOKENS}). Please shorten by ~{excess_chars} characters."

    # Determine output view name
    if not p_output_view_name:
        p_output_view_name = f"{p_source_view_name}_ENHANCED"

    # Construct fully qualified view names
    source_view_full = f"{p_schema_name}.{p_source_view_name}"
    output_view_full = f"{p_schema_name}.{p_output_view_name}"

    # Use DESCRIBE SEMANTIC VIEW to get complete structure
    try:
        describe_result = session.sql(f"DESCRIBE SEMANTIC VIEW {p_database_name}.{source_view_full}").collect()
    except Exception as e:
        return f"Error: Could not describe semantic view. Error: {str(e)}"

    # Get the DDL of the source semantic view using correct syntax
    try:
        ddl_result = session.sql(f"SELECT GET_DDL('SEMANTIC_VIEW', '{source_view_full}', TRUE)").collect()
        source_ddl = ddl_result[0][0]
    except Exception as e:
        return f"Error: Could not get DDL for {source_view_full}. Error: {str(e)}"

    # Parse DESCRIBE output to get source table mappings
    # TABLE rows have BASE_TABLE_DATABASE_NAME, BASE_TABLE_SCHEMA_NAME, BASE_TABLE_NAME
    table_info = {}
    for row in describe_result:
        if row['object_kind'] == 'TABLE':
            table_alias = row['object_name']
            if table_alias not in table_info:
                table_info[table_alias] = {}

            if row['property'] == 'BASE_TABLE_DATABASE_NAME':
                table_info[table_alias]['database'] = row['property_value']
            elif row['property'] == 'BASE_TABLE_SCHEMA_NAME':
                table_info[table_alias]['schema'] = row['property_value']
            elif row['property'] == 'BASE_TABLE_NAME':
                table_info[table_alias]['table'] = row['property_value']

    # Build fully qualified table names
    table_mappings = {}
    for alias, info in table_info.items():
        if 'database' in info and 'schema' in info and 'table' in info:
            table_mappings[alias] = f"{info['database']}.{info['schema']}.{info['table']}"

    # Extract unique dimensions and facts with their current comments
    dimensions = {}
    for row in describe_result:
        obj_kind = row['object_kind']
        obj_name = row['object_name']
        prop = row['property']
        prop_value = row['property_value']

        # We want DIMENSION and FACT objects only
        if obj_kind in ['DIMENSION', 'FACT'] and obj_name:
            if obj_name not in dimensions:
                dimensions[obj_name] = {
                    'kind': obj_kind,
                    'comment': '',
                    'data_type': '',
                    'expression': ''
                }

            # Capture properties
            if prop == 'COMMENT' and prop_value:
                dimensions[obj_name]['comment'] = prop_value
            elif prop == 'DATA_TYPE' and prop_value:
                dimensions[obj_name]['data_type'] = prop_value
            elif prop == 'EXPRESSION' and prop_value:
                dimensions[obj_name]['expression'] = prop_value

    if not dimensions:
        return f"No dimensions or facts found in {p_source_view_name}"

    # Generate enhanced comments for each dimension/fact
    enhanced_comments = {}
    enhanced_count = 0
    errors = []
    failed_dimensions = []

    total_dims = len(dimensions)
    log_progress(session, f"Starting enhancement of {total_dims} dimensions/facts using model {p_model}")

    dim_index = 0
    for dim_name, dim_info in dimensions.items():
        dim_index += 1

        if dim_index % PROGRESS_LOG_INTERVAL == 0:
            log_progress(session, f"Enhanced {dim_index}/{total_dims} dimensions ({int(dim_index/total_dims*100)}%)")

        enhanced_desc = None
        last_error = None

        for attempt in range(p_max_retries):
            try:
                current_desc_text = f"CURRENT DESCRIPTION: {dim_info['comment']}" if dim_info['comment'] else "CURRENT DESCRIPTION: None"
                data_type_text = f"DATA TYPE: {dim_info['data_type']}" if dim_info['data_type'] else ""

                prompt = f"""You are enhancing a Snowflake semantic view {dim_info['kind'].lower()} description for Cortex Analyst.

{dim_info['kind']}: {dim_name}
{data_type_text}
{current_desc_text}

ADDITIONAL BUSINESS CONTEXT:
{p_business_context_prompt}

Task: Create a concise, enhanced description (max {p_max_comment_length} characters) that:
1. Incorporates relevant parts of the additional business context
2. Preserves useful information from the current description if any
3. Is optimized for AI query understanding
4. Focuses on business meaning

Output ONLY the enhanced description text, no formatting or quotes."""

                prompt_escaped = prompt.replace("'", "''")

                cortex_sql = f"SELECT AI_COMPLETE('{p_model}', '{prompt_escaped}')"
                cortex_result = session.sql(cortex_sql).collect()
                enhanced_desc = cortex_result[0][0].strip()

                if enhanced_desc.startswith('"') and enhanced_desc.endswith('"'):
                    enhanced_desc = enhanced_desc[1:-1]
                if enhanced_desc.startswith("'") and enhanced_desc.endswith("'"):
                    enhanced_desc = enhanced_desc[1:-1]

                enhanced_desc = ' '.join(enhanced_desc.split())

                if len(enhanced_desc) > p_max_comment_length:
                    enhanced_desc = enhanced_desc[:p_max_comment_length-3] + '...'

                if not is_valid_enhancement(enhanced_desc):
                    raise ValueError(f"AI returned invalid response: {enhanced_desc[:50]}")

                enhanced_comments[dim_name] = enhanced_desc
                enhanced_count += 1
                break

            except Exception as e:
                last_error = str(e)
                if attempt < p_max_retries - 1:
                    time.sleep(RETRY_BACKOFF_SECONDS * (attempt + 1))
                    continue
                else:
                    errors.append(f"{dim_name}: {last_error[:MAX_ERROR_MESSAGE_LENGTH]}")
                    failed_dimensions.append(dim_name)
                    enhanced_comments[dim_name] = dim_info['comment']

    log_progress(session, f"Enhancement complete: {enhanced_count} successful, {len(failed_dimensions)} failed")

    if p_dry_run:
        result_rows = []
        for dim_name, dim_info in dimensions.items():
            result_rows.append({
                'DIMENSION_NAME': dim_name,
                'OBJECT_KIND': dim_info['kind'],
                'ORIGINAL_COMMENT': dim_info['comment'],
                'ENHANCED_COMMENT': enhanced_comments.get(dim_name, ''),
                'STATUS': 'FAILED' if dim_name in failed_dimensions else 'ENHANCED'
            })

        return session.create_dataframe(result_rows).to_pandas().to_string()

    # Update the DDL with enhanced comments and change the view name
    new_ddl = source_ddl

    # Replace the view name in the DDL
    # The DDL contains the fully qualified name: DATABASE.SCHEMA.VIEW
    # We need to replace the entire qualified name
    source_fqn = f"{p_database_name}.{source_view_full}"
    output_fqn = f"{p_database_name}.{output_view_full}"

    # Pattern: create or replace semantic view DATABASE.SCHEMA.VIEWNAME
    new_ddl = re.sub(
        rf'(create\s+or\s+replace\s+semantic\s+view\s+){re.escape(source_fqn)}',
        rf'\1{output_fqn}',
        new_ddl,
        flags=re.IGNORECASE
    )

    # Fix table references - GET_DDL may not fully qualify them in TABLES clause
    # If no mappings found, return error with DDL for debugging
    if not table_mappings:
        return f"Error: No table mappings found. Cannot determine source tables. DDL: {source_ddl[:1000]}"

    # The DDL can have different formats:
    # 1. TABLEALIAS as UNQUALIFIED_TABLE primary key ...
    # 2. TABLEALIAS primary key ... (no AS clause)
    # We need to handle both cases
    for table_alias, source_table in table_mappings.items():
        # Case 1: TABLEALIAS as SOMETABLE (where SOMETABLE is not fully qualified)
        # Replace with: TABLEALIAS as FULL.QUALIFIED.NAME
        pattern1 = rf'\b{re.escape(table_alias)}\s+as\s+(\w+)(?!\.)'
        replacement1 = rf'{table_alias} as {source_table}'
        new_ddl = re.sub(pattern1, replacement1, new_ddl, flags=re.IGNORECASE)

        # Case 2: TABLEALIAS primary key (no AS clause at all)
        # Replace with: TABLEALIAS as FULL.QUALIFIED.NAME primary key
        pattern2 = rf'\b{re.escape(table_alias)}\s+(primary\s+key|comment|unique)'
        replacement2 = rf'{table_alias} as {source_table} \1'
        new_ddl = re.sub(pattern2, replacement2, new_ddl, flags=re.IGNORECASE)

    # Replace each comment in the DDL
    for dim_name, enhanced_comment in enhanced_comments.items():
        # Escape single quotes for SQL
        safe_comment = enhanced_comment.replace("'", "''")

        # Pattern: dimension_name AS column_name COMMENT = 'old comment'
        # This pattern handles: tablealias.dimension_name AS alias_name COMMENT = 'text'
        pattern = rf"(\w+\.{re.escape(dim_name)}\s+AS\s+\w+\s+COMMENT\s*=\s*)'[^']*'"
        replacement = rf"\1'{safe_comment}'"
        new_ddl = re.sub(pattern, replacement, new_ddl, flags=re.IGNORECASE)

    # Execute the new DDL to create the enhanced semantic view
    try:
        session.sql(new_ddl).collect()
        result_msg = f"Successfully created {p_output_view_name} with {enhanced_count}/{total_dims} enhanced dimension/fact comments"
        if failed_dimensions:
            result_msg += f". Failed: {len(failed_dimensions)} dimensions ({', '.join(failed_dimensions[:5])}"
            if len(failed_dimensions) > 5:
                result_msg += f" and {len(failed_dimensions)-5} more"
            result_msg += ")"
    except Exception as create_error:
        error_details = f"Error creating view: {str(create_error)}"
        ddl_preview = new_ddl[:MAX_DDL_PREVIEW_LENGTH] if len(new_ddl) > MAX_DDL_PREVIEW_LENGTH else new_ddl
        return f"{error_details}\n\nGenerated DDL:\n{ddl_preview}"

    return result_msg
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 6: Verify Installation
-- ═══════════════════════════════════════════════════════════════════════════

SHOW PROCEDURES LIKE 'SFE_ENHANCE_SEMANTIC_VIEW'
  IN SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS;

SHOW WAREHOUSES LIKE 'SFE_ENHANCEMENT_WH';

-- ═══════════════════════════════════════════════════════════════════════════
-- ✅ DEPLOYMENT COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ DEPLOYMENT COMPLETE' AS STATUS,
       'Semantic view enhancement tool is ready to use' AS MESSAGE,
       'SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS.SFE_ENHANCE_SEMANTIC_VIEW' AS PROCEDURE_NAME,
       'See README.md for usage examples' AS NEXT_STEPS;

/*******************************************************************************
 * USAGE EXAMPLE:
 ******************************************************************************/

-- USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS;
-- USE WAREHOUSE SFE_ENHANCEMENT_WH;
--
-- CALL SFE_ENHANCE_SEMANTIC_VIEW(
--     P_SOURCE_VIEW_NAME => 'YOUR_SEMANTIC_VIEW',
--     P_BUSINESS_CONTEXT_PROMPT => 'Your comprehensive business context here...'
-- );

/*******************************************************************************
 * ESTIMATED COSTS:
 ******************************************************************************/
-- Edition: Standard ($2/credit) or higher
-- One-time Setup: < $0.01 (warehouse barely used)
-- Per Enhancement: ~$0.005-0.05 per semantic view (75% cost reduction with snowflake-llama-3.3-70b)
-- Monthly Idle: $0 (warehouse auto-suspends)
--
-- Cost Breakdown (snowflake-llama-3.3-70b model):
--   10 dimensions:  ~$0.005
--   50 dimensions:  ~$0.025
--   100 dimensions: ~$0.05
