-- =============================================================================
-- 04_git_driven_import.sql — The Git-driven lifecycle (GitHub as source of truth)
-- Pair-programmed by SE Community + Cortex Code
--
-- In this model the agent spec lives in GitHub. You review and merge changes
-- through pull requests, then Snowflake pulls the merged file and creates a
-- new immutable version DIRECTLY from the repo — bypassing LIVE entirely.
--
-- Snowflake connects to Git natively: an API integration + a GIT REPOSITORY
-- object clone the repo into a read-only stage you can reference with @repo/...
--
-- Requires ACCOUNTADMIN (or CREATE INTEGRATION) for the integration steps.
-- Every value in <ANGLE_BRACKETS> is yours to replace.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- --- Option A: authenticate with the Snowflake GitHub App (recommended) ------
-- No secret to manage. After running, authorize the app in Snowsight when
-- prompted (Data > Git repositories), or via the returned consent flow.
CREATE OR REPLACE API INTEGRATION git_agent_api
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/<YOUR_ORG_OR_USER>')
  API_USER_AUTHENTICATION = ( TYPE = SNOWFLAKE_GITHUB_APP )
  ENABLED = TRUE
  COMMENT = 'GitHub connection for agent-spec deployment';

-- --- Option B: authenticate with a personal access token (PAT) ---------------
-- Use this for private repos when the GitHub App is not an option. The secret
-- holds the PAT; it must be listed in ALLOWED_AUTHENTICATION_SECRETS.
--
-- CREATE OR REPLACE SECRET github_pat
--   TYPE = PASSWORD
--   USERNAME = '<YOUR_GITHUB_USERNAME>'
--   PASSWORD = '<YOUR_GITHUB_PAT>';   -- never commit this value
--
-- CREATE OR REPLACE API INTEGRATION git_agent_api
--   API_PROVIDER = git_https_api
--   API_ALLOWED_PREFIXES = ('https://github.com/<YOUR_ORG_OR_USER>')
--   ALLOWED_AUTHENTICATION_SECRETS = (github_pat)
--   ENABLED = TRUE;

-- --- Clone the repo into Snowflake as a read-only stage ----------------------
CREATE OR REPLACE GIT REPOSITORY agent_repo
  API_INTEGRATION = git_agent_api
  ORIGIN = 'https://github.com/<YOUR_ORG_OR_USER>/<YOUR_REPO>.git'
  -- GIT_CREDENTIALS = github_pat   -- uncomment for Option B (PAT)
  COMMENT = 'Clone of the repo holding agent specs';

-- Pull the latest commits (run this whenever main/tags change).
ALTER GIT REPOSITORY agent_repo FETCH;

-- Browse what Snowflake sees.
SHOW GIT BRANCHES IN agent_repo;
LIST @agent_repo/branches/main/;

-- --- Import a committed version straight from the repo -----------------------
-- The stage path must contain an agent_spec.yaml. Point at a branch for
-- continuous deployment, or a tag for release-pinned deployment.
--
-- Assumes the repo layout:  specs/agent_spec.yaml  (adjust the path as needed).

-- From the main branch (continuous):
ALTER AGENT ORDERS_AGENT ADD VERSION FROM @agent_repo/branches/main/specs
  COMMENT = 'Imported from main @ latest';

-- Or from a release tag (pinned — recommended for production):
-- ALTER AGENT ORDERS_AGENT ADD VERSION FROM @agent_repo/tags/v2.1/specs
--   COMMENT = 'Automated deploy from CI pipeline, tag v2.1';

-- Promote the freshly imported version. Grab its VERSION$N from SHOW VERSIONS,
-- then alias + default it (see 05_promote_rollback.sql for the full flow).
SHOW VERSIONS IN AGENT ORDERS_AGENT;

-- --- Bootstrap a brand-new agent from the repo (infrastructure-as-code) ------
-- Handy in a fresh environment: create the agent directly from the staged spec.
-- CREATE AGENT ORDERS_AGENT_FROM_GIT
--   COMMENT = 'Deployed by CI pipeline'
--   FROM @agent_repo/branches/main/specs;
