# guide-ad-platform-integrations — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Repo-wide guide format standards live in the root
     AGENTS.md. Do not duplicate either here. -->

## Scope

Reference guide covering two commonly conflated ad-platform integrations:

1. **Google Ads Data Manager** with Snowflake as a native first-party source —
   Snowflake → Google Ads for Customer Match and offline conversions.
2. **Meta's Ads MCP Server** — an open-beta tool surface for agents operating Meta ad
   accounts, registered in Snowflake via `EXTERNAL MCP SERVER` or Cortex Code `mcp.json`.

The guide's central framing: **one moves rows, the other moves intent.** Preserve that
distinction on every update. The most common reader error is expecting Meta's MCP server to
be a data pipe, and the guide exists partly to correct that.

No deploy script. The `sql/` files are reviewed copy/paste references — `CREATE INTEGRATION`,
`CREATE USER`, and `CREATE ROLE` all require ACCOUNTADMIN.

## Three-Tier Claim Provenance — Preserve This System

This guide documents two vendors' independently moving targets, one of which has
machine-unreadable documentation. Every claim carries a provenance tag, and the README
explains the taxonomy to the reader in a "Provenance of the claims" subsection.

| Tier | Meaning | How to re-verify |
|---|---|---|
| **Verified** | Read from official Snowflake or Google docs, or executed live | Re-fetch the page, or re-execute |
| **Beta-reported** | Consistent across secondary sources, unconfirmable from Meta's own docs | Open Meta's JS-rendered pages in a real browser |
| **Untested** | Follows documented Snowflake syntax; the Meta OAuth handshake specifically | Requires a Meta ad account plus a browser |

**Both `sql/` files were executed end-to-end against a live account (v10.30.102) on
2026-08-28 and torn down.** Do not downgrade the Google half back to "reviewed reference" —
it is executed and verified, including negative access tests.

**Do not upgrade a tier without doing the verification work.** Do not silently drop the tags
to make the guide read more confidently — the hedging is the value here, not a defect.

## Verified Facts — Do Not Regress These

Confirmed by execution or by primary documentation:

- `SHA2(col, 256)` returns a **lowercase 64-character hex** string. **Executed live.** This
  is why the pre-hash variant uses `SHA2` and not `BASE64_ENCODE`.
- Google Ads Data Manager authenticates with a **Programmatic Access Token**, not a password
  and not key-pair. The UI field is labeled *password*; the PAT goes in it.
- Google's connector exposes **no ROLE field** — hence `ROLE_RESTRICTION` on the PAT.
- Snowflake **supports only OAuth** for `EXTERNAL MCP SERVER`.
- Snowflake's pre-built MCP connectors are exactly **Atlassian, GitHub, Glean, Linear,
  Salesforce**. Meta is not among them; it requires a custom connector.
- `TYPE = OAUTH_DYNAMIC_CLIENT` takes only `OAUTH_RESOURCE_URL`, and
  `OAUTH_REFRESH_TOKEN_VALIDITY` **does not apply to DCR**.
- With `TYPE = OAUTH2`, `OAUTH_REFRESH_TOKEN_VALIDITY` defaults to `0`, which means a
  refresh token that **never expires**. Minimum settable value is 3600.
- `TYPE = SERVICE_AGENT` users can generate and use a PAT **without** being subject to a
  network policy. `TYPE = SERVICE` cannot, under default policy evaluation.
- `SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER <u>` is the correct form. **Executed live**
  — `SHOW PROGRAMMATIC ACCESS TOKENS` without the leading `USER` is a syntax error.
- `LOGIN_HISTORY_BY_USER` takes `RESULT_LIMIT`, not `TIME_LIMIT`. **Executed live** —
  `TIME_LIMIT` raises "invalid argument for function". The function also only covers the
  last 7 days.
- Snowflake documentation **does not mention Google Ads Data Manager anywhere**. Verified by
  absence via web search against docs.snowflake.com, not an exhaustive index scan.
- `npm install -g @meta/ads-cli` **does not exist** — `registry.npmjs.org/@meta/ads-cli`
  returns HTTP 404. Verified directly. Do not reinstate this command.
