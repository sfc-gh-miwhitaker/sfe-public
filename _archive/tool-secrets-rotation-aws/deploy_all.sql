/*==============================================================================
DEPLOY ALL - Secrets Rotation Workbook
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-05
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

-- 1. Expiration check (informational -- warns but does not block)
SELECT
    '2026-04-05'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-04-05'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-05'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-05'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-05'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-05'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent -- safe to re-run)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';
USE WAREHOUSE SFE_TOOLS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- 3. Fetch latest from Git
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- 4. Create schema
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SECRETS_ROTATION
  COMMENT = 'TOOL: Secrets rotation workbook for service accounts (Expires: 2026-04-05)';

-- 5. Import notebook from Git stage
CREATE OR REPLACE NOTEBOOK SNOWFLAKE_EXAMPLE.SECRETS_ROTATION.SECRETS_ROTATION_WORKBOOK
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-secrets-rotation-aws/'
  MAIN_FILE = 'secrets_rotation_workbook.ipynb'
  QUERY_WAREHOUSE = SFE_TOOLS_WH
  COMMENT = 'TOOL: Key-pair and PAT rotation workbook (Expires: 2026-04-05)';

-- 6. Add live version so the notebook is runnable
ALTER NOTEBOOK SNOWFLAKE_EXAMPLE.SECRETS_ROTATION.SECRETS_ROTATION_WORKBOOK
  ADD LIVE VERSION FROM LAST;

-- 7. Final summary
SELECT 'Deployment complete!' AS status,
       'Open: Snowsight > Projects > Notebooks > SECRETS_ROTATION_WORKBOOK' AS next_step,
       CURRENT_TIMESTAMP() AS completed_at;
