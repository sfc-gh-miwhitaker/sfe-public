# guide-ad-platform-integrations — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Repo-wide guide format standards live in the root
     AGENTS.md. Do not duplicate either here. -->

## Scope

Reference guide on moving advertising data between Snowflake and the Google/Meta ad platforms.
Two mechanisms, split by direction:

1. **Google Ads Data Manager** (outbound, Snowflake → Google Ads) — a Google product with
   Snowflake as a supported source connector. Customer Match and offline conversions.
2. **Meta ads MCP and the Meta Conversions API skill** (the pairing announced Jul 2026) — the
   CAPI skill is outbound (Snowflake → Meta, conversion events) and public on GitHub; the MCP is
   inbound (Meta → Snowflake, campaign data) and available by request only.
3. **Openflow connectors for Meta Ads and Google Ads** (inbound, ad platform → Snowflake) —
   Snowflake products that run on Openflow. **Distinct from the Meta ads MCP.**
4. **Snowflake → Meta audience-list activation** (outbound, brokered) — no native path for
   *lists* (events are covered by the CAPI skill), closed via the Data Clean Rooms Meta Ads
   Manager activation connector, a marketplace partner, or Meta's Marketing API directly.

The organizing idea is **direction determines mechanism**, and the two directions have very
different prerequisites. Preserve that framing. The most common reader error is assuming the
two are symmetric.

No deploy script. Both `sql/` files are copy/paste references requiring ACCOUNTADMIN.

## Tone: Facts, Not Position

**This guide states what the products are and what they require. It does not advise whether to
adopt them.** Established 2026-08-28 after a draft leaned toward gating Openflow adoption
behind a recommendation framework.

Concretely, do NOT add:
- Adoption screens, readiness criteria, or go/no-go frameworks
- Internal telemetry: support-case sentiment ratios, escalation rates, credit consumption
  patterns, cost-shock figures
- Customer names, Gong call references, Jira/case IDs, Salesforce records
- Comparative positioning against third-party ETL tools, in either direction
- Any framing implying Openflow is a good or bad choice

**Do** state prerequisites plainly and completely, validate them where possible, and let the
reader draw the conclusion. "Openflow is required, here are the three privileges, here is the
networking, here is what's GA and what's Preview" is the right register.

The prerequisite comparison table in the README is factual and belongs. It compares object
counts and setup steps without editorializing.

## Provenance Tiers

| Tier | Meaning | How to re-verify |
|---|---|---|
| **Verified** | Official Snowflake/Google docs, or executed live | Re-fetch, or re-execute |
| **Unverified** | In one vendor's docs but not confirmable elsewhere, or documented inconsistently | Called out inline |

**Executed live against a Snowflake account (v10.30.102) on 2026-08-28, then dropped:** all of
Part 1 end to end, plus the Part 3 prerequisites (three Openflow privileges, both network rules,
both EAIs). **Not executed:** the Openflow deployment, runtime, and connector flow — the
validation account had no Openflow deployment. Keep that boundary explicit; do not let the
Part 3 setup steps read as observed behavior.

## Verified Facts — Do Not Regress These

Confirmed by execution or primary documentation:

**Part 1 — Google Ads Data Manager**
- Authenticates with a **Programmatic Access Token**, not a password and not key-pair. The UI
  field is labeled *password*; the PAT goes in it.
- The connector exposes **no ROLE field** — hence `ROLE_RESTRICTION` on the PAT.
- `SHA2(col, 256)` returns **lowercase 64-character hex**. **Executed live.** This is why the
  pre-hash variant uses `SHA2`, not `BASE64_ENCODE`.
- `TYPE = SERVICE_AGENT` can generate and use a PAT **without** a network policy. **Executed
  live** — `mins_to_bypass_network_policy_requirement` reads `None`.
- **`USE ROLE` alone does not test least privilege.** **Executed live:** with secondary roles at
  `ALL`, `ACCOUNTADMIN` stays active and `GET_DDL` on the secure view **succeeds**. With
  `USE SECONDARY ROLES NONE` it correctly fails.
- `CREATE USER` defaults `DEFAULT_SECONDARY_ROLES` to `[ALL]`. **Executed live** — set `()`
  explicitly on connector identities. Accepted inline for `TYPE = SERVICE_AGENT`.