- **`USE ROLE` alone does not test least privilege.** **Executed live:** with
  `DEFAULT_SECONDARY_ROLES = ALL` on the operator, `ACCOUNTADMIN` and `ORGADMIN` stay active
  as secondary roles after `USE ROLE GOOGLE_ADS_DM_ROLE`, and `GET_DDL` on the secure view
  **succeeds**. With `USE SECONDARY ROLES NONE` it correctly fails. This is the defect that
  live execution caught; the verification section is worthless without it.
- **`CREATE USER` defaults `DEFAULT_SECONDARY_ROLES` to `[ALL]`.** **Executed live** — set it
  to `()` explicitly on any connector identity. Accepted inline for `TYPE = SERVICE_AGENT`.
- **`SERVICE_AGENT` + PAT with no network policy works.** **Executed live** — the PAT was
  created successfully and `SHOW USER PROGRAMMATIC ACCESS TOKENS` reports
  `mins_to_bypass_network_policy_requirement = None`. This is the guide's central
  operational claim and it holds.
- **`SECURE VIEW` does hide its DDL** from a role with only `USAGE` + `SELECT` — but only
  once secondary roles are dropped. Both halves of that sentence are load-bearing.
- **`external_mcp` API integration and `EXTERNAL MCP SERVER` create successfully** against
  the Meta URL, and `SYSTEM$START_USER_OAUTH_FLOW` returns a consent URL. **Executed live.**
  This proves the Snowflake plumbing only — no Meta contact happens at `CREATE` time.
- **`mcp.facebook.com` resolves via DNS** to `star.c10r.facebook.com`, a genuine Facebook
  host. The hostname is real. An HTTPS probe was blocked by corporate VPN egress, so the
  endpoint's actual response is still unverified — do not upgrade that claim on DNS alone.

## Two Documented Vendor Contradictions — Preserve Both Callouts

The guide deliberately flags conflicts inside Google's own documentation rather than picking
a side silently. Do not "correct" either back to the losing variant.

1. **PAT vs password.** Google's Requirements block says PAT; the collapsed step body on the
   same page still says password. The Requirements block is newer and authoritative.
2. **Hex vs Base64.** The Data Manager data-prep page specifies **hex**; the legacy
   manual-upload page labels its examples "Base64 Encoded". The Data Manager API rejects
   non-hex with `INVALID_HEX_ENCODING`. Hex wins for this path.

A third conflict is flagged unresolved: scheduling cadence is "daily" on two pages and
"daily, weekly, and ad hoc" on the confidential-matching FAQ.

## Known Gaps — Do Not Paper Over

These are stated as gaps in the guide on purpose. Fill them only with real verification.

- **Offline conversion / enhanced-conversion column names**, including the gclid column, sit
  inside a collapsed accordion in Google's help that is not machine-readable. Only
  `conversion_value` and the conversion time/date columns are confirmed.
- **Snowflake connector release status.** Google applies no GA/beta/allowlist label. GA is
  inferred from the absence of a beta tag that sibling features carry. Never write "GA" as
  though Google said it.
- **PrivateLink compatibility** is addressed by neither vendor. The guide says "probably
  incompatible" and labels it unverified. Keep the hedge until someone tests it.
- **Incremental vs full refresh** semantics per connector run are undocumented.
- **Meta's endpoint, tool list, scopes, rate limits, and CLI distribution channel** are all
  unverified. The README names the two exact Meta URLs a human should open to settle them.

## Conventions

- Snowflake identifiers in examples: `GOOGLE_ADS_DM_ROLE`, `GOOGLE_ADS_DM_SVC`,
  `SFE_ADS_ACTIVATION_WH`, database `MARKETING`, schema `ACTIVATION`, views
  `V_GOOGLE_CUSTOMER_MATCH` and `V_GOOGLE_CUSTOMER_MATCH_HASHED`, MCP server
  `MARKETING.ACTIVATION.meta_ads_mcp_server`, agent role `MARKETING_AGENT_ROLE`, and base
  table `MARKETING.CORE.CUSTOMER`. Keep these consistent across the README and both SQL
  files. `MARKETING.CORE.CUSTOMER` is the one identifier a reader is expected to replace;
  it is named in the Google file's PREREQUISITES for that reason.
