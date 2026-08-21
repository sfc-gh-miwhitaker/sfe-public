![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2027--02--20-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Cube as a Semantic Layer on Snowflake

How Cube connects to Snowflake, how to authenticate it without long-lived secrets, how its
pre-aggregation cache interacts with your warehouse spend, and how the bi-directional
Snowflake Semantic Views sync actually behaves — including what it refuses to sync.

**Audience:** Data platform engineers and architects evaluating or operating Cube on top of
Snowflake, and Snowflake administrators who need to grant, attribute, and audit Cube's access.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-20 | **Expires:** 2027-02-20 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

Cube is a **decoupled semantic layer**. Snowflake remains storage and compute; Cube sits above
it holding metric definitions, compiles incoming queries into Snowflake SQL, and pushes them
down. No extracts — your data never leaves Snowflake.

That much is uncontroversial. The decisions that actually matter are narrower:

1. **How does Cube authenticate?** Three options, and only one avoids long-lived secrets.
2. **What privileges does it need?** Less than most people grant.
3. **Where does the warehouse cost go?** Pre-aggregations are the whole conversation.
4. **Can you keep Cube and Snowflake semantic views in sync?** Partially — and the gaps are
   specific and knowable.
5. **Should you add Cube at all?** For a single-warehouse Snowflake shop, often no.

Every SQL statement and privilege claim in this guide was executed against a live Snowflake
account, not transcribed from vendor documentation. Where Snowflake's own docs contradict
observed behavior, this guide documents the behavior and flags the conflict.

---

## Architecture

```
                        ┌──────────────────────────────────┐
                        │   Snowflake                      │
                        │   storage + compute + RBAC       │
                        └───────────────┬──────────────────┘
                                        │  SQL pushdown
                                        │  (Node.js driver, HTTPS)
                        ┌───────────────┴──────────────────┐
                        │   Cube semantic layer            │
                        │   metrics · joins · access rules │
                        └───────────────┬──────────────────┘
                                        │
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        │               │               │               │               │
   SQL API         REST API        GraphQL            MDX             DAX
 (Postgres wire)  (embedded)      (embedded)        (Excel)       (Power BI)
        │               │               │               │               │
      BI tools      applications    applications    spreadsheets    Power BI

                        ┌──────────────────────────────────┐
                        │   Cube Store                     │
                        │   pre-aggregation cache          │
                        │   absorbs repeat query traffic    │
                        └──────────────────────────────────┘
```

The fan-out is the point. One metric definition serves BI, embedded apps, Excel, and Power BI
without reimplementing logic per tool. Access rules — row, column, and user level — are defined
once in the semantic layer and apply across every consumer.

---

## Connection Layer

Cube treats Snowflake as a data source via `@cubejs-backend/snowflake-driver`. Minimum viable
configuration:

```bash
CUBEJS_DB_TYPE=snowflake
CUBEJS_DB_SNOWFLAKE_ACCOUNT=<org>-<account>
CUBEJS_DB_SNOWFLAKE_WAREHOUSE=CUBE_WH
CUBEJS_DB_SNOWFLAKE_ROLE=CUBE_ROLE
CUBEJS_DB_NAME=ANALYTICS
```

### Three authentication paths

Set via `CUBEJS_DB_SNOWFLAKE_AUTHENTICATOR`:

| Value | Mechanism | Required companions | Verdict |
|---|---|---|---|
| `SNOWFLAKE` (default) | Username + password | `CUBEJS_DB_USER`, `CUBEJS_DB_PASS` | **Avoid.** Snowflake is actively deprecating single-factor password auth for service connections. |
| `SNOWFLAKE_JWT` | RSA key pair | `CUBEJS_DB_SNOWFLAKE_PRIVATE_KEY` or `_PRIVATE_KEY_PATH`; `_PRIVATE_KEY_PASS` if encrypted | **Default choice for Cube Core / self-hosted.** A secret still exists, but it rotates cleanly. |
| `OAUTH` | External OAuth, incl. Cube Cloud OIDC workload identity | `CUBEJS_DB_SNOWFLAKE_OAUTH_TOKEN_PATH` (auto-populated in Cube Cloud) | **Best posture if you're on Cube Cloud.** No long-lived secret provisioned or rotated. |

Omit `CUBEJS_DB_USER` and `CUBEJS_DB_PASS` entirely for both `SNOWFLAKE_JWT` and `OAUTH`.

### OIDC workload identity (Cube Cloud)

This is the cleanest option and worth the setup cost. A Snowflake External OAuth integration
trusts Cube's OIDC issuer; the driver presents a short-lived Cube-minted JWT. Snowflake validates
each token against your Cube tenant's public JWKS endpoint — **no key material ever changes
hands.**

Full DDL is in [`sql/external_oauth_setup.sql`](sql/external_oauth_setup.sql). The shape:

```sql
CREATE SECURITY INTEGRATION CUBE_CLOUD_EXTERNAL_OAUTH
  TYPE = EXTERNAL_OAUTH
  ENABLED = TRUE
  EXTERNAL_OAUTH_TYPE = CUSTOM
  EXTERNAL_OAUTH_ISSUER = 'https://<tenant-name>.cubecloud.dev'
  EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://<tenant-name>.cubecloud.dev/.well-known/jwks.json'
  EXTERNAL_OAUTH_AUDIENCE_LIST = ('https://<account-identifier>.snowflakecomputing.com')
  EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'sub'
  EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME'
  EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE';
```

On the Cube side, create an OIDC token config with audience type **Custom**, custom audience set
to your Snowflake account URL, a custom claim `scp` = `session:role-any`, and target env var
`CUBEJS_DB_SNOWFLAKE_OAUTH_TOKEN_PATH`.

Then the service user, whose `LOGIN_NAME` must match the token's rendered `sub` claim:

```sql
CREATE USER CUBE_SVC
  TYPE = SERVICE
  LOGIN_NAME = 'cube:deployment:<deployment-id>'
  DEFAULT_ROLE = CUBE_ROLE
  DEFAULT_WAREHOUSE = CUBE_WH;
```

`TYPE = SERVICE` is a hard guarantee, not a convention. Attempting to set a password on such a
user fails outright:

```
511503 (23001): SQL execution error:
Cannot set PASSWORD on users with TYPE=SERVICE.
```

The user can *only* authenticate through the federation.

### Network policies on External OAuth integrations — docs conflict

`NETWORK_POLICY` **is** accepted on an External OAuth security integration:

```sql
ALTER SECURITY INTEGRATION CUBE_CLOUD_EXTERNAL_OAUTH
  SET NETWORK_POLICY = 'CUBE_ALLOWED_IPS';
```

This was verified end to end — the policy applies and persists in `DESC SECURITY INTEGRATION`
output. Note that Snowflake's [custom authorization servers guide](https://docs.snowflake.com/en/user-guide/oauth-ext-custom)
currently states that *"network policies cannot be added to your External OAuth security
integration."* That statement is stale; the
[CREATE SECURITY INTEGRATION (External OAuth) reference](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-external)
correctly lists `NETWORK_POLICY` as a supported optional parameter. Trust the reference page.

If your Cube Cloud deployment has a stable egress address, pairing the integration with a network
policy is a meaningful additional control on top of the token validation.

---

## Privileges

Read-only access is sufficient to query. This is less than most teams grant by reflex:

```sql
GRANT USAGE  ON WAREHOUSE CUBE_WH                     TO ROLE CUBE_ROLE;
GRANT USAGE  ON DATABASE  ANALYTICS                   TO ROLE CUBE_ROLE;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE ANALYTICS  TO ROLE CUBE_ROLE;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE ANALYTICS  TO ROLE CUBE_ROLE;
GRANT SELECT ON ALL TABLES     IN DATABASE ANALYTICS  TO ROLE CUBE_ROLE;
GRANT SELECT ON FUTURE TABLES  IN DATABASE ANALYTICS  TO ROLE CUBE_ROLE;
```

Write access is needed in exactly one scenario: **pre-aggregations built inside Snowflake using
the default batching strategy**, which issues `CREATE TABLE` against the pre-aggregation schema.
The export bucket strategy stays read-only — it unloads via `COPY INTO` and needs only `USAGE` on
the storage integration.

If you push Cube views into Snowflake as semantic views, add:

```sql
GRANT CREATE SEMANTIC VIEW ON SCHEMA ANALYTICS.CUBE_SV TO ROLE CUBE_ROLE;
GRANT CREATE VIEW          ON SCHEMA ANALYTICS.CUBE_SV TO ROLE CUBE_ROLE;
```

Both are grantable at schema level (verified). `CREATE VIEW` is only required if any cube uses a
raw `sql` string — see [Push limitations](#push-limitations).

---

## Pre-Aggregations and Warehouse Cost

This is the section that matters most to a Snowflake bill.

Cube materializes rollups into **Cube Store**, its own columnar cache. Repeated dashboard queries
hit Cube Store instead of your warehouse. That is the primary reason Cube reduces Snowflake spend
in embedded and high-concurrency scenarios — and the primary reason a misconfigured Cube
deployment quietly *increases* it, by rebuilding rollups more often than anyone is watching.

### Two build strategies

| Strategy | Mechanism | Warehouse impact | Config |
|---|---|---|---|
| **Batching** (default) | Cube reads results through the driver, writes `CREATE TABLE` in the pre-agg schema | Needs write access; slower at volume | No extra config |
| **Export bucket** | Snowflake `COPY INTO` unloads to S3 / GCS / Azure; Cube Store reads the files | Read-only; much faster at volume | `CUBEJS_DB_EXPORT_BUCKET_TYPE` + `CUBEJS_DB_EXPORT_INTEGRATION` |

Export bucket is the right default for anything non-trivial. It unloads directly from the query
with no temporary tables.

```bash
CUBEJS_DB_EXPORT_BUCKET_TYPE=s3
CUBEJS_DB_EXPORT_BUCKET=my.bucket.on.s3
CUBEJS_DB_EXPORT_INTEGRATION=aws_int
CUBEJS_DB_EXPORT_BUCKET_AWS_REGION=us-east-1
```

Snowflake supports S3, Google Cloud Storage, and Azure Blob Storage as export buckets, each via a
Snowflake storage integration.

Measures of type `count_distinct_approx` are supported in pre-aggregations, backed by Snowflake's
`APPROX_COUNT_DISTINCT`.

### Tag the connection — this is not optional in practice

Without a query tag, Cube's traffic is indistinguishable from everything else in
`QUERY_HISTORY`, and you cannot attribute cost or diagnose a runaway rebuild. There is **no
environment variable** for this. You must supply a custom `driverFactory`:

```js
const SnowflakeDriver = require('@cubejs-backend/snowflake-driver');

module.exports = {
  driverFactory: () =>
    new SnowflakeDriver({
      queryTag: 'cube',
    }),
};
```

The tag is set once per connection, not per query — every query on that connection carries it.
Attribution queries are in [`sql/observability.sql`](sql/observability.sql).

---

## Bi-Directional Semantic Views Sync

Snowflake ships native semantic views; Cube added two-way sync against them. This is available
only on **Cube's Enterprise plan**.

- **Pull** — browse Snowflake semantic views from the Cube IDE and import them as generated cube
  and view definition files in your Cube repository.
- **Push** — Cube generates `CREATE SEMANTIC VIEW` DDL from your Cube view definitions and
  executes it in Snowflake via the SQL Runner.

### Push prerequisites

1. Enable DDL operations: Cube Cloud UI → Deployment Settings → Configuration → **Enable DDL
   operations**. Without this, the SQL Runner rejects the generated DDL.
2. The role in `CUBEJS_DB_SNOWFLAKE_ROLE` needs `CREATE SEMANTIC VIEW` on the target schema, plus
   `USAGE` on the parent database and schema.
3. If any cube uses a plain SQL string in its `sql` property, Cube creates a helper Snowflake view
   named `CUBE_SV_SRC_<CUBENAME>` in a configurable schema (defaults to `PUBLIC`) and uses it as
   the semantic view's source. That requires `CREATE VIEW` on that schema.
4. `CUBEJS_DB_SNOWFLAKE_QUOTED_IDENTIFIERS_IGNORE_CASE` must match how identifiers are defined in
   your Cube data model. Default is `false`.

For straightforward table access prefer `sql_table: MY_SCHEMA.MY_TABLE` over a `sql` string — it
avoids the helper view entirely.

### Push limitations

Cube's modeling layer is broader than what Snowflake semantic views express today. Views relying
on the following keep working in Cube but **cannot be pushed**; the push wizard flags them during
validation.

| Blocked pattern | Why |
|---|---|
| Templated `sql` (Jinja, dbt `{{ source(...) }}`) | Cube can't resolve the template into static DDL |
| No single-column `primary_key` | Composite keys and SQL-expression keys unsupported |
| Non-equi and expression joins (`LOWER(a.id) = b.id`, `OR`, inequalities) | Joins must be simple column equality |
| Joins not referencing the target cube's primary key | Snowflake requires referenced columns be a primary or unique key |
| Measures beyond `count`, `count_distinct`, `sum`, `avg`, `min`, `max` | Calculated measures, per-measure filters, and rolling windows have no direct equivalent |
| Segments, access policies, hierarchies, time-dimension granularities, view-level filters, pre-aggregations | Skipped silently during push |

That last row deserves emphasis: **access policies do not travel with the push.** If you rely on
Cube-defined row or user level security, the resulting Snowflake semantic view does not carry it.
Enforce equivalent controls with Snowflake row access and masking policies on the underlying
tables, which do propagate into semantic views.

---

## Should You Add Cube At All?

An honest decision table. Cube is real infrastructure with real operational cost.

| Reach for Cube when… | Stay Snowflake-native when… |
|---|---|
| Non-Snowflake consumers need governed metrics — Excel via MDX, Power BI via DAX, embedded apps via REST/GraphQL | Your consumers are BI tools plus Snowflake-native AI (Cortex Analyst, CoWork) |
| Multiple warehouses sit behind one metric layer (Snowflake + BigQuery + Databricks) | Snowflake is your only warehouse |
| High-concurrency embedded analytics where a pre-agg cache must absorb traffic your warehouse shouldn't see | Query volume is analyst-scale, not application-scale |
| You need modeling beyond semantic views — calculated measures, rolling windows, segments, hierarchies | Your metrics are basic aggregates over clean star schemas |
| You want a Postgres-wire SQL endpoint for tools that can't speak Snowflake | Your tools already have first-class Snowflake connectors |

For a single-warehouse Snowflake shop whose consumers are BI plus Snowflake-native AI, adding
Cube is net additional infrastructure to operate, secure, and pay for. The bi-directional sync is
what makes a hybrid tenable rather than duplicative: model once, and let each side hold the
metrics it can actually express.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `The role … is not listed in the Access Token or was filtered` | The `scp` custom claim is missing from the Cube token config, or the role isn't granted to the mapped user. **This is the most common failure** — Snowflake grants session roles exclusively through `scp`; a token without it authenticates fine and then fails role authorization. |
| `Invalid OAuth access token` | Issuer or audience mismatch between the Cube token config and the Snowflake security integration, or the JWKS URL is unreachable. Values are case-sensitive and must match exactly. |
| `User … not found` / mapping errors | The rendered `sub` doesn't match the Snowflake user's `LOGIN_NAME`. Compare against the live preview in Cube's token config dialog. |
| `File … provided by CUBEJS_DB_SNOWFLAKE_OAUTH_TOKEN_PATH does not exist` | Target Env Var isn't set on the token config, a stale hand-written path is configured, or the deployment is still starting. Never hand-write this path. |
| Network error / Snowflake unreachable | Try [format 2 account identifier](https://docs.snowflake.com/en/user-guide/admin-account-identifier#format-2-account-locator-in-a-region) (account locator + region). |
| Object exists in Snowflake but Cube reports it missing | `CUBEJS_DB_SNOWFLAKE_QUOTED_IDENTIFIERS_IGNORE_CASE` disagrees with your model's identifier casing. |
| Push fails with a permissions error | *Enable DDL operations* is off, or the role lacks `CREATE SEMANTIC VIEW` (and `CREATE VIEW` for helper views). |

### Confirming which auth path actually ran

Login history records the mechanism, and the value differs per path — check the one you expect:

| Auth path | `FIRST_AUTHENTICATION_FACTOR` |
|---|---|
| `SNOWFLAKE_JWT` (key pair) | `RSA_KEYPAIR` |
| `OAUTH` / OIDC workload identity | `OAUTH_ACCESS_TOKEN` |
| `SNOWFLAKE` (password) | `PASSWORD` |

```sql
SELECT event_timestamp, user_name, first_authentication_factor, is_success
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.LOGIN_HISTORY_BY_USER(USER_NAME => 'CUBE_SVC'))
ORDER BY event_timestamp DESC;
```

---

## Files

| File | Purpose |
|---|---|
| `README.md` | This guide |
| `ELI5.md` | Plain-language companion for non-technical stakeholders |
| `AGENTS.md` | Project instructions for AI coding assistants |
| `sql/external_oauth_setup.sql` | External OAuth integration, service user, role, and grants |
| `sql/observability.sql` | Login history, query-tag attribution, credit spend, pre-agg detection |

---

## Related Guides

- [Cube: Snowflake data source configuration](https://docs.cube.dev/admin/connect-to-data/data-sources/snowflake)
- [Cube: Snowflake Semantic Views integration](https://docs.cube.dev/docs/integrations/snowflake-semantic-views)
- [Cube: OIDC workload identity](https://docs.cube.dev/admin/deployment/oidc)
- [Snowflake: Key-pair authentication and rotation](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [Snowflake: Using SQL to create and manage semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/sql)
- [Snowflake: Best practices for developing and deploying semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)

---

## External References

- [CREATE SECURITY INTEGRATION (External OAuth)](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-external)
- [Configure custom authorization servers for External OAuth](https://docs.snowflake.com/en/user-guide/oauth-ext-custom)
- [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Snowflake account identifiers](https://docs.snowflake.com/en/user-guide/admin-account-identifier)
- [Snowflake storage integration for S3](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration)
- [Cube environment variables reference](https://docs.cube.dev/reference/configuration/environment-variables)
- [Cube pre-aggregation build strategies](https://docs.cube.dev/docs/pre-aggregations/using-pre-aggregations#pre-aggregation-build-strategies)
- [Cube Dev on Snowflake Partners](https://www.snowflake.com/en/why-snowflake/partners/all-partners/cube-dev-inc/)