- `SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER <u>` is correct. **Executed live** — omitting
  the leading `USER` is a syntax error.
- `LOGIN_HISTORY_BY_USER` takes `RESULT_LIMIT`, not `TIME_LIMIT`. **Executed live.** Covers only
  the last 7 days.
- Snowflake documentation **does not mention Google Ads Data Manager anywhere.**

**Snowflake → Meta activation**
- **Snowflake Data Clean Rooms ships a Meta Ads Manager activation connector**, alongside a Google
  Ads one. Configured under Connectors » Activation with the `MANAGE_DCR_CONNECTORS` role.
- **Third-party activation is UI only** — not available via custom templates; the support matrix
  says "UI only" for both provider-run and consumer-run. **Only the Audience Overlap &
  Segmentation template supports it.**
- **The connector is documented on the LEGACY Provider/Consumer clean rooms, which are being
  discontinued:** 2026-10-01 no new legacy clean rooms via web UI; 2027-02-01 web UI inaccessible;
  2027-06-01 legacy clean rooms inaccessible. Migration target is the Collaboration API. Because
  third-party activation is UI-only and the UI is what sunsets, the guide tells readers to confirm
  how Meta activation is delivered under the Collaboration API. **Keep that caveat** — it is the
  single most perishable fact in the guide.
- Third-party connectors are **not offered by Snowflake**. DCR **does not support data subject
  consent management.**
- Hashing responsibility **flips** between the Google and Meta routes. Google Ads Data Manager
  hashes for you; on the Meta side the DCR connector asks which columns hold which identifier
  types, and partners describe reformatting as part of their service. The guide says to confirm
  per route rather than assuming either.

**Part 2 — Meta ads MCP and Conversions API skill**

Added 2026-08-28 after a Snowflake internal slide and the July 2026 blog identified the product a
customer means by "that Meta MCP." This is **not** the Openflow Meta Ads connector. Part 2 was
retargeted and Openflow moved to Part 3. Do not merge them back together.

- **The pairing is two separate halves with different access models.** The **Meta Conversions API
  skill** is a public CoCo skill on GitHub, self-serve. The **Meta ads MCP** is **not self-serve** —
  the blog says to contact Snowflake for access. Never present both as equally available.
- Repo: `https://github.com/Snowflake-Labs/sf-samples/tree/main/samples/meta-capi-pipeline`.
  Install: `/skill add https://github.com/Snowflake-Labs/sf-samples.git/samples/meta-capi-pipeline`.
  Both the repo tree and the blog were **fetched live and returned 200** on 2026-08-28.
- Blog: `https://www.snowflake.com/en/blog/snowflake-meta-campaigns-governed-conversion-signals/`,
  Jul 21, 2026. Authors: Erin Foxworthy, Florian Delval, Luke Ambrosetti, Varun Kumar, Morgan Davy.
- Skill prerequisites, quoted from the repo's own `SKILL.md`/`README.md`: **`ACCOUNTADMIN` or
  `CREATE INTEGRATION`**, Meta Pixel ID from Events Manager, Meta access token with
  **`ads_management`**, a warehouse. The repo also states use of CAPI is governed by the
  customer's own agreements with Meta.
- Objects created: `META_CAPI_DB.PIPELINE` schema, `META_CAPI_EVENTS`, `META_CAPI_LOG`,
  `META_CAPI_CONFIG`, `send_to_meta_capi` UDTF, `meta_capi_integration` EAI. Egress list is
  `graph.facebook.com:443` **and** `api.facebook.com:443` — two hosts, unlike Openflow's one.
- Two rules the skill declares non-negotiable: **SHA256 PII hashing is mandatory** before egress,
  and **discovery has three mandatory human stops** (table selection → `event_id` + custom fields
  → final approval). Do not describe it as a one-shot script.
- `META_CAPI_EVENTS` uses a **VARIANT** schema (`USER_DATA`, `CUSTOM_DATA`), so new Meta fields
  need no table DDL — only a mapping-view change.
- **This skill is not audience activation.** It sends conversion *events*. The audience-list gap
  is still real. Keep that distinction — an earlier draft claimed "no native first-party path" for
  all Snowflake→Meta traffic, which the CAPI skill falsifies for events but not for lists.
- Nothing in Part 2 has been executed live. It is sourced from the repo, the blog, and the slide.

