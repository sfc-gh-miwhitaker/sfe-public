/*==============================================================================
META ADS MCP SERVER — SNOWFLAKE REGISTRATION REFERENCE
Pair-programmed by SE Community + Cortex Code | Expires: 2026-11-28

WHAT THIS IS
  A reference for registering Meta's Ads MCP Server as a tool source for a
  Cortex Agent (Path A), plus the Cortex Code client configuration (Path B).

READ THIS FIRST — PROVENANCE
  The SNOWFLAKE half of this file is EXECUTED AND VERIFIED against a live account
  (v10.30.102) on 2026-08-28, then torn down. Confirmed working:
    - CREATE API INTEGRATION with API_PROVIDER = external_mcp and
      TYPE = OAUTH_DYNAMIC_CLIENT (Section 2)
    - CREATE EXTERNAL MCP SERVER against the Meta URL (Section 3)
    - SYSTEM$START_USER_OAUTH_FLOW, which returned a valid Snowflake-hosted
      consent URL (Section 6)
    - the teardown order in Section 8

  WHAT THAT DOES AND DOES NOT PROVE. Object creation is metadata only — Snowflake
  does not contact Meta at CREATE time, and START_USER_OAUTH_FLOW only hands off
  to a browser. So the Snowflake plumbing is proven; the Meta handshake is not.
  Dynamic Client Registration happens when a human opens that consent URL, and
  that step remains UNTESTED.

  The META half is NOT verified. Meta's developer docs are JavaScript-rendered
  and could not be read programmatically. Specifically UNVERIFIED:
    - whether https://mcp.facebook.com/ads returns a live MCP endpoint. DNS DOES
      resolve it to a genuine Facebook host (star.c10r.facebook.com), so the
      hostname is real and not invented — but an HTTPS probe was blocked by
      corporate VPN egress, so no status code was obtained.
    - the OAuth scope names
    - whether Meta permits Snowflake's server-side callback URL at all

  No working Meta<->Snowflake MCP integration has been published anywhere. Treat
  a failure at the consent step as expected and diagnosable, not as a defect in
  this reference.

  Confirm the endpoint in a browser BEFORE running Section 2:
    developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/
      ads-mcp-server/ads-mcp-server-get-started

RECOMMENDED ORDER
  Do PATH B FIRST (Section 1). It needs no ACCOUNTADMIN, costs nothing, and its
  browser-based DCR flow is the one Meta designed for. Only attempt Path A once
  you have confirmed the endpoint and OAuth behavior interactively — otherwise a
  failure could be Meta's callback policy, Snowflake's DCR handshake, or a wrong
  URL, with nothing to distinguish them.

PREREQUISITES
  Path A: CREATE INTEGRATION (ACCOUNTADMIN by default), an existing Cortex Agent.
  Path B: Cortex Code installed.
  Both:   admin role on the target Meta ad account in Business Manager.

  Path A also needs a schema to hold the MCP server object and a role to grant it
  to. Section 3 creates MARKETING.ACTIVATION if the Google reference file has not
  already; replace MARKETING_AGENT_ROLE in Section 4 with your agent's role.
==============================================================================*/


/*==============================================================================
SECTION 1 — PATH B: CORTEX CODE (do this first)

  Not SQL. Shown here so both paths live in one place.

  Register the server:

    cortex mcp add meta-ads https://mcp.facebook.com/ads --type http

  Or in ~/.snowflake/cortex/mcp.json:

    {
      "mcpServers": {
        "meta-ads": {
          "type": "http",
          "url": "https://mcp.facebook.com/ads",
          "oauth": {
            "client_name": "Cortex Code",
            "redirect_port": 8585
          }
        }
      }
    }

  OMITTING client_id IS DELIBERATE. Cortex Code then attempts Dynamic Client
  Registration and opens the system browser — behaviorally identical to how
  Claude Desktop and Cursor connect, which is the flow Meta built for. Adding a
  client_id you have no documented way to obtain will make this fail.

  Tokens land in the OS keychain and auto-refresh. Tools namespace as
  mcp__meta-ads__<tool>.

  ---------------------------------------------------------------------------
  GUARDRAIL — apply this before granting ads_management to anything.

  With write scope, an agent can change live spend. Start read-only via
  ~/.snowflake/cortex/permissions.json:

    {
      "permissions": {
        "deny":  ["mcp__meta-ads__*create*",
                  "mcp__meta-ads__*update*",
                  "mcp__meta-ads__*delete*",
                  "mcp__meta-ads__*pause*"],
        "allow": ["mcp__meta-ads__*get*",
                  "mcp__meta-ads__*insights*",
                  "mcp__meta-ads__*list*"]
      }
    }

  Deny patterns are guesses against an UNVERIFIED tool list. After connecting,
  enumerate the real tool names and rewrite these patterns against them. Do not
  trust the tool names in blog posts — several published lists are actually the
  third-party Pipeboard server's catalog, not Meta's.

  Set an account-level budget cap in Meta Business Suite regardless. It is the
  only guardrail that does not depend on getting these patterns right.

  Admins can disable user MCP servers entirely with
  "areUserMcpServersAllowed": false, or enforce a URL allowlist.
==============================================================================*/