- Identifiers in the SQL files are **hardcoded**, not driven by `SET`/`IDENTIFIER()`. An
  earlier revision parameterized only the `CREATE SCHEMA`, which silently split the schema
  from the views when a reader changed the variable. Do not reintroduce that indirection.
- Google's Customer Match headers contain spaces and **require double-quoted identifiers**
  in Snowflake. This is the single most likely thing for an editor to break — verify
  `"First Name"` style aliases survive any reformatting.
- Optional and fallback SQL sections are block-commented with a rationale line, so each file
  is safe to read top to bottom without accidentally running the wrong variant.
- Every `ACCOUNT_USAGE` query is bounded to a day window. Tune the window rather than
  dropping the bound.
- Placeholders use angle brackets: `<client_id>`, `<meta_token_endpoint>`,
  `<paste_previous_specification_here>`. Account identifiers in prose stay `<org>-<account>`
  to avoid the pre-commit account-name scanner.

## Maintenance

Expires **2026-11-28** (3 months — Meta's connector is in open beta, and the Google Data
Manager API migration is actively in flight).

Validated end-to-end on **2026-08-28** against `sfsenorthamerica-mwhitaker_aws` (Snowflake
v10.30.102), created and torn down in one session. Re-run that validation on any refresh —
the fixture is a synthetic `MARKETING.CORE.CUSTOMER` table with six rows chosen to exercise
the filters: one gmail address with dots, one googlemail address, one row at 539 days
(included), one at 600 days (excluded), one opt-out, and one NULL email. Expect 3 rows in
the view.

The Meta half rots fastest. On any refresh, do these three things first:

1. Open both Meta documentation URLs in a real browser and resolve the five unverified items
   (endpoint, tool list, scopes, rate limits, CLI install).
2. Re-check whether Meta appears in Snowflake's **pre-built** MCP connector list. If it
   does, Path A collapses to a few UI steps and Section 2 of the Meta SQL file should be
   rewritten around the supported-connector flow.
3. Re-check whether the Google Ads API Customer Match sunset has acquired **official dates**.
   Trade-press dates are deliberately excluded — the guide says the direction is confirmed
   but the calendar is not. Only add dates sourced from a Google help page.

Also worth re-checking: whether Snowflake has published anything at all about Google Ads
Data Manager. The current answer is no, which the guide names as a content gap.

Paths: this guide is in Path 1 (connect an external tool). Both the root `AGENTS.md` member
list and both `README.md` tables must stay in sync.

## Key Commands

```bash
# Register Meta's MCP server with Cortex Code (Path B — try this before Path A).
# ENDPOINT UNVERIFIED — confirm it in a browser against Meta's docs first.
cortex mcp add meta-ads https://mcp.facebook.com/ads --type http

# Enumerate the real tool names after connecting, to replace the guessed
# permission patterns in sql/meta_ads_mcp_setup.sql Section 1
cortex mcp list

# Confirm SHA2 hex behavior still holds (the one live-verified SQL claim)
snow sql -c <connection> -q \
  "SELECT SHA2('test@example.com', 256) AS hex, LENGTH(SHA2('x', 256)) AS len;"
```

Verification of the DDL in either SQL file needs **ACCOUNTADMIN** — `CREATE INTEGRATION`,
`CREATE USER`, and `CREATE ROLE` are account-level privileges. Note that a compile-only
check is useless for these statements: Snowflake raises the authorization error **before**
validating syntax, so `only_compile` on `CREATE API INTEGRATION` tells you nothing about
whether the statement is well-formed. Statements that need no privileges (`SHOW USER
PROGRAMMATIC ACCESS TOKENS`, `LOGIN_HISTORY_BY_USER`, `SHA2`) *can* be verified live, and
the two syntax fixes listed above were found exactly that way — prefer live execution over
compile checks wherever privileges allow it.
