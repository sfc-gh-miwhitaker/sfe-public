![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2026--11--28-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Snowflake and the Ad Platforms: Meta Ads MCP and Google Ads Data Manager

Two different integrations that get confused with each other. **Google Ads Data Manager**
pulls first-party audience and conversion data *out of* Snowflake into Google Ads — it is a
native, no-code connector and Snowflake is on the supported source list. **Meta's Ads MCP
Server** lets an AI agent *operate* Meta ad accounts — it is an open-beta tool surface, not
a data pipe, and nothing about it reads your warehouse.

One moves rows. The other moves intent. Choosing the wrong one for the job is the most
common mistake in this area.

**Audience:** Marketing data engineers and Snowflake administrators building first-party
data activation, and SEs fielding "can Snowflake talk to Meta/Google Ads?" questions.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-28 | **Expires:** 2026-11-28 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

Pick the row that matches what you are actually trying to do.

| Goal | Use | Maturity | Section |
|---|---|---|---|
| Push audience lists from Snowflake to Google Ads | Google Ads Data Manager, Snowflake source | Native connector, no status label | [Part 1](#part-1--google-ads-data-manager) |
| Push offline conversions from Snowflake to Google Ads | Google Ads Data Manager, Snowflake source | Native connector | [Part 1](#part-1--google-ads-data-manager) |
| Let an agent create, pause, or report on Meta campaigns | Meta Ads MCP Server | **Open beta** | [Part 2](#part-2--meta-ads-mcp-server) |
| Push audience lists from Snowflake to **Meta** | Neither — see the gap | No native path | [The Meta activation gap](#the-meta-activation-gap) |
| Pull Google Ads performance data *into* Snowflake | Openflow Connector for Google Ads | **Preview** | [Reverse direction](#reverse-direction-ads--snowflake) |

### The one-sentence version of each

- **Google Ads Data Manager** is a point-and-click importer inside Google Ads. You register
  a Snowflake table or view once, map columns to a destination (Customer Match, offline
  conversions), and schedule a daily refresh. Google connects outbound to your Snowflake
  endpoint with a username and a Programmatic Access Token.
- **Meta Ads MCP Server** is a hosted remote MCP endpoint Meta exposes over the Marketing
  API. You add it to an MCP client — Claude Desktop and Cortex Code today, and Snowflake
  CoWork via `EXTERNAL MCP SERVER` (untested — see [Part 2](#part-2--meta-ads-mcp-server)) —
  and authenticate with Meta Business OAuth. It gives an agent tools, not tables.

### Before you start

For Part 1: Google Ads administrator access, plus Snowflake privileges to create a role, a
service user, and a PAT (`CREATE ROLE` and `CREATE USER` are account-level).

For Part 2: an admin role on the target Meta ad account in Business Manager, and — for the
Cortex Agents path — `CREATE INTEGRATION` (ACCOUNTADMIN by default).

### Provenance of the claims in this guide

This guide documents two vendors' moving targets. Claims are tagged:

- **Verified** — read from official Snowflake or Google documentation, or executed against a
  live Snowflake account.
- **Beta-reported** — consistent across multiple secondary sources but not confirmable from
  Meta's own documentation, which is JavaScript-rendered and not machine-readable.
- **Untested** — a construction that follows documented Snowflake syntax but that nobody has
  published working end-to-end.

**The Snowflake side of both `sql/` files was executed end-to-end against a live account
(v10.30.102) on 2026-08-28, then torn down.** That includes the least-privilege role, the
`SERVICE_AGENT` user, a real PAT with no network policy, both views, the `external_mcp` API
integration, the `EXTERNAL MCP SERVER`, `SYSTEM$START_USER_OAUTH_FLOW`, and the teardown
ordering. Positive *and* negative access tests were run.

That run found two defects in an earlier draft, both since fixed: the least-privilege
verification needs `USE SECONDARY ROLES NONE` to mean anything, and the service user needs
`DEFAULT_SECONDARY_ROLES = ()`. Both are called out inline.

**What execution did not prove:** creating the MCP objects is metadata only — Snowflake does
not contact Meta at `CREATE` time, and `SYSTEM$START_USER_OAUTH_FLOW` only returns a consent
URL for a browser. The Meta handshake itself remains untested.

---

## Part 1 — Google Ads Data Manager

### Where it lives

Google Ads: **Tools → Data manager** (direct: `https://ads.google.com/aw/productlinks`).

Note that Google collapsed the old "Tools & settings" menu into **Tools**. Older
walkthroughs routing you through *Tools & settings → Shared library → Audience manager*
describe a still-functional but secondary entry point.

Data Manager also exists in **Display & Video 360** (Advertiser settings → Data manager) and
**Campaign Manager 360**, each with its own scope and its own admin requirement. The DV360
source list is nearly identical but swaps Google Drive for Google Business Profile.

Do not confuse this with **Marketing Data Manager**, a separate Google product currently in
limited beta.

### Snowflake is a first-party source

**Verified.** Snowflake is one of 17 direct-connection sources, alongside Amazon Redshift,
BigQuery, S3, Salesforce, HubSpot, PostgreSQL, MySQL, Oracle, Shopify, and others. Google's
own supported-sources table describes these as connecting "directly to Google Ads without
third-party integration partners."

Snowflake and S3 were added together, and the launch note scoped both to **Customer Match
and offline conversion imports**. Enhanced conversions for leads is also documented.

**One honest caveat:** Google never labels the Snowflake connector GA, beta, or allowlisted.
It carries no preview banner, and sibling features in the same help navigation *do* carry
explicit "(beta)" tags — so GA is a reasonable inference, but it is an inference. Do not tell
a customer it is "GA" as though Google said so.

### Architecture

```
   ┌──────────────────────────────────────────────────────┐
   │ Snowflake                                            │
   │                                                      │
   │   base tables (PII, all history)                     │
   │        │                                             │
   │        ▼                                             │
   │   SECURE VIEW  V_GOOGLE_CUSTOMER_MATCH               │
   │   column aliases = Google's expected headers         │
   │        │                                             │
   │   granted SELECT to GOOGLE_ADS_DM_ROLE only          │
   │        │                                             │
   │   GOOGLE_ADS_DM_SVC  (service user, PAT auth)        │
   └────────┼─────────────────────────────────────────────┘
            │  outbound-initiated by Google
            │  HTTPS from Google Cloud egress IPs
            │  username + Programmatic Access Token
            ▼
   ┌──────────────────────────────────────────────────────┐
   │ Google Ads Data Manager                              │
   │   normalize → SHA-256 (hex) → confidential match     │
   │        │                                             │
   │        ▼                                             │
   │   Customer Match list  /  offline conversions        │
   └──────────────────────────────────────────────────────┘
```

Google initiates the connection. There is no Snowflake-side scheduler, no egress
integration, and no Google service account to grant. Snowflake is a passive source.

### Authentication: it is a PAT, not a password

**Verified, and this is the detail most people get wrong.** Google's requirements block for
the Snowflake source asks for:

- Snowflake **username**
- **Account identifier**
- A **Programmatic Access Token (PAT)**, "used in place of a password"

The connector is **not** key-pair and **not** OAuth. The UI field is labeled *password* —
paste the PAT into it. This matches Snowflake's own guidance for third-party tools.

> **Documented contradiction, flagged deliberately:** the collapsed step-by-step body on the
> same Google help page still says "enter your Snowflake account identifier, username, and
> password." The Requirements block saying PAT is the newer and authoritative text. Do not
> "correct" this guide back to password auth.

**Account identifier format.** Copy it from Snowsight; it arrives as
`orgname.account_name`. If underscores are rejected, replace them with hyphens.

**There is no ROLE field.** This is the important consequence: because Google gives you
nowhere to specify a role, you must pin the role server-side with `ROLE_RESTRICTION` on the
PAT. Otherwise the connection runs as the user's default role, which is exactly the kind of
implicit privilege you do not want on a PII view.

### The network policy problem — read this before you promise a customer it works

This is the single hardest operational constraint, and it is a genuine conflict between the
two products.

**Google's side:** "Snowflake is accessed from Google Cloud IP addresses. However, Google
Cloud external IP ranges are dynamic and subject to change." Google publishes the ranges at
`https://www.gstatic.com/ipranges/cloud.json` and expects you to refresh your firewall from
it.

**Snowflake's side:** PAT authentication is network-policy-gated by default. With
`NETWORK_POLICY_EVALUATION = ENFORCED_REQUIRED`, a `TYPE = SERVICE` user cannot generate or
use a PAT unless it is subject to a network policy.

So Snowflake wants a static allowlist and Google offers a moving target. Three ways out,
in descending order of preference:

1. **Use `TYPE = SERVICE_AGENT`.** This user type can generate and use a PAT without being
   subject to a network policy. It is the cleanest resolution and avoids both a bypass flag
   and a self-updating firewall job.
2. **Maintain a network policy from Google's published ranges**, refreshed on a schedule.
   Highest assurance, real ongoing maintenance cost, and it breaks silently when Google adds
   a range before your job runs.
3. **Set `PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED)`.** Works.
   Snowflake does not recommend it. Disclose it as a deliberate exception, not a default.

**PrivateLink: unverified, and probably incompatible.** Neither Google's nor Snowflake's
documentation addresses PrivateLink for this connector. Given Google connects to the public
endpoint from Google Cloud IPs, a Snowflake account restricted to PrivateLink-only ingress
will very likely break it. Test before asserting either way.

### Let Google do the hashing

**Verified, and it saves you compute.** Data Manager states plainly: it "will hash the data
for you using the SHA256 algorithm," hex-encoded, and "you don't need to pre-format your
data." Normalization, hashing, and encoding all happen on Google's side.

So do **not** burn Snowflake credits on SHA-256 unless a customer policy forbids sending
unhashed PII outbound. If you must pre-hash:

- Normalize first: trim, lowercase, phone numbers in **E.164**, strip periods before the
  domain for `gmail.com` and `googlemail.com`.
- Hash to **hex** SHA-256. Snowflake's `SHA2(col, 256)` returns a lowercase 64-character hex
  string — **verified by execution** — which is the correct format.
- **Do not hash `Country` or `Zip`.** They must stay in cleartext.

> **Second documented contradiction:** Google's legacy manual-upload page labels its hashed
> examples "Base64 Encoded," while the Data Manager data-prep page specifies hex, and the
> Data Manager API rejects non-hex with `INVALID_HEX_ENCODING`. For the Data Manager path,
> **hex wins.**

### Column headers

Customer Match expects these exact English headers:

`Email` · `Phone` · `First Name` · `Last Name` · `Country` · `Zip` · `Mobile Device ID`

- Mailing-address matching requires **all four** of First Name, Last Name, Country, Zip.
- Multiple `Email`, `Phone`, or `Zip` columns are allowed for one customer.
- `Mobile Device ID` must be the **only** header present, and must be **unhashed** —
  hashing device IDs is unsupported.
- No name prefixes ("Mr."). Emails need a domain. Accented characters are fine in names but
  will not match in emails.

Google's field-mapping UI can map arbitrary source columns to destination fields, so exact
naming is a convenience rather than a hard requirement — but matching the headers in your
view removes a manual step and a class of mapping mistakes. Note that the headers contain
spaces, so they need **double-quoted identifiers** in Snowflake. See
`sql/google_ads_data_manager_setup.sql`.

**Offline conversion and enhanced-conversion column names are not documented here.**
`conversion_value` and the conversion time/date columns are confirmed; the exact required
set, including the gclid column name, sits inside a collapsed accordion in Google's help
that could not be read programmatically. Open Google's data-prep page in a browser and read
the schema table before building that view.

### Scheduling and refresh semantics

- **Daily import and daily scheduled refresh** are documented. Manual one-off runs are
  supported.
- Google's confidential-matching FAQ claims "daily, weekly, and ad hoc." Two other pages say
  daily only. **The docs conflict**; verify in the UI for your account.
- **Google does not detect change.** You must refresh the Snowflake object *before* the
  scheduled start time. If your data is stale, Google imports stale data.
- **Whether a run is incremental or a full read is undocumented.** What *is* documented is at
  the audience level: replace all data, add customers, or remove specific customers. The
  safe design is therefore to model the view as **the desired current state**, not an
  append-only event log.
- Customer Match processing can take **up to 48 hours**.
- **Imports should not exceed 100 million rows.**

### Constraints worth knowing before the customer finds them

**Minimums — the widely-repeated "1,000 users" figure is wrong.** Current Google docs say:

- Minimum **100 user records** per submitted file.
- Match rates display only with **at least 100 rows matched**.
- A list stays eligible with **at least 100 members added or updated in the last 540 days**.

Membership duration caps at **540 days**. Reported list size is bucketed and will always be
lower than rows uploaded. Mobile-device-ID lists only include users active on Google
networks in the past 30 days.

**Filters run in Google, not Snowflake.** One filter with up to 25 conditions per connection.
You do not need a separate Snowflake view per audience variant — though a view per *use case*
is still the right boundary.

**Reauthorize per connection.** Every new audience segment or conversion action connection
requires reauthorizing the Snowflake account. Credentials are stored against the Google Ads
account and shared by all its users.

**Data source name is load-bearing.** Rename it and the integration breaks; data silently
stops updating.

**Date parsing will bite you.** `02/01/2026` is read as **February 1** (MM/DD/YYYY). If
Google detects even one unambiguous DD/MM/YYYY row, the **entire import fails** by design.
Rows without a timezone are dropped unless you set a fallback. Emit ISO 8601 from Snowflake
and remove the ambiguity.

**PAT expiry is an operational time bomb.** Default expiry is **15 days**, maximum 365, and
**expiry cannot be changed after creation** — you revoke and reissue. A PAT that quietly
expires looks exactly like a broken connector. The reference SQL overrides the default to
**90 days** so reissue fits a quarterly process; set your renewal reminder from whichever
value you actually choose, and monitor `LOGIN_HISTORY`.

**EEA/UK restriction.** Since March 2024, Customer Match lists activated on Google Partner
inventory or third-party exchanges in the EEA, UK, and Switzerland are unavailable for web
and app. Google's owned-and-operated properties still work. This is a real targeting
limitation, not a configuration issue.

**Consent.** Data Manager has a Consent settings tab covering both tag and imported data,
with per-connection override. At the API layer the DMA fields are `adUserData` and
`adPersonalization`, each `CONSENT_GRANTED` / `CONSENT_DENIED` / `CONSENT_STATUS_UNSPECIFIED`.
Whether the *UI connector* exposes these as per-row mappable columns from Snowflake is
**unverified** — the UI definitely exposes connection-level defaults. Either way, the user's
own signal wins: if Google lacks consent for a user, that user is ineligible regardless of
what you send.

### Confidential matching — the good news, and its one limit

**Verified and worth leading with.** Confidential matching is **on by default, at no cost,
requiring no advertiser action** for Customer Match via a direct connection — which is
exactly what the Snowflake connector is. Google states that all Data Manager Customer Match
sources support it, so Snowflake qualifies.

It runs in a Trusted Execution Environment (Google Cloud Confidential Space), strips unused
identifiers, and supports cryptographic attestation. The implementation is open source at
`github.com/google-ads-confidential-computing/confidential-match`, and NCC Group has
published an independent review of Confidential Space.

**The limit that matters for Snowflake:** optional customer-side *encryption* — the stronger
tier — is awkward here. Google notes it "may be complex or infeasible… if your preferred data
source is not an object store," and names GCS as the example that works. If a customer
demands encrypted confidential matching, **Snowflake is the wrong source and GCS is the right
one.** Say so early rather than discovering it in implementation.

### Snowflake-side recommendations

These are recommendations, not vendor doctrine. Snowflake's documentation does not mention
Google Ads Data Manager anywhere — a real content gap.

- **Expose a view, not a table.** Google explicitly accepts "table (or view)." A view
  decouples the activation contract from physical storage.
- **Prefer a `SECURE VIEW`** for PII activation. **Verified by execution:** a role holding
  only `USAGE` + `SELECT` on the view cannot run `GET_DDL` against it, so the definition and
  the base table name stay hidden. Trade-off: some optimizations are disabled, so expect
  slower scans. A standard view is defensible when the base table is already tightly scoped.

  **The caveat that invalidates most people's test of this:** that protection only holds if
  the session is not carrying a privileged *secondary* role. An interactive user usually has
  `DEFAULT_SECONDARY_ROLES = ALL`, so `USE ROLE GOOGLE_ADS_DM_ROLE` leaves `ACCOUNTADMIN`
  active alongside it — and under those conditions `GET_DDL` **succeeds**. Run
  `USE SECONDARY ROLES NONE` first, and set `DEFAULT_SECONDARY_ROLES = ()` on the service
  user so the connector identity never has the problem at all.
- **One view per use case**, named for the destination. Use Google's filters for variants
  within a use case.
- **Grant `SELECT` on the specific view only.** Never `SELECT ON ALL TABLES` and never
  future grants in that schema.
- **Pin the role via PAT `ROLE_RESTRICTION`**, since Google has no role field. Consider an
  authentication policy with `PAT_POLICY = (BLOCKED_ROLES_LIST = ('ACCOUNTADMIN','SYSADMIN'))`.
- **Set `DEFAULT_SECONDARY_ROLES = ()` on the service user.** Left at the default, Snowflake
  gives it `[ALL]`, which quietly widens the identity's reach past what `ROLE_RESTRICTION`
  suggests. Verified by execution, and accepted inline on `CREATE USER`.
- **Size the warehouse small and set `STATEMENT_TIMEOUT_IN_SECONDS`.** This is a periodic
  extract, not analytics.
- **Audit it.** Join `LOGIN_HISTORY` where
  `first_authentication_factor = 'PROGRAMMATIC_ACCESS_TOKEN'` to `CREDENTIALS` on credential
  ID to prove which PAT authenticated when, then to `SESSIONS` and `QUERY_HISTORY` for what
  it read.

Full SQL: **`sql/google_ads_data_manager_setup.sql`**.

### The API is where this is heading

Google Ads API Customer Match uploads via `OfflineUserDataJobService` and `UserDataService`
are being retired in favor of the **Data Manager API**. Google's own help pages now carry
banners telling developers to "avoid implementing new Customer Match workflows using the
Google Ads API."

The Data Manager API uses OAuth 2.0 with the `datamanager` scope, offers REST and gRPC, has a
`validateOnly` dry-run parameter, and supports confidential matching and encryption the old
API did not. If you are writing code rather than clicking, target it.

Specific sunset **dates** circulating in trade press are **not** on Google's help pages.
The direction is confirmed by Google's own banners; the calendar is not. Do not put dates in
a customer deck.

---

## Part 2 — Meta Ads MCP Server

### What it is, and what it is not

**Verified:** Meta publishes an official MCP server. The umbrella product is **Meta Ads AI
Connectors**, comprising an **MCP server** and a **CLI**. The documentation page is titled
"Ads MCP Server," lives under `developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/`,
and the launch announcement is at `facebook.com/business/news/meta-ads-ai-connectors`.

It wraps the **Marketing API**. Meta's announcement describes it as giving advertisers "a
secure, Meta-authenticated connection from their ad account to an AI agent," with "no
developer credentials, API setup, or coding required."

**Verified: open beta.** Meta's own announcement text says "in open beta." It is not GA and
no GA date has been announced.

**What it is not:** it is not a data pipeline. It does not read Snowflake. It exposes tools an
agent can call against your Meta ad accounts. If you want Meta *performance data* in
Snowflake for modeling, this is the wrong tool.

There is **no public GitHub repository** — it appears to be a closed-source hosted service.
That is a notable contrast with Google, which does publish `github.com/googleads/google-ads-mcp`.

### A necessary caveat about the details below

`developers.facebook.com` and `facebook.com/business` are client-side JavaScript-rendered.
Their page **existence and titles** are verifiable, and the announcement page's **indexed
excerpt** is readable, but the documentation bodies are not machine-readable. Everything in
the next three subsections is therefore **beta-reported** — consistent across many secondary
sources, most of which are vendor blogs with a competing product to sell.

**Open these two pages in a real browser before quoting any of it to a customer:**

- `.../ads-ai-connectors/ads-mcp-server/ads-mcp-server-overview`
- `.../ads-ai-connectors/ads-mcp-server/ads-mcp-server-get-started`

They will settle the endpoint, the tool list, the scopes, the rate limits, and the CLI
install command — the five things that could not be confirmed.

### Endpoint, auth, and tools (beta-reported)

- **Endpoint:** `https://mcp.facebook.com/ads`. A hosted remote endpoint — there is no
  install step, you paste a URL. At least one source warns to paste it exactly, with no
  trailing slash, implying path sensitivity only official docs can settle.
- **Auth:** Meta Business OAuth in the browser. Reported to need **no** Meta Developer App,
  **no** App Review, and **no** manually managed system-user token. This aligns with Meta's
  official "no developer credentials" claim. **One secondary source contradicts this**,
  claiming a Developer App is required — flagging the conflict rather than resolving it.
- **Scopes:** `ads_read`, `ads_management`, `business_management`, sometimes
  `read_insights`. These are the underlying Marketing API scopes; that the connector uses
  exactly this set is inference.
- **Prerequisite:** admin role on the target ad account in Business Manager. You choose which
  ad accounts to grant during consent.
- **Tool count: 29**, across reporting and insights, campaign management, catalog operations,
  account diagnostics, and dataset/signal quality. The count is unusually consistent across
  sources, which suggests it traces to a real official list.
- **Safety behavior:** objects an agent creates reportedly land **PAUSED**, requiring a human
  to activate.
- **Rate limits:** none published for the MCP during beta. Marketing API limits presumably
  still apply, but the specific figures floating around (200 calls/hour, etc.) are
  third-party claims about the *API*, not the connector. Do not quote them as authoritative.

**Two corrections to widely-circulated misinformation:**

1. **`npm install -g @meta/ads-cli` does not work.** The npm registry returns HTTP 404 for
   `@meta/ads-cli` — **verified directly against `registry.npmjs.org`.** No Meta-published
   npm package exists. The only registry matches are third-party, one of which self-describes
   as "Unofficial." One source describes the real CLI as a local *Python* tool. The actual
   distribution channel is **unverified** — do not repeat the npm command.
2. **Tool names in blog posts are contaminated.** Lists citing
   `mcp_meta_ads_get_login_link` are quoting the **third-party Pipeboard** server's tool
   catalog, not Meta's. Treat every specific `ads_*` tool name you see in a blog post as
   unreliable; only the count and the five capability areas have broad agreement.

### Connecting it to Snowflake

Snowflake has a genuinely first-class mechanism for consuming external MCP servers. **The
Snowflake half of what follows is fully verified.** The Meta half is not, so both paths are
**untested** — no working Meta↔Snowflake MCP integration has been published anywhere.

#### Path A — Cortex Agents and Snowflake CoWork (`EXTERNAL MCP SERVER`)

**Verified mechanism.** An admin creates an API integration holding OAuth credentials, then
an `EXTERNAL MCP SERVER` object referencing it, then adds that server to a Cortex Agent.
CoWork users complete OAuth in the browser and the agent's tools light up.

Snowflake's pre-built connectors are exactly **Atlassian, GitHub, Glean, Linear, Salesforce**.
**Meta is not among them**, so it must be built as a custom connector.

The important refinement over the naive approach: Snowflake supports
**`TYPE = OAUTH_DYNAMIC_CLIENT`**, which performs Dynamic Client Registration and needs only
`OAUTH_RESOURCE_URL`. Since Meta's connector is designed for interactive AI clients that
register dynamically, **DCR is the better first attempt than `TYPE = OAUTH2`** with a manual
client ID and secret you have no documented way to obtain.

```sql
CREATE API INTEGRATION meta_ads_mcp_api_integration
  API_PROVIDER = external_mcp
  API_ALLOWED_PREFIXES = ('https://mcp.facebook.com')
  API_USER_AUTHENTICATION = (
    TYPE = OAUTH_DYNAMIC_CLIENT
    OAUTH_RESOURCE_URL = 'https://mcp.facebook.com/ads'
  )
  ENABLED = TRUE;

CREATE EXTERNAL MCP SERVER MARKETING.ACTIVATION.meta_ads_mcp_server
  WITH DISPLAY_NAME = 'Meta Ads'
  URL = 'https://mcp.facebook.com/ads'
  API_INTEGRATION = meta_ads_mcp_api_integration;
```

Qualify the MCP server name. The object is schema-scoped, so an unqualified `CREATE` lands
it in whatever schema the session happens to point at.

**Verified constraints that shape this path:**

- **OAuth only.** "Snowflake supports only OAuth for MCP server connections." A static-token
  server cannot be registered this way at all.
- **Callback URL:** `https://identity.snowflake.com/oauth2/callback`. Some providers also
  require allowlisting it. **This is the most likely hard blocker** — Meta must accept a
  server-side OAuth client with Snowflake's callback, and whether a connector designed for
  desktop AI clients permits that is unknown.
- **Tools only.** External MCP servers "support tool capabilities only" — no resources,
  prompts, roots, notifications, or sampling. Fine for Meta's tool-only surface.
- **Hostnames must use hyphens, not underscores.** `mcp.facebook.com` is fine.
- **`OAUTH_REFRESH_TOKEN_VALIDITY` does not apply to DCR.** If you fall back to
  `TYPE = OAUTH2`, set it explicitly (minimum 3600) — the default of `0` means a refresh
  token that **never expires**.
- **Privileges:** `CREATE EXTERNAL MCP SERVER` on the schema; to delegate, grant `USAGE` on
  **both** the MCP server **and** the underlying API integration. Account admins only by
  default.
- **Observability:** calls land in `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS` and appear as
  spans in the agent Observability tab. Tool names, latency, and tokens need `MONITOR` on the
  agent; full inputs and outputs are redacted without
  `READ UNREDACTED AI OBSERVABILITY EVENTS TABLE`.
- **Disable vs drop:** disabling the API integration invalidates all user tokens immediately
  and calls the provider's revocation endpoint, but preserves config. Dropping permanently
  deletes the OAuth configuration and secrets. Disable for maintenance; drop to decommission.

Snowflake attaches an explicit disclaimer to this feature: external MCP servers "are not
provided, maintained, or verified by Snowflake," and you are responsible for the server's
trustworthiness and for complying with third-party terms governing the data. For ad data
with audience and PII characteristics, that is a real governance obligation.

#### Path B — Cortex Code (`mcp.json`) — try this first

**Verified mechanism, and far more likely to work.** Cortex Code is itself an MCP client
supporting `stdio`, `http`, and `sse`, with a native OAuth block. Omitting `client_id` makes
Cortex Code attempt **Dynamic Client Registration** and open your system browser — which is
behaviorally identical to how Claude Desktop and Cursor connect, the exact flow Meta designed
for.

```bash
cortex mcp add meta-ads https://mcp.facebook.com/ads --type http
```

Tools namespace as `mcp__meta-ads__<tool>`. Tokens go to the OS keychain and auto-refresh.

**The practical guardrail worth applying:** `~/.snowflake/cortex/permissions.json` lets you
`deny` the write tools and `allow` only reads. With `ads_management` granted, an agent can
change live spend — start read-only, and set an account-level budget cap in Business Suite
regardless. Admins can also disable user MCP servers entirely
(`areUserMcpServersAllowed: false`) or enforce a URL allowlist.

Configuration details and a permissions example: **`sql/meta_ads_mcp_setup.sql`**.

#### Which path

Start with **Path B**. It costs nothing, requires no ACCOUNTADMIN, and its auth flow matches
what Meta built for. Only after you have confirmed the endpoint and the OAuth behavior
interactively should you attempt Path A — where a failure could be Meta's callback policy,
Snowflake's DCR handshake, or a wrong endpoint, with little to distinguish them.

### Do not use MCP as a data pipeline

An MCP tool call returns a JSON blob into a context window. It is not a join key, and it does
not scale to modeling.

The durable pattern: **land Meta ads data in Snowflake on a schedule, model it in a semantic
view, and let Cortex Analyst answer questions about it.** Use the Meta MCP connector only for
*actions* — create, pause, adjust — and for freshness-critical reads that must bypass your
pipeline latency.

Snowflake also warns specifically about **recursive loops** between agents and MCP servers
producing "expensive, unbounded loops." An agent that can both query the warehouse and call
an ads API is exactly the shape where that happens.

### Third-party Meta Ads MCP servers

An official server now exists, so these are alternatives rather than necessities. The
largest is **`pipeboard-co/meta-ads-mcp`** (~1.2k stars, Python, hosted option, 42 tools).
Others include `hashcott/meta-ads-mcp-server` (TypeScript, 54 tools with writes gated behind
an env var), `gomarble-ai/facebook-ads-mcp-server` (Python, MIT), and `amekala/ads-mcp`
(multi-platform, OAuth 2.1 with DCR and PKCE).

Four cautions that are substantive rather than pro forma:

1. **Token custody is the core risk.** Self-hosting means handing a Marketing API token with
   `ads_management` to third-party code. Multiple sources report advertiser accounts being
   **restricted by Meta** for misuse of developer tokens with third-party AI tools — and
   report that this is part of *why* Meta shipped an official connector.
2. **Licensing is not what it looks like.** Pipeboard is **Business Source License 1.1**,
   not OSI open source; it converts to Apache-2.0 in 2029 and forbids competing hosted
   services. It is routinely mislabeled "open source." Its history also includes an SSRF fix
   in `upload_ad_image` and an HTTP auth middleware fix — read as normal maturation, but read
   it.
3. **API version drift.** `hashcott` pins Graph API v22.0 while the official connector
   reportedly targets v25.0. Self-hosted servers rot.
4. **They mostly cannot be used with Path A.** Servers authenticating via static bearer
   tokens or `?token=` query parameters are **incompatible** with Snowflake's OAuth-only
   requirement for `EXTERNAL MCP SERVER`. They may work in Cortex Code via `headers`, but not
   in Cortex Agents.

---

## The Meta activation gap

Worth stating plainly, because it is the question customers ask next.

Google Ads has a native Snowflake source. **Meta does not.** There is no Meta equivalent of
Data Manager's Snowflake connector — Meta's official MCP server is a tool surface, not an
importer, and Custom Audience uploads still go through the Marketing API or a partner.

So for Snowflake → Meta audience activation the realistic options are:

- A **reverse-ETL partner** (Hightouch and similar) that reads Snowflake and writes Custom
  Audiences via Meta's API.
- **Your own code** against the Marketing API, with a Snowflake external access integration
  and the token-custody responsibility that implies.
- **Meta's own file-based upload**, which is not an integration.

If a customer says "we do this with Google, do it with Meta," the answer is that the shape is
genuinely different and the effort is not comparable.

---

## Reverse direction: Ads → Snowflake

For completeness, since it is usually the second half of the conversation.

**Openflow Connector for Google Ads** — Snowflake-native, uses the Google Ads API,
configurable custom reports. **Explicitly a preview feature.** BYOC deployments are AWS
commercial regions only; Openflow Snowflake deployments cover AWS, Azure, and GCP commercial.

Two ingestion modes: **snapshot** (default, appends each run) and **incremental** (enabled by
including the `segments.date` segment, overlapping by the conversion window — a 14-day window
on a daily run means 13 days of overlap, so plan your deduplication). Limitations: no
filtering, no custom columns, no attributed-resource ingestion, one report per
(resource name, client ID) pair, and all-zero metric rows are dropped when segmenting.

**Snowflake Connector for Google Analytics** is a distinct, GA product on the Marketplace —
no extra licensing, consumes your credits. Aggregate data via the GA4 API; raw event data
replicated from the BigQuery storage layer.

Third-party ELT also covers this ground for both Google and Meta.

---

## Quick reference

| Question | Google Ads Data Manager | Meta Ads MCP Server |
|---|---|---|
| Moves warehouse rows? | Yes | No |
| Direction | Snowflake → Google Ads | Agent ↔ Meta ad account |
| Maturity | Native source, no status label | Open beta |
| Snowflake auth | Username + PAT | N/A (Meta Business OAuth) |
| Snowflake object | Table or view (prefer secure view) | `EXTERNAL MCP SERVER` or `mcp.json` |
| Who initiates | Google, outbound to Snowflake | The MCP client |
| Network policy issue | Yes — dynamic Google Cloud IPs | No |
| Hashing | Google does it, hex SHA-256 | N/A |
| Cadence | Daily scheduled, or manual | Per agent turn |
| Documented by Snowflake? | **No** | The generic `EXTERNAL MCP SERVER` mechanism, yes; Meta's server itself, no |

---

## Related Guides

- [Google Ads Data Manager — connect Snowflake](https://support.google.com/google-ads-data-manager/answer/14186945)
- [Snowflake MCP Connectors](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp-connectors)
- [Snowflake Programmatic Access Tokens](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [CREATE API INTEGRATION](https://docs.snowflake.com/en/sql-reference/sql/create-api-integration)

## External References

**Google**

- [Data Manager overview](https://support.google.com/google-ads-data-manager/answer/13761872)
- [Supported data sources](https://support.google.com/google-ads-data-manager/table/13860693)
- [Connect Snowflake](https://support.google.com/google-ads-data-manager/answer/14186945)
- [Prepare your data (hashing, dates, filters, row limits)](https://support.google.com/google-ads-data-manager/answer/14184381)
- [Manage connections](https://support.google.com/google-ads-data-manager/answer/13944739)
- [Confidential matching](https://support.google.com/google-ads-data-manager/answer/14577185)
- [Customer Match about page (540-day, minimums, EEA)](https://support.google.com/google-ads/answer/6379332)
- [Customer Match data formatting](https://support.google.com/google-ads/answer/7659867)
- [Data Manager API](https://developers.google.com/data-manager/api)
- [DMA Consent object](https://developers.google.com/data-manager/api/reference/rest/v1/Consent)
- [DV360 Data Manager sources](https://support.google.com/displayvideo/answer/17233737)
- [Google Cloud IP ranges (JSON)](https://www.gstatic.com/ipranges/cloud.json)
- [Confidential match, open source](https://github.com/google-ads-confidential-computing/confidential-match)

**Meta**

- [Ads MCP Server overview](https://developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/ads-mcp-server/ads-mcp-server-overview)
- [Ads MCP Server, get started](https://developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/ads-mcp-server/ads-mcp-server-get-started)
- [Meta Ads AI Connectors announcement](https://www.facebook.com/business/news/meta-ads-ai-connectors)

**Snowflake**

- [MCP Connectors](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp-connectors)
- [Snowflake-managed MCP server](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [Cortex Code MCP configuration](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-mcp)
- [Programmatic access tokens](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [Account identifiers](https://docs.snowflake.com/en/user-guide/admin-account-identifier)
- [Access control privileges](https://docs.snowflake.com/en/user-guide/security-access-control-privileges)
- [Openflow Connector for Google Ads](https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/google-ads/about)
