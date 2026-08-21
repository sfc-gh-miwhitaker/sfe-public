# guide-cube-snowflake-semantic-layer — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Repo-wide guide format standards live in the root
     AGENTS.md. Do not duplicate either here. -->

## Scope

Reference guide on operating Cube (cube.dev) as a decoupled semantic layer on top of
Snowflake. Covers connection and authentication, privileges, pre-aggregation cost
behavior, the bi-directional Snowflake Semantic Views sync, and a build-vs-skip
decision framework.

No deploy script. The `sql/` files are copy/paste references, not an automated
deployment — `external_oauth_setup.sql` requires ACCOUNTADMIN and depends on a Cube
Cloud OIDC token config existing first.

## Two-Sided Fact Problem

This guide documents an integration between two independently versioned products.
Claims fall into three buckets, and each is verified differently:

| Claim type | Source of truth | How to re-verify |
|---|---|---|
| Snowflake DDL, privileges, `QUERY_TYPE` values, `ACCOUNT_USAGE` columns | The live account | Execute it. Do not trust docs alone. |
| Cube env vars, plan gating, push limitations | `docs.cube.dev` | Re-fetch the page; Cube ships fast and this list moves. |
| Behavior at the seam (what push actually generates) | Live test of both | Requires a Cube Enterprise deployment. |

When Snowflake's own docs disagree with observed behavior, **document the behavior and
flag the conflict inline.** The guide already does this for `NETWORK_POLICY` on External
OAuth integrations — the user-guide page says it's unsupported, the SQL reference says it
is, and a live test confirms the reference. Preserve that callout on updates; do not
"correct" it back to match the stale page.

## Verified Facts — Do Not Regress These

Established by execution against a live Snowflake account, not transcription:

- `TYPE = SERVICE` users hard-reject passwords: `511503 (23001) Cannot set PASSWORD on
  users with TYPE=SERVICE.`
- `NETWORK_POLICY` **is** accepted on `TYPE = EXTERNAL_OAUTH` integrations and persists
  in `DESC SECURITY INTEGRATION`.
- `EXTERNAL_OAUTH_SCOPE_MAPPING_ATTRIBUTE` defaults to `scp`.
- `CREATE SEMANTIC VIEW` and `CREATE VIEW` are both grantable at schema level.
- `FIRST_AUTHENTICATION_FACTOR` differs per auth path: `RSA_KEYPAIR` for key pair,
  `OAUTH_ACCESS_TOKEN` for OAuth/OIDC, `PASSWORD` for password. Key pair does **not**
  report as `SNOWFLAKE_JWT`.
- `CREATE_SEMANTIC_VIEW` is a distinct `QUERY_TYPE` in `ACCOUNT_USAGE.QUERY_HISTORY`.
  Never match pre-aggregation builds with `query_type LIKE 'CREATE%'` — it captures
  semantic-view pushes and helper views, mislabeling schema changes as data refreshes.

## Conventions

- Snowflake identifiers in examples: `CUBE_WH`, `CUBE_ROLE`, `CUBE_SVC`, `ANALYTICS`,
  schemas `CUBE_SV` and `CUBE_PRE_AGGREGATIONS`. Keep these consistent across README
  and both SQL files.
- Optional SQL sections are block-commented with a rationale line explaining when to
  enable them, so the file is safe to run top to bottom.
- Every `ACCOUNT_USAGE` query in `observability.sql` is bounded to a day window
  (7, 14, or 30 days depending on the question). Tune the window rather than dropping
  the bound — these run against accounts with millions of rows in `QUERY_HISTORY`.
- Placeholders use angle brackets: `<tenant-name>`, `<account-identifier>`,
  `<deployment-id>`. Account identifiers in prose must stay `<org>-<account>` to avoid
  the pre-commit account-name scanner.

## Maintenance

Expires **2027-02-20** (6 months; connector/auth guide per repo rule).

The Semantic Views sync section rots fastest — it is Cube Enterprise-gated and Cube's
docs state they are actively expanding coverage as Snowflake semantic views evolve.
Re-check the push limitation table before the guide's expiry even if nothing else
changed, and re-run `sql/observability.sql` against a live account to confirm
`ACCOUNT_USAGE` column names and `QUERY_TYPE` values still hold.

Paths: this guide is in Path 1 (connect an external tool) and Path 5 (new capabilities).
Both root `AGENTS.md` member lists and both `README.md` tables must stay in sync.

## Key Commands

```bash
# Run a single observability query
snow sql -c <connection> --role ACCOUNTADMIN -q "<query from sql/observability.sql>"

# Confirm which auth path a Cube service user actually used
snow sql -c <connection> --role ACCOUNTADMIN -q \
  "SELECT event_timestamp, first_authentication_factor, is_success
     FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.LOGIN_HISTORY_BY_USER(USER_NAME => 'CUBE_SVC'))
     ORDER BY event_timestamp DESC LIMIT 10;"
```

`snow sql` has no dry-run or parse-only flag — do not add one to these instructions.
To validate DDL without creating anything, either use the Cortex Code SQL tool with
`only_compile`, or create the objects with a scoped test prefix and drop them in the
same session. Note that a compile-only check passes on authorization errors before
parameter names are validated, so it is a weaker signal than an actual create.

Verification work needs ACCOUNTADMIN (`CREATE INTEGRATION` and `CREATE USER` are
account-level privileges).