**Part 3 — Openflow**
- **Openflow — Snowflake Deployments is Generally Available** (AWS, Azure, GCP commercial), runs
  on SPCS. **Openflow — BYOC is AWS commercial only.** The Meta Ads and Google Ads *connectors*
  are **Preview**. Do not collapse the platform status into the connector status, or vice versa.
- Exactly **three** account privileges: `CREATE OPENFLOW DATA PLANE INTEGRATION`,
  `CREATE OPENFLOW RUNTIME INTEGRATION`, `CREATE COMPUTE POOL`. **All three executed live**
  against a non-ACCOUNTADMIN role and confirmed in `SHOW GRANTS`.
- `CREATE COMPUTE POOL` is documented on the **Core Snowflake** page, not the deployment page.
- Endpoints: **`graph.facebook.com`** (Meta Ads), **`googleads.googleapis.com`** (Google Ads).
  Egress network rule + EAI both **executed live**; `SHOW NETWORK RULES` reports
  `MODE = EGRESS`, `TYPE = HOST_PORT`.
- **A user with `DEFAULT_ROLE = ACCOUNTADMIN` cannot log in to an Openflow runtime.**
- **Snowflake recommends `DEFAULT_SECONDARY_ROLES = ('ALL')` for Openflow users** — the reverse
  of the Part 1 hardening. Both are correct in context; the guide explains why. Do not
  "fix" either to match the other.
- Execute-as roles are linked to Openflow session tokens, **removing the need for a separate
  service user and key pair** on Snowflake Deployments. `KEY_PAIR` is the BYOC path.
- **No separate charge for a deployment; only active runtimes consume credits.**
- Openflow — Snowflake Deployment is **not automatically available in trial accounts.**
  PrivateLink requires **Business Critical Edition.**

## Two Documented Vendor Contradictions — Preserve Both Callouts

The guide flags conflicts inside Google's own documentation rather than silently picking a side.

1. **PAT vs password.** Google's Requirements block says PAT; the collapsed step body on the same
   page says password. The Requirements block is newer and authoritative.
2. **Hex vs Base64.** The Data Manager data-prep page specifies **hex**; the legacy manual-upload
   page says "Base64 Encoded". The Data Manager API rejects non-hex with `INVALID_HEX_ENCODING`.
   Hex wins for this path.

A third is flagged unresolved: scheduling cadence is "daily" on two pages, "daily, weekly, and
ad hoc" on the confidential-matching FAQ.

## Known Gaps — Do Not Paper Over

- **Meta Marketing API version.** The connector docs list `v22.0` for `Meta Ads Version`. Meta
  retires versions on its own schedule. The guide says to confirm the currently supported version
  with Snowflake. State it that way — do not assert the docs are stale, and do not cite internal
  engineering findings.
- **Offline conversion / enhanced-conversion column names**, including gclid, sit in a collapsed
  accordion in Google's help that is not machine-readable. Only `conversion_value` and the
  conversion time/date columns are confirmed.
- **Google's Snowflake connector release status.** Google applies no GA/beta label. Never write
  "GA" as though Google said it.
- **PrivateLink for Data Manager** is addressed by neither vendor. The hedge stays.
- **Incremental vs full refresh** semantics per Data Manager run are undocumented.

## Conventions

- Part 1 identifiers: `GOOGLE_ADS_DM_ROLE`, `GOOGLE_ADS_DM_SVC`, `SFE_ADS_ACTIVATION_WH`,
  database `MARKETING`, schema `ACTIVATION`, views `V_GOOGLE_CUSTOMER_MATCH` and
  `V_GOOGLE_CUSTOMER_MATCH_HASHED`, base table `MARKETING.CORE.CUSTOMER`. The base table is the
  one identifier a reader must replace; it is named in PREREQUISITES for that reason.
- Part 3 identifiers: `OPENFLOW_ADMIN`, `OPENFLOW_MONITOR`, `OPENFLOW_CONFIG.NETWORKING`,
  `META_ADS_EGRESS`, `GOOGLE_ADS_EGRESS`, `META_ADS_EAI`, `GOOGLE_ADS_EAI`,
  `META_ADS_DESTINATION_DB`, `GOOGLE_ADS_DESTINATION_DB`.
