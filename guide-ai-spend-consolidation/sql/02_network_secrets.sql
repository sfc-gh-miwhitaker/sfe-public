/* Cross-platform AI spend consolidation — network rules and credentials
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-11-09

   Creates network rules for each vendor host and one external access integration.
   SECRET creation is left COMMENTED on purpose -- running this file must never be
   the thing that puts a credential into a shell history, a worksheet history, or a
   git diff. Use an approved secret-provisioning workflow; running SQL containing
   a literal credential interactively does not guarantee it is absent from history.

   Only add hosts for platforms you are actually ingesting. An external access
   integration is an egress allowlist, and an unused entry is an unnecessary hole.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Network rules, one per vendor. IF NOT EXISTS preserves approved custom hosts
-- on rerun; review existing rules and use an explicit ALTER for policy changes.
--
-- Kept separate rather than merged into one rule so a platform can be revoked by
-- detaching a single rule, and so the allowlist reads as documentation of exactly
-- which vendors this pipeline talks to.
-- ---------------------------------------------------------------------------

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.GITHUB_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.github.com:443')
  COMMENT = 'GitHub Copilot usage metrics and user-management APIs';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.OPENAI_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.openai.com:443')
  COMMENT = 'OpenAI admin, analytics, and cost endpoints';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.MICROSOFT_GRAPH_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- login.microsoftonline.com is required for the OAuth token exchange, separately
  -- from the Graph host itself. Omitting it produces an authentication failure that
  -- looks like a credential problem and is not one.
  VALUE_LIST = ('graph.microsoft.com:443', 'login.microsoftonline.com:443')
  COMMENT = 'Microsoft Graph Copilot usage reports plus Entra token endpoint';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.BOX_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- api.box.com serves the enterprise events and reporting endpoints;
  -- File downloads redirect to a separate download host (for example
  -- dl.boxcloud.com). Approve the exact current host before adding it; reject
  -- unapproved redirects and never forward the API bearer token to downloads.
  VALUE_LIST = ('api.box.com:443')
  COMMENT = 'Box enterprise events, AI reporting, and report file retrieval';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.ANTHROPIC_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- One host serves three separate API families with three non-interchangeable key
  -- types: the Admin API, the Claude Enterprise Analytics API, and the Compliance
  -- API. A single network rule is correct here; the separation is in the credentials.
  VALUE_LIST = ('api.anthropic.com:443')
  COMMENT = 'Anthropic Admin API and Claude Enterprise Analytics API';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.CURSOR_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.cursor.com:443')
  COMMENT = 'Cursor Admin API: members, daily usage, spend, usage events';

CREATE NETWORK RULE IF NOT EXISTS AI_SPEND.CONTROL.GOOGLE_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  -- Four hosts because the three Google surfaces do not share one API:
  --   oauth2.googleapis.com   service-account token exchange, needed by all of them
  --   admin.googleapis.com    Workspace Admin SDK Reports (Gemini audit activities)
  --   logging.googleapis.com  Gemini Code Assist per-user entries (labels.user_id)
  --   bigquery.googleapis.com Workspace BigQuery export and Cloud Billing export,
  --                           which is where the bulk paths actually live
  -- Omitting oauth2.googleapis.com produces an authentication failure that looks
  -- like a bad service-account key and is not one.
  VALUE_LIST = (
    'oauth2.googleapis.com:443',
    'admin.googleapis.com:443',
    'logging.googleapis.com:443',
    'bigquery.googleapis.com:443'
  )
  COMMENT = 'Google Workspace Reports, Cloud Logging, and BigQuery export reads';

-- ---------------------------------------------------------------------------
-- External access integration
--
-- ALLOWED_AUTHENTICATION_SECRETS must name every secret any handler will use. It
-- is static DDL -- adding a platform means re-running this ALTER, which is the same
-- structural reason the SECRETS clause on each procedure cannot be data-driven.
--
-- Start disabled, with only GitHub's API host and no usable secrets. Approve
-- exact download hosts and provision credentials before explicitly enabling it.
-- ---------------------------------------------------------------------------

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS AI_SPEND_EAI
  ALLOWED_NETWORK_RULES = (
    AI_SPEND.CONTROL.GITHUB_API_RULE
  )
  ALLOWED_AUTHENTICATION_SECRETS = (none)
  ENABLED = FALSE
  COMMENT = 'Egress for AI platform admin API pulls';

GRANT USAGE ON INTEGRATION AI_SPEND_EAI TO ROLE AI_SPEND_RL;

/* ===========================================================================
   CREDENTIAL TEMPLATES -- run these interactively, one at a time.

   Do not uncomment these and run the file. Do not paste real values into a file
   that git can see. Use your approved secret-provisioning workflow. Scrolling a
   value out of view does not remove it from worksheet or shell history.

   The procedure creator needs READ on each bound secret, USAGE on its schema,
   and USAGE on the EAI. Missing grants or a secret absent from the integration
   can fail CREATE PROCEDURE; verify these before creation, not just at runtime.
   https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access
   =========================================================================== */