/*==============================================================================
SECTION 2 — PATH A: API INTEGRATION (Cortex Agents / Snowflake CoWork)

  DCR is the right first attempt, not OAUTH2. Meta's connector is designed for
  interactive AI clients that register dynamically, and TYPE = OAUTH_DYNAMIC_CLIENT
  needs only a resource URL — no client ID or secret, which you have no
  documented way to obtain for this connector anyway.

  Verified constraints:
    - Snowflake supports ONLY OAuth for MCP server connections.
    - Hostnames must use hyphens, not underscores. mcp.facebook.com is fine.
    - Register this callback URL with the provider:
        https://identity.snowflake.com/oauth2/callback
      Some providers additionally require allowlisting it. THIS IS THE MOST
      LIKELY BLOCKER for Meta — a connector built for desktop AI clients may not
      permit a server-side OAuth client at all.
    - For PrivateLink, use SYSTEM$ALLOWLIST_PRIVATELINK, take the entry starting
      with app.<region>.privatelink.snowflakecomputing, and append
      /oauth/complete-secret.
==============================================================================*/
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS meta_ads_mcp_api_integration
    API_PROVIDER         = external_mcp
    API_ALLOWED_PREFIXES = ('https://mcp.facebook.com')
    API_USER_AUTHENTICATION = (
        TYPE               = OAUTH_DYNAMIC_CLIENT
        OAUTH_RESOURCE_URL = 'https://mcp.facebook.com/ads'
    )
    ENABLED = TRUE
    COMMENT = 'Meta Ads MCP Server, open beta (Expires: 2026-11-28)';

/*------------------------------------------------------------------------------
  FALLBACK — only if DCR fails and Meta documents a way to obtain OAuth client
  credentials for this connector.

  OAUTH_REFRESH_TOKEN_VALIDITY is REQUIRED reading here: the default of 0 means
  a refresh token that NEVER EXPIRES. Minimum accepted value is 3600. Set it
  explicitly. This parameter does NOT apply to DCR, which is another reason to
  prefer DCR above.

  The scope names below are the underlying Marketing API scopes. That the
  connector uses exactly this set is INFERENCE, not documented. business_management
  is included because Business-level asset access is reportedly needed; drop it
  if consent succeeds without it.
------------------------------------------------------------------------------*/
-- CREATE API INTEGRATION meta_ads_mcp_api_integration
--     API_PROVIDER         = external_mcp
--     API_ALLOWED_PREFIXES = ('https://mcp.facebook.com')
--     API_USER_AUTHENTICATION = (
--         TYPE                         = OAUTH2
--         OAUTH_CLIENT_ID              = '<client_id>'
--         OAUTH_CLIENT_SECRET          = '<client_secret>'
--         OAUTH_TOKEN_ENDPOINT         = '<meta_token_endpoint>'
--         OAUTH_AUTHORIZATION_ENDPOINT = '<meta_authorization_endpoint>'
--         OAUTH_CLIENT_AUTH_METHOD     = CLIENT_SECRET_BASIC
--         OAUTH_ALLOWED_SCOPES         = ('ads_read', 'business_management')
--         OAUTH_REFRESH_TOKEN_VALIDITY = 86400
--     )
--     ENABLED = TRUE
--     COMMENT = 'Meta Ads MCP Server, OAuth2 fallback (Expires: 2026-11-28)';


/*==============================================================================
SECTION 3 — EXTERNAL MCP SERVER OBJECT

  Note the schema choice: this object is schema-scoped, so put it somewhere
  deliberate rather than wherever your session happens to point. Always create
  and reference it fully qualified.
==============================================================================*/
USE ROLE SYSADMIN;
CREATE SCHEMA IF NOT EXISTS MARKETING.ACTIVATION
    COMMENT = 'Outbound ad-platform activation objects (Expires: 2026-11-28)';

USE ROLE ACCOUNTADMIN;
CREATE EXTERNAL MCP SERVER IF NOT EXISTS
    MARKETING.ACTIVATION.meta_ads_mcp_server
    WITH DISPLAY_NAME = 'Meta Ads'
    URL             = 'https://mcp.facebook.com/ads'
    API_INTEGRATION = meta_ads_mcp_api_integration;

DESCRIBE EXTERNAL MCP SERVER MARKETING.ACTIVATION.meta_ads_mcp_server;
SHOW EXTERNAL MCP SERVERS IN ACCOUNT;


/*==============================================================================
SECTION 4 — DELEGATE ACCESS

  USAGE is required on BOTH the MCP server AND the underlying API integration.
  Granting only one silently yields no tools. By default only account admins
  have access.

  Access to the MCP server does NOT automatically grant access to its tools —
  tool permissions are granted separately.

  Replace MARKETING_AGENT_ROLE with the role your Cortex Agent runs as. The
  CREATE ROLE below is a convenience for a clean test account; drop it if the
  role already exists.
==============================================================================*/
CREATE ROLE IF NOT EXISTS MARKETING_AGENT_ROLE
    COMMENT = 'Role owning the Meta Ads MCP-enabled agent (Expires: 2026-11-28)';