- Google's Customer Match headers contain spaces and **require double-quoted identifiers** in
  Snowflake. Most likely thing for an editor to break — verify `"First Name"` style aliases
  survive any reformatting.
- Part 1 SQL uses hardcoded identifiers, not `SET`/`IDENTIFIER()`. An earlier revision
  parameterized only the `CREATE SCHEMA`, which silently split the schema from the views. Do not
  reintroduce it.
- Optional and teardown sections are block-commented with a rationale line so each file reads
  top to bottom safely.
- Every `ACCOUNT_USAGE` query is day-bounded. Tune the window rather than dropping the bound.
- Placeholders use angle brackets: `<connector_role>`, `<openflow_user>`,
  `<dataplane_integration_name>`. Account identifiers in prose stay `<org>-<account>` for the
  pre-commit scanner.

## Maintenance

Expires **2026-11-28** (3 months — the connectors are Preview and the Google Data Manager API
migration is in flight).

Validated **2026-08-28** against a demo account (Snowflake v10.30.102), created and torn down in
one session. Re-run on refresh. The Part 1 fixture is a synthetic `MARKETING.CORE.CUSTOMER` with
six rows chosen to exercise the filters: a gmail address with dots, a googlemail address, one row
at 539 days (included), one at 600 (excluded), one opt-out, one NULL email. Expect 3 rows.

On any refresh, check these first:

1. **Connector status.** Have the Meta Ads / Google Ads connectors moved from Preview to GA? The
   status split between platform (GA) and connectors (Preview) is the most load-bearing fact in
   Part 3.
2. **The Meta Ads Version allowed value.** Still `v22.0` in the docs, or updated?
3. **Gen2 connectors.** Snowflake has been reworking connector configuration, starting with
   Postgres and MySQL. If Meta Ads or Google Ads gets that treatment, the parameter tables in
   Part 3 and Section 7 of the SQL file need rewriting.
4. **Google Ads API Customer Match sunset dates.** Trade-press dates are deliberately excluded.
   Only add dates sourced from a Google help page.
5. Whether Snowflake has published anything about Google Ads Data Manager. Currently nothing.
6. **The DCR legacy sunset.** Re-check whether the Meta Ads Manager activation connector exists
   under the Collaboration API, and whether third-party activation is still UI-only. The first
   sunset date (2026-10-01) falls inside this guide's validity window.
7. **Marketplace listings.** Re-run `skill(command="marketplace-search")` before touching that
   section — listings and global names change. Never edit a listing's title, provider, or
   description from memory; every claim must come from search output. All listings must carry
   their `https://app.snowflake.com/marketplace/listing/<global_name>` URL.
8. **Meta ads MCP availability.** Currently request-only with no public docs page. If Snowflake
   publishes a docs page or self-serve enablement, Part 2's "the MCP half is gated" section and
   the routing table row both change.
9. **The CAPI skill repo.** It is an actively developed sample — the last commit touched AI-based
   event type discovery. Re-read `SKILL.md` and `README.md` before quoting prerequisites or the
   object list; both have already changed once since the initial commit.

Paths: Path 1 (connect an external tool). Both the root `AGENTS.md` member list and both
`README.md` tables must stay in sync.

## Key Commands

```bash
# Confirm SHA2 hex behavior (the load-bearing Part 1 claim)
snow sql -c <connection> -q \
  "SELECT SHA2('test@example.com', 256) AS hex, LENGTH(SHA2('x', 256)) AS len;"

# Confirm the three Openflow privileges still grant as documented
snow sql -c <connection> --role ACCOUNTADMIN -q \
  "SHOW GRANTS TO ROLE OPENFLOW_ADMIN;"

# Check whether an account has any Openflow deployment at all
snow sql -c <connection> --role ACCOUNTADMIN -q \
  "SHOW OPENFLOW DATA PLANE INTEGRATIONS;"
```

Verification needs **ACCOUNTADMIN** — `CREATE ROLE`, `CREATE USER`, and the Openflow grants are
account-level. Note that compile-only checks are useless for privileged DDL: Snowflake raises the
authorization error **before** validating syntax, so `only_compile` on `CREATE API INTEGRATION`
tells you nothing about whether the statement is well-formed. Prefer live execution wherever
privileges allow — the two Part 1 syntax errors were found exactly that way.
