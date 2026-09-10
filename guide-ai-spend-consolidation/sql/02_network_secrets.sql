/* Cross-platform AI spend consolidation — network rules and credentials
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Creates network rules for each vendor host and one external access integration.
   SECRET creation is left COMMENTED on purpose -- running this file must never be
   the thing that puts a credential into a shell history, a worksheet history, or a
   git diff. Copy the template you need, fill it in interactively, and run that one
   statement by itself.

   Only add hosts for platforms you are actually ingesting. An external access
   integration is an egress allowlist, and an unused entry is an unnecessary hole.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Network rules, one per vendor
--
-- Kept separate rather than merged into one rule so a platform can be revoked by
-- detaching a single rule, and so the allowlist reads as documentation of exactly
-- which vendors this pipeline talks to.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE NETWORK RULE AI_SPEND.CONTROL.GITHUB_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.github.com:443')
  COMMENT = 'GitHub Copilot usage metrics and user-management APIs';

CREATE OR REPLACE NETWORK RULE AI_SPEND.CONTROL.OPENAI_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.openai.com:443')
  COMMENT = 'OpenAI admin, analytics, and cost endpoints';

CREATE OR REPLACE NETWORK RULE AI_SPEND.CONTROL.MICROSOFT_GRAPH_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- login.microsoftonline.com is required for the OAuth token exchange, separately
  -- from the Graph host itself. Omitting it produces an authentication failure that
  -- looks like a credential problem and is not one.
  VALUE_LIST = ('graph.microsoft.com:443', 'login.microsoftonline.com:443')
  COMMENT = 'Microsoft Graph Copilot usage reports plus Entra token endpoint';

CREATE OR REPLACE NETWORK RULE AI_SPEND.CONTROL.BOX_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- api.box.com serves the enterprise events and reporting endpoints;
  -- upload.box.com is needed only if you also fetch report files Box has
  -- delivered into a Box folder rather than reading events directly.
  VALUE_LIST = ('api.box.com:443', 'upload.box.com:443')
  COMMENT = 'Box enterprise events, AI reporting, and report file retrieval';

-- ---------------------------------------------------------------------------
-- External access integration
--
-- ALLOWED_AUTHENTICATION_SECRETS must name every secret any handler will use. It
-- is static DDL -- adding a platform means re-running this ALTER, which is the same
-- structural reason the SECRETS clause on each procedure cannot be data-driven.
--
-- Start with only the platforms you have credentials for. ENABLED = TRUE with an
-- empty secret list is valid and useful while you are still testing connectivity.
-- ---------------------------------------------------------------------------

CREATE EXTERNAL ACCESS INTEGRATION AI_SPEND_EAI
  ALLOWED_NETWORK_RULES = (
    AI_SPEND.CONTROL.GITHUB_API_RULE,
    AI_SPEND.CONTROL.OPENAI_API_RULE,
    AI_SPEND.CONTROL.MICROSOFT_GRAPH_RULE,
    AI_SPEND.CONTROL.BOX_API_RULE
  )
  ALLOWED_AUTHENTICATION_SECRETS = (
    AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS
  )
  ENABLED = TRUE
  COMMENT = 'Egress for AI platform admin API pulls';

GRANT USAGE ON INTEGRATION AI_SPEND_EAI TO ROLE AI_SPEND_RL;

/* ===========================================================================
   CREDENTIAL TEMPLATES -- run these interactively, one at a time.

   Do not uncomment these and run the file. Do not paste real values into a file
   that git can see. Fill in the placeholder, run the single statement, and let it
   scroll out of your history.

   Every secret below needs GRANT READ ... TO ROLE AI_SPEND_RL, or the procedure
   fails at execution with a message that reads like a network problem.
   =========================================================================== */

/* ---------------------------------------------------------------------------
   GitHub Copilot -- the one worked adapter in sql/03

   Needs a token with organization or enterprise scope carrying BOTH:
     - permission to read Copilot usage metrics
     - permission to read Copilot seat assignments (a separate API)

   A fine-grained PAT or a GitHub App installation token both work. A GitHub App
   is the better long-term choice: it is not tied to a leaving employee, which is
   the failure mode that silently kills these pipelines six months in.

   TYPE = GENERIC_STRING because a token is one value, not a username/password pair.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_GITHUB_TOKEN>'  -- pragma: allowlist secret
--   COMMENT = 'GitHub Copilot usage metrics + seat assignment read token';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS TO ROLE AI_SPEND_RL;

/* ---------------------------------------------------------------------------
   OpenAI -- ChatGPT Enterprise and the API Platform

   These are SEPARATE products with separate billing. Their admin credentials are
   also separate, and the identifiers they scope to are different: a ChatGPT
   workspace ID versus an API Platform organization ID.

   Register them as two platforms (sql/01 already does) and consider two secrets
   even if one token happens to reach both. Two secrets makes it structurally
   harder to produce a blended "OpenAI spend" figure that reconciles to no invoice.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_OPENAI_ADMIN_KEY>'  -- pragma: allowlist secret
--   COMMENT = 'OpenAI admin key for analytics and cost endpoints';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS TO ROLE AI_SPEND_RL;

/* ---------------------------------------------------------------------------
   Microsoft Graph -- M365 Copilot

   Client credentials flow: an Entra app registration with an application
   permission to read usage reports, admin-consented. TYPE = PASSWORD maps
   naturally: client ID to username, client secret to password.

   BEFORE creating this, confirm the tenant's report-concealment setting. If
   concealment is ON -- the default -- the usage report returns hashed user
   principal names and you CANNOT join Copilot usage to a department. Ingesting
   first and discovering that later wastes the credential request and produces a
   dashboard nobody can use. See gotcha 2 in the README.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.GRAPH_API_CREDENTIALS
--   TYPE = PASSWORD
--   USERNAME = '<YOUR_ENTRA_APP_CLIENT_ID>'
--   PASSWORD = '<YOUR_ENTRA_APP_CLIENT_SECRET>'  -- pragma: allowlist secret
--   COMMENT = 'Entra app registration for Graph Copilot usage reports';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.GRAPH_API_CREDENTIALS TO ROLE AI_SPEND_RL;

/* ---------------------------------------------------------------------------
   Box AI

   Box AI is METERED in AI Units (since 2025-10-20), so this platform does carry
   per-user cost -- it is not a bundled seat.

   Auth: a Box Platform App using Client Credentials Grant, authorized by an
   enterprise admin. The service account must hold the "Run new reports and access
   existing reports" permission, or the Enterprise Events endpoints return
   authorization errors that read like a bad token.

   TYPE = PASSWORD maps the OAuth pair naturally: Client ID to username, Client
   Secret to password. The adapter exchanges them for a bearer token per run.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.BOX_API_CREDENTIALS
--   TYPE = PASSWORD
--   USERNAME = '<YOUR_BOX_CLIENT_ID>'
--   PASSWORD = '<YOUR_BOX_CLIENT_SECRET>'  -- pragma: allowlist secret
--   COMMENT = 'Box Platform App (client credentials) for enterprise events and AI reports';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.BOX_API_CREDENTIALS TO ROLE AI_SPEND_RL;

-- ---------------------------------------------------------------------------
-- Verify: which secrets exist and which the integration will actually permit
--
-- A secret that exists but is absent from ALLOWED_AUTHENTICATION_SECRETS produces
-- a runtime failure, not a creation-time one. Check both sides here rather than
-- discovering the mismatch inside a Python traceback.
-- ---------------------------------------------------------------------------

SHOW SECRETS IN SCHEMA AI_SPEND.CONTROL;

DESCRIBE INTEGRATION AI_SPEND_EAI;