GRANT USAGE ON EXTERNAL MCP SERVER MARKETING.ACTIVATION.meta_ads_mcp_server
    TO ROLE MARKETING_AGENT_ROLE;

GRANT USAGE ON INTEGRATION meta_ads_mcp_api_integration
    TO ROLE MARKETING_AGENT_ROLE;


/*==============================================================================
SECTION 5 — ATTACH TO A CORTEX AGENT

  ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION REPLACES the whole
  spec. You must include the previous specification content alongside the
  mcp_servers block or you will destroy the agent's existing configuration.
==============================================================================*/
ALTER AGENT IF EXISTS MARKETING.ACTIVATION.my_marketing_agent
    MODIFY LIVE VERSION SET SPECIFICATION $$
    <paste_previous_specification_here>
    mcp_servers:
      - server_spec:
          name: "MARKETING.ACTIVATION.meta_ads_mcp_server"
$$;

-- Users then connect in Snowflake CoWork: sources panel -> Connectors ->
-- Connect, which redirects to Meta for consent. A connector that is not in the
-- Connected state is excluded from the agent's orchestration entirely.


/*==============================================================================
SECTION 6 — OAUTH FROM THE Agent:run API

  For non-CoWork clients. Run both in the SAME session: open the returned URL
  in a browser, consent, then pass the query string from the redirect back.
==============================================================================*/
SELECT SYSTEM$START_USER_OAUTH_FLOW('META_ADS_MCP_API_INTEGRATION');

-- SELECT SYSTEM$FINISH_OAUTH_FLOW('<query_string_from_redirect_url>');


/*==============================================================================
SECTION 7 — MONITORING

  Tool names, latency, and token usage need MONITOR on the agent. Full tool
  INPUTS AND OUTPUTS ARE REDACTED unless the role also holds
  READ UNREDACTED AI OBSERVABILITY EVENTS TABLE. For an ads connector this
  matters: without it you can see that a spend change was made but not what it
  was.
==============================================================================*/
SELECT
    timestamp,
    record_type,
    record,
    record_attributes
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND record_attributes:"snow.ai.observability.mcp.server.name"::STRING
      ILIKE '%meta_ads%'
ORDER BY timestamp DESC
LIMIT 100;

-- Attribute names in AI_OBSERVABILITY_EVENTS are subject to change. If the
-- filter above returns nothing, drop the ILIKE predicate, inspect
-- record_attributes for one known agent run, and re-derive the key.


/*==============================================================================
SECTION 8 — DISABLE, RE-ENABLE, DECOMMISSION

  DISABLE for maintenance or incident response. It preserves configuration but
  IMMEDIATELY invalidates all user tokens and calls Meta's revocation endpoint.
  Every agent using the server loses its tools at once, and users must
  re-authenticate from scratch afterward as if connecting for the first time.

  This is the kill switch if an agent starts making unintended spend changes.

  DROP to decommission. It PERMANENTLY deletes the OAuth configuration and all
  stored secrets; both objects must be recreated from scratch.

  VERIFIED BY EXECUTION: the drop order below works — the MCP server must go
  before its API integration.
==============================================================================*/
-- Kill switch:
-- ALTER API INTEGRATION meta_ads_mcp_api_integration SET ENABLED = FALSE;

-- Restore:
-- ALTER API INTEGRATION meta_ads_mcp_api_integration SET ENABLED = TRUE;

-- Decommission, in this order. You cannot create an MCP server that references
-- a disabled integration, and only OWNERSHIP can drop.
-- DROP EXTERNAL MCP SERVER IF EXISTS MARKETING.ACTIVATION.meta_ads_mcp_server;
-- DROP API INTEGRATION IF EXISTS meta_ads_mcp_api_integration;


/*==============================================================================
SECTION 9 — WHAT NOT TO DO

  1. Do not use MCP as a data pipeline. A tool call returns a JSON blob into a
     context window; it is not a join key and it does not scale to modeling.
     Land Meta data in Snowflake on a schedule, model it in a semantic view, and
     let Cortex Analyst answer questions. Use MCP for ACTIONS and for
     freshness-critical reads only.

  2. Do not give one agent both broad warehouse access and ads write scope
     without thinking about loops. Snowflake warns specifically about recursive
     loops between agents and MCP servers producing "expensive, unbounded
     loops." An agent that can query data and act on an ads platform is exactly
     that shape.

  3. Do not register a third-party Meta MCP server here expecting it to work.
     Servers using static bearer tokens or ?token= query parameters are
     INCOMPATIBLE with Snowflake's OAuth-only requirement for
     EXTERNAL MCP SERVER. They may work in Cortex Code via headers, but not in
     Cortex Agents.

  4. Do not treat this as governed by Snowflake. Snowflake's own disclaimer:
     external MCP servers "are not provided, maintained, or verified by
     Snowflake," and you are responsible for the server's trustworthiness and
     for complying with third-party terms governing the data. For ad data with
     audience and PII characteristics, that is a real obligation.
==============================================================================*/