/* ---------------------------------------------------------------------------
   GitHub Copilot -- the one worked adapter in sql/03

   Uses organization endpoints. A fine-grained token needs BOTH:
     - Organization Copilot metrics (read) for users-1-day
     - GitHub Copilot Business (read) or Administration (read) for seats
   Classic PAT/OAuth support is documented with read:org for both endpoints.
   Verify the principal's organization access and the enabled metrics policy.
   Seat-management endpoints are public preview and subject to change.
   https://docs.github.com/en/rest/copilot/copilot-usage-metrics
   https://docs.github.com/en/rest/copilot/copilot-user-management

   Verify token support and permissions for EACH endpoint and scope. The worked
   connector uses a single organization; enterprise metrics and enterprise seat
   inventory are not interchangeable with the organization APIs.

   TYPE = GENERIC_STRING because a token is one value, not a username/password pair.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_GITHUB_TOKEN>'  -- pragma: allowlist secret
--   COMMENT = 'GitHub Copilot usage metrics + seat assignment read token';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS TO ROLE AI_SPEND_RL;
-- After creating the secret, qualify report download URLs and configure the same
-- exact hosts in DOWNLOAD_HOSTS in sql/03. Never paste a signed URL into DDL.
-- CREATE NETWORK RULE AI_SPEND.CONTROL.GITHUB_REPORT_DOWNLOAD_RULE
--   MODE = EGRESS TYPE = HOST_PORT VALUE_LIST = ('<approved-download-host>:443');
-- ALTER EXTERNAL ACCESS INTEGRATION AI_SPEND_EAI SET
--   ALLOWED_NETWORK_RULES = (AI_SPEND.CONTROL.GITHUB_API_RULE,
--                           AI_SPEND.CONTROL.GITHUB_REPORT_DOWNLOAD_RULE)
--   ALLOWED_AUTHENTICATION_SECRETS = (AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS)
--   ENABLED = TRUE;
-- IF NOT EXISTS above preserves existing integration settings; explicitly review
-- and ALTER an older integration that still permits unnecessary vendor hosts.

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

/* ---------------------------------------------------------------------------
   Anthropic -- TWO credentials, and they are not interchangeable

   This is the same product-separation trap as OpenAI, but with a sharper edge:
   Anthropic ships three API families and an Admin API key CANNOT call the Claude
   Enterprise Analytics API, nor can an Analytics key call the Admin API. Both are
   documented under one "Admin API" heading, which is how people lose an afternoon.

   (a) ANTHROPIC_ANALYTICS_CREDENTIALS -- Claude Enterprise (the seats)
       Scope read:analytics. Created in claude.ai -> Organization settings -> API
       by the PRIMARY OWNER ONLY. No other role can mint it, so budget for that
       conversation early -- it is usually a person, not a team.
       This is the ONLY surface with per-user cost.

   (b) ANTHROPIC_ADMIN_CREDENTIALS -- Claude Console (the metered API platform)
       An sk-ant-admin key, created by an org admin in the Console. Sent as
       x-api-key, not as a bearer token. A WORKSPACE-SCOPED key will not work --
       the key must be org-scoped or the request fails on privilege, not on syntax.

   These are separate billing scopes. Enterprise parent organizations do not have
   Console Admin API keys. Reconcile Enterprise per-user amounts to Enterprise
   organization totals; ingest Console only for a separately identified API scope.

   Every request on both families needs an anthropic-version header. It is now
   documented as required on surfaces that previously tolerated its absence, which
   is a live break for older sample code.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.ANTHROPIC_ANALYTICS_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_CLAUDE_ANALYTICS_KEY>'  -- pragma: allowlist secret
--   COMMENT = 'Claude Enterprise Analytics API key, scope read:analytics';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.ANTHROPIC_ANALYTICS_CREDENTIALS TO ROLE AI_SPEND_RL;

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.ANTHROPIC_ADMIN_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_ANTHROPIC_ADMIN_KEY>'  -- pragma: allowlist secret
--   COMMENT = 'Anthropic Admin API key (org-scoped) for Console usage and cost';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.ANTHROPIC_ADMIN_CREDENTIALS TO ROLE AI_SPEND_RL;

/* ---------------------------------------------------------------------------
   Cursor

   A team administrator creates the key in the Cursor dashboard. It is shown once.

   TYPE = GENERIC_STRING rather than PASSWORD, even though the wire format is HTTP
   Basic. Cursor sends the API KEY AS THE USERNAME WITH AN EMPTY PASSWORD, which is
   not what a PASSWORD secret models -- storing it as a username/password pair
   invites someone to "fix" the empty half. Keep the key as one value and let the
   adapter build the Basic header.

   Two scoping traps worth knowing before you request the key:
     - Team keys and Organization keys are DIFFERENT credential types. The team
       endpoints need a Team key; the organization endpoints need an Organization
       key. They are not interchangeable.
     - Keys are org-scoped and visible to all admins, and they survive the creator
       leaving -- which is the failure mode that silently kills these pipelines.
       Unusually, that is the good outcome here.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.CURSOR_ADMIN_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_CURSOR_ADMIN_KEY>'  -- pragma: allowlist secret
--   COMMENT = 'Cursor Admin API key, sent as HTTP Basic username with empty password';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.CURSOR_ADMIN_CREDENTIALS TO ROLE AI_SPEND_RL;

/* ---------------------------------------------------------------------------
   Google -- one service account, three very different surfaces

   A single service-account JSON key covers all three Google platforms, but each
   needs its own authorization step and they are granted in different consoles:

     Workspace Gemini   Domain-wide delegation, authorized by a Workspace super
                        admin, with admin.reports.audit.readonly. The adapter must
                        impersonate an admin user -- a service account acting as
                        itself gets a 403 that reads like a missing API enablement.
     Code Assist        Cloud Logging read on the project(s) collecting Code Assist
                        entries. Logging must be ENABLED first; it is off by
                        default and there is no backfill.
     Vertex / billing   BigQuery read on the Cloud Billing detailed export dataset.

   BEFORE creating this, settle what Google can actually give you. Google offers
   user-level USAGE nearly everywhere and user-level COST almost nowhere: baseline
   Workspace Gemini has no separable cost at all, and Vertex cost cannot be
   attributed to a person. See gotcha 11 in the README before promising anything.

   TYPE = GENERIC_STRING holding the whole JSON key. It is one credential, and
   splitting it across fields loses the parts the token exchange needs.
   --------------------------------------------------------------------------- */

-- CREATE OR REPLACE SECRET AI_SPEND.CONTROL.GOOGLE_SA_CREDENTIALS
--   TYPE = GENERIC_STRING
--   SECRET_STRING = '<YOUR_SERVICE_ACCOUNT_JSON>'  -- pragma: allowlist secret
--   COMMENT = 'Google service account JSON: Workspace Reports, Cloud Logging, BigQuery';
-- GRANT READ ON SECRET AI_SPEND.CONTROL.GOOGLE_SA_CREDENTIALS TO ROLE AI_SPEND_RL;

-- ---------------------------------------------------------------------------
-- Verify: which secrets exist and which the integration will actually permit
--
-- Check secret bindings, creator privileges and ALLOWED_AUTHENTICATION_SECRETS
-- before CREATE PROCEDURE. Host allowlisting is a separate runtime requirement;
-- this inventory does not prove connectivity or expose credential values.
-- ---------------------------------------------------------------------------

SHOW SECRETS IN SCHEMA AI_SPEND.CONTROL;

DESCRIBE INTEGRATION AI_SPEND_EAI;
