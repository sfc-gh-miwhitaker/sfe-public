![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--03--21-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex AI Access Control and Observability

Snowflake's Cortex AI surface — AI functions, Cortex Agents, Cortex Analyst, Cortex Search, CoWork, and Cortex Code (CoCo) across Desktop, CLI, and Snowsight — is enabled for **every user** in a new account by default. This guide is the single place to decide *who* gets *which* part of that surface, apply the grants, cap spend per user, verify the restriction actually holds, and monitor usage afterwards.

It covers four independent control planes that stack: **database roles** (which Cortex services), **account privileges** (which AI functions), **model application roles** (which LLMs), and **per-user credit limits** (how much).

**Audience:** Snowflake administrators (ACCOUNTADMIN or SECURITYADMIN) responsible for governing AI access and usage.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-19 | **Updated:** 2026-09-21 | **Expires:** 2027-03-21 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use. Every SQL claim was verified against Snowflake documentation on the updated date above.

---

## Start Here

| If you want to... | Jump to |
| --- | --- |
| Pick the right grant for a team | [Which Grant Do You Actually Want?](#which-grant-do-you-actually-want) |
| Understand what gates Cortex access | [How Access Works](#how-cortex-access-works) |
| Give a team AI functions but not Agents | [Narrowing With AI_FUNCTIONS_USER](#narrowing-with-ai_functions_user) |
| Restrict which specific functions a role can call | [Per-Function Privileges](#per-function-privileges) |
| Restrict which models a role can use | [Model RBAC](#model-rbac) |
| Lock the whole surface down to one role | [Lockdown Procedure](#lockdown-procedure) |
| Roll out gradually without breaking things | [Progressive Rollout](#progressive-rollout-for-the-paranoid) |
| Manage grants across dozens of roles | [Applying at Scale](#applying-at-scale) |
| Cap daily credit spend per user | [Spend Limits](#spend-limits-daily-credit-caps) |
| See who is using what today | [Observability Queries](#observability-queries) |
| Avoid the four ways a lockdown silently fails | [Gotchas](#gotchas-and-faq) |

Companion SQL lives in `sql/`:

| File | Contents |
| --- | --- |
| [`sql/ai_functions_user_rbac.sql`](sql/ai_functions_user_rbac.sql) | Audit queries, the narrowing and full-lockdown grant patterns, per-function control, the governance-table template, verification |
| [`sql/observability.sql`](sql/observability.sql) | The eleven usage queries summarized below |

---

## Which Grant Do You Actually Want?

Five mechanisms, five different jobs. Most accounts need two or three of them, not all five.

| Mechanism | Grants access to | Choose it when | Default state |
| --- | --- | --- | --- |
| `SNOWFLAKE.CORTEX_USER` (database role) | The full Cortex surface: all AI functions including the aggregate variants, Agents, Analyst, Search, CoWork, Cortex Code | A team needs Agents, Analyst, or Search — or you simply want the historical default behavior for a trusted role | Granted to `PUBLIC` |
| `SNOWFLAKE.AI_FUNCTIONS_USER` (database role) | Scalar AI functions only | A team needs `AI_COMPLETE`-style calls in SQL but has no business running Agents, building Search services, or using CoWork | Not granted — must be explicit |
| `SNOWFLAKE.CORTEX_AGENT_USER` (database role) | Cortex Agents only | You are exposing an agent to a business cohort that should not get the rest of Cortex | Not granted — must be explicit |
| `USE AI FUNCTION <name>` (account privilege) | One named AI function | A role needs `AI_CLASSIFY` but must not be able to call `AI_COMPLETE` at all | Superseded by blanket `USE AI FUNCTIONS` on `PUBLIC` |
| `SNOWFLAKE."CORTEX-MODEL-ROLE-*"` (application roles) | Specific LLMs | You want cheap models broadly available and frontier models restricted to a few teams | `CORTEX-MODEL-ROLE-ALL` bootstrapped to the `SNOWFLAKE.PUBLIC` application role |

Two things to internalize from that table:

- The database role and the account privilege are **both required** — they are not alternatives. See [the two-grant requirement](#the-two-grant-requirement).
- Model RBAC is **orthogonal** to all of it. A role with `CORTEX_USER` and no model grant can call `AI_COMPLETE` and still be refused every model.

---

## How Cortex Access Works

Three layers must ALL pass before a user can invoke any Cortex AI feature:

```text
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: a qualifying SNOWFLAKE database role                  │
│  CORTEX_USER (full surface) or a narrower one —                  │
│  AI_FUNCTIONS_USER (scalar functions) /                          │
│  CORTEX_AGENT_USER (Agents). CORTEX_USER is on PUBLIC.          │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: USE AI FUNCTIONS account privilege                    │
│  Gates AI function calls (AI_COMPLETE, AI_EXTRACT, etc.).       │
│  Granted to PUBLIC by default. Per-function variants exist.     │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Model RBAC (application roles)                        │
│  Controls which LLMs are available. CORTEX-MODEL-ROLE-ALL is    │
│  bootstrapped to the SNOWFLAKE.PUBLIC application role.         │
└─────────────────────────────────────────────────────────────────┘
```

**The single most impactful action:** revoking `SNOWFLAKE.CORTEX_USER` from `PUBLIC` removes Cortex AI — Cortex Code included — from every role that only inherited it through `PUBLIC`. It is necessary but **not sufficient** on its own; two inheritance paths survive it, both covered in [Gotchas](#gotchas-and-faq).

> `CORTEX_USER`, `AI_FUNCTIONS_USER`, and `CORTEX_AGENT_USER` are database roles on the shared `SNOWFLAKE` database. Database roles cannot be granted directly to users — they must be granted to account-level roles.

---

## Narrowing With AI_FUNCTIONS_USER

When a new business unit gets Snowflake access, it inherits the same AI capabilities as everyone else, because `CORTEX_USER` is granted to `PUBLIC` and `PUBLIC` is granted to every user. That default exists to make getting started easy, but it means every new user can immediately call `AI_COMPLETE`, run Cortex Agents, query through Cortex Analyst, and open CoWork.

`CORTEX_USER` is broad. It covers:

- All Cortex AI functions (`AI_COMPLETE`, `AI_CLASSIFY`, `AI_EXTRACT`, `AI_FILTER`, `AI_SENTIMENT`, `AI_EMBED`, `AI_PARSE_DOCUMENT`, `AI_REDACT`, `AI_TRANSLATE`, `AI_TRANSCRIBE`)
- Cortex Agents
- Cortex Analyst
- Cortex Search
- Snowflake CoWork
- Cortex Code

`AI_FUNCTIONS_USER` (GA April 2, 2026) enables the scalar AI functions and nothing else. It does **not** grant:

- Cortex Agents
- Cortex Analyst
- Cortex Search
- Cortex Fine-tuning
- Snowflake CoWork
- `AI_AGG` and `AI_SUMMARIZE_AGG` — the aggregate variants require `CORTEX_USER`

If a team needs AI functions in SQL but has no reason to run Agents or stand up Search services, `AI_FUNCTIONS_USER` is the correct scope and `CORTEX_USER` is over-granting.

### The two-grant requirement

A user needs **both** of these, not either:

1. The `USE AI FUNCTIONS` account-level privilege — **or** a per-function `USE AI FUNCTION <name>` privilege
2. A qualifying database role: `AI_FUNCTIONS_USER` or `CORTEX_USER`

The account privilege is on `PUBLIC` by default, so if you have not locked that down, granting the database role is the only change you need. Once you revoke the blanket privilege from `PUBLIC`, every role needs both grants explicitly. Granting one without the other produces an access error that reads as though the role has no Cortex access at all.

### The narrowing pattern

New BU gets AI functions; existing users unchanged:

```sql
USE ROLE ACCOUNTADMIN;

-- USE AI FUNCTIONS is still on PUBLIC, so the database role is the only change
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
```

Full lockdown — remove the broad default, then grant deliberately:

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: audit FIRST (see sql/ai_functions_user_rbac.sql), then remove the default
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- Step 2: full Cortex for roles that genuinely need Agents / Analyst / Search
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE trusted_data_eng_role;

-- Step 3: scalar AI functions only for everyone else
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE analyst_role;

-- Step 4: Agents only, no other Cortex surface
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE business_cohort_role;
```

The audit in step 1 is the load-bearing part. Workflows that depend on Agents or Analyst break the moment `CORTEX_USER` leaves `PUBLIC` without a replacement grant.

---

## Per-Function Privileges

If a role should reach `AI_COMPLETE` and `AI_CLASSIFY` but not the rest of the function surface, grant the functions individually.

```sql
USE ROLE ACCOUNTADMIN;

-- Required first: the blanket privilege overrides per-function grants while it exists
REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;

GRANT USE AI FUNCTION AI_COMPLETE ON ACCOUNT TO ROLE limited_bu_role;
GRANT USE AI FUNCTION AI_CLASSIFY ON ACCOUNT TO ROLE limited_bu_role;

-- Still need a qualifying database role
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE limited_bu_role;
```

> **The blanket privilege and the per-function privileges have an OR relationship.** A role holding `USE AI FUNCTIONS` can call every function regardless of which per-function grants exist. Per-function grants only restrict anything once the blanket privilege is gone from every path that role inherits. This is why the `REVOKE` above is a prerequisite, not an optional extra.

Restore blanket access for roles that should keep everything:

```sql
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE trusted_data_eng_role;
```

Per-function grants surface in `SHOW GRANTS ON ACCOUNT` — filter the output for privileges matching `USE AI FUNCTION%`.

---

## Model RBAC

`CORTEX_MODELS_ALLOWLIST` has been retired in phases. From August 5, 2026 the only permitted change was setting it to `'None'`. Since September 8, 2026 the 2026_07 behavior change bundle has removed allowlist-based authorization entirely, and full retirement lands November 18, 2026. **Model-level RBAC via application roles in `SNOWFLAKE.MODELS` is now the only mechanism**, and it is enforced for embedding models (`AI_EMBED`, `AI_SIMILARITY`, `EMBED_TEXT_768`, `EMBED_TEXT_1024`) and Cortex Search as well as for text generation.

```sql
USE ROLE ACCOUNTADMIN;

-- Refresh the model objects. This runs daily on its own; call it on demand when a
-- newly released model has not yet appeared as an application role.
CALL SNOWFLAKE.MODELS.CORTEX_BASE_MODELS_REFRESH();

-- Take exact role names from these two commands — the identifiers are quoted
-- and case-sensitive.
SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;
SHOW APPLICATION ROLES LIKE 'CORTEX-MODEL%' IN APPLICATION SNOWFLAKE;

-- Grant one model
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-<MODEL>" TO ROLE analyst_role;

-- Or all current and future models
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE data_eng_role;

-- Setting the allowlist to 'None' is the one transition still permitted, and it
-- is a no-op once the 2026_07 bundle is enabled in your account.
ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'None';
```

### Removing broad model access takes a stored procedure, not a REVOKE

Accounts whose allowlist was set to `'All'` received an automatic `CORTEX-MODEL-ROLE-ALL` bootstrap grant on the **`SNOWFLAKE.PUBLIC` application role** — which is a different object from the account-level `PUBLIC` role. A raw `REVOKE APPLICATION ROLE ... FROM ROLE PUBLIC` neither clears that bootstrap grant nor persists across upgrades. Use the procedure:

```sql
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
  'APP_ROLE',
  'CORTEX-MODEL-ROLE-ALL'
);
```

Audit the bootstrap state with:

```sql
SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;
```

Until that grant is gone, every model remains reachable by everyone and your per-model grants have no restrictive effect at all.

This layer gives per-role, per-model control — the usual reason to reach for it is restricting expensive frontier models to specific teams while leaving smaller models broadly available. Combine all three planes for complete coverage: who can call Cortex (database roles), which functions they can call (per-function privileges), and which models they can use (model RBAC).

---

## Lockdown Procedure

Run these as `ACCOUNTADMIN`. Each step is independent and reversible. This sequence locks the surface down to one role; substitute a narrower database role at step 3 if the role does not need all of Cortex.

### Step 1 — Revoke CORTEX_USER from PUBLIC

```sql
USE ROLE ACCOUNTADMIN;

REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
```

This removes Cortex access from every role whose only path to it was `PUBLIC`. Roles with an explicit grant, a secondary-role path, or `IMPORTED PRIVILEGES` retain it — see [Gotchas](#gotchas-and-faq).

### Step 2 — Create a dedicated role

```sql
CREATE ROLE IF NOT EXISTS CORTEX_AI_USER_RL
  COMMENT = 'Grants access to Cortex AI (all surfaces, including Cortex Code)';
```

### Step 3 — Grant the database role

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE CORTEX_AI_USER_RL;
```

Narrower alternatives: `SNOWFLAKE.AI_FUNCTIONS_USER` for scalar functions only, `SNOWFLAKE.CORTEX_AGENT_USER` for Agents only.

### Step 4 — Grant USE AI FUNCTIONS

```sql
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE CORTEX_AI_USER_RL;
```

Required if you also revoked `USE AI FUNCTIONS` from `PUBLIC` (a separate action). If you only revoked `CORTEX_USER`, this step is redundant because the privilege still flows through `PUBLIC` — but granting it explicitly makes the role self-sufficient and survives a later `PUBLIC` cleanup.

### Step 5 — Grant model access

```sql
-- Option A: all models
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE CORTEX_AI_USER_RL;

-- Option B: specific models only
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-<MODEL>" TO ROLE CORTEX_AI_USER_RL;
```

If you have not removed the `CORTEX-MODEL-ROLE-ALL` bootstrap from the `SNOWFLAKE.PUBLIC` application role, model access still reaches everyone regardless of what you grant here. See [Model RBAC](#model-rbac).

### Step 6 — Assign to users

```sql
GRANT ROLE CORTEX_AI_USER_RL TO USER <username>;
```

Or attach the database role to a functional role a group already uses:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ENGINEERING_RL;
```

### Step 7 — Verify as a non-admin

```sql
USE SECONDARY ROLES NONE;

USE ROLE CORTEX_AI_USER_RL;
SELECT AI_COMPLETE('<model_name>', 'Say hello');
-- Should succeed

USE ROLE PUBLIC;
SELECT AI_COMPLETE('<model_name>', 'Say hello');
-- Should fail with an access error
```

> **Verifying as ACCOUNTADMIN tells you nothing.** ACCOUNTADMIN always reaches every model and every Cortex service, and an inherited secondary role masks a missing grant. Always test as a non-ACCOUNTADMIN role with `USE SECONDARY ROLES NONE` in the session.

---

## Applying at Scale

Ad-hoc `GRANT` statements stop being auditable somewhere around the tenth role. Drive grants from a table instead, so the *intent* is queryable and reviewable separately from the grant state.

```sql
CREATE TABLE IF NOT EXISTS your_db.your_schema.cortex_access_grants (
    role_name     VARCHAR   NOT NULL,
    cortex_level  VARCHAR   NOT NULL,  -- CORTEX_USER | AI_FUNCTIONS_USER | CORTEX_AGENT_USER
    granted_by    VARCHAR,
    granted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    justification VARCHAR,
    PRIMARY KEY (role_name)
);
```

Generate the statements, review the output, then execute:

```sql
SELECT
    role_name,
    cortex_level,
    'GRANT DATABASE ROLE SNOWFLAKE.' || cortex_level
        || ' TO ROLE ' || role_name || ';' AS grant_statement
FROM your_db.your_schema.cortex_access_grants
WHERE cortex_level IN ('CORTEX_USER', 'AI_FUNCTIONS_USER', 'CORTEX_AGENT_USER')
ORDER BY cortex_level, role_name;
```

The table earns its keep at review time: it records *why* each role has the access it has, which no `SHOW GRANTS` output can tell you. Reconcile intent against reality periodically — rows in the table with no matching grant, and grants with no matching row, are both findings.

Plain SQL cannot execute generated DDL; wrap the loop in a stored procedure or a Snowpark script if you want this applied automatically. The full template is in [`sql/ai_functions_user_rbac.sql`](sql/ai_functions_user_rbac.sql).

---

## Progressive Rollout for the Paranoid

For administrators who want certainty before making changes.

### Phase 1 — Observe (7-14 days)

**Change nothing.** Run the observability queries to answer: who is already using Cortex, how many credits per day, which surfaces and models. This establishes a baseline and identifies the stakeholders you need to notify.

### Phase 2 — Pilot (7 days)

1. Create `CORTEX_AI_USER_RL` per the lockdown procedure.
2. Grant it to every user identified in Phase 1 — they should notice no change.
3. Revoke `CORTEX_USER` from `PUBLIC`.
4. Announce internally that Cortex now requires an explicit role grant, that current users are already granted, and how new users request access.
5. Monitor for 7 days, watching for support tickets and broken automation.

### Phase 3 — Steady state

1. Formalize onboarding (request form, manager approval, SCIM group mapping).
2. Set a Snowflake `ALERT` on the usage views to catch anomalies (query #9).
3. Review the unused-access query (#8) periodically to right-size grants.

### Rollback (any phase)

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;
```

---

## Spend Limits (Daily Credit Caps)

Independently of RBAC, Snowflake provides per-surface daily credit limits for Cortex Code. These are rolling 24-hour caps — when a user's estimated usage hits the limit, that surface blocks until usage rolls off.

### Parameters

| Parameter | Controls |
| --- | --- |
| `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo CLI |
| `CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo Desktop |
| `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo in Snowsight |

### How it works

| Value | Behavior |
| --- | --- |
| `-1` (default) | No limit |
| `0` | Blocked entirely |
| Positive number | Blocked when rolling 24-hour estimated usage exceeds this value |

User-level settings override account-level settings for that user.

### Pattern A — A default cap for everyone

```sql
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

### Pattern B — Block by default, allow specific users

```sql
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;

ALTER USER <power_user>  SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
ALTER USER <team_lead>   SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

### Pattern C — Unlimited for pilots, capped for everyone else

```sql
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 10;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 10;

ALTER USER <pilot_user> SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = -1;
ALTER USER <pilot_user> SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = -1;
```

### Removing limits

```sql
-- Account level (restores the unlimited default)
ALTER ACCOUNT UNSET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- User level (the account-level value applies instead)
ALTER USER <username> UNSET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;
```

### Spend limits vs RBAC

| Goal | Use |
| --- | --- |
| Completely block a surface for unauthorized users | RBAC (revoke `CORTEX_USER` from `PUBLIC`) |
| Allow access but prevent runaway spend | Spend limits |
| Block one CoCo surface but allow others | Spend limits (set `0` on the blocked surface) |
| Restrict who **and** cap how much | Both — RBAC for access, limits for guardrails |

> These are complementary, not alternatives. A user needs a qualifying database role **and** a non-zero credit limit to use a CoCo surface. For per-user AI credit caps beyond Cortex Code, look at `SNOWFLAKE.CORE.QUOTA`.

---

## Observability Queries

The full query set is in [`sql/observability.sql`](sql/observability.sql). What each answers:

| # | Question |
| --- | --- |
| 1 | Who is using Cortex Code today? (user, requests, credits, first/last seen) |
| 2 | Which surface is most popular? (CLI vs Desktop vs Snowsight) |
| 3 | What models are being consumed? (token breakdown per model) |
| 4 | Monthly credits per user (3-month trend) |
| 5 | Peak usage hours (hour-of-day distribution) |
| 6 | Top 10 heaviest users (last 30 days) |
| 7 | What roles are people using CoCo with? |
| 8 | Users with access who have NEVER used CoCo (unused access audit) |
| 9 | Daily credit trend (last 30 days — good for alerting) |
| 10 | New users in the last 7 days (adoption tracking) |
| 11 | Inference region distribution (regional vs global routing) |

All of them read `SNOWFLAKE.ACCOUNT_USAGE` views, which retain 365 days of history.

> **Tip:** `SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY` combines CLI, Desktop, and Snowsight into one view. Use it if available in your account; the queries in the SQL file use the individual views for maximum compatibility.

---

## Gotchas and FAQ

### Revoking CORTEX_USER from PUBLIC is not sufficient by itself

Two inheritance paths survive that revoke, and both are common. If you skip either one, you will conclude the lockdown worked when it did not.

**Path 1 — secondary roles.** A user whose *secondary* roles include a role with Cortex access still gets in, even when their primary role has none. Test with `USE SECONDARY ROLES NONE` before believing any result.

**Path 2 — `IMPORTED PRIVILEGES` on the SNOWFLAKE database.** A role granted `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` inherits **all** database roles in that database, `CORTEX_USER` included. Revoking `CORTEX_USER` from `PUBLIC` does not close this path. Find and fix it per role:

```sql
-- Which roles hold IMPORTED PRIVILEGES on the SNOWFLAKE database?
SHOW GRANTS ON DATABASE SNOWFLAKE;

-- Revoke only from roles that should not inherit CORTEX_USER through it
REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE <role_name>;
```

### Don't revoke IMPORTED PRIVILEGES from PUBLIC unless you mean it

You may see guidance to run `REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE PUBLIC`. Snowflake documents this as an **optional** companion to the `CORTEX_USER` revoke, not a required one. It removes `PUBLIC` access to **everything** in the shared `SNOWFLAKE` database — the `ACCOUNT_USAGE` views these observability queries depend on included. Don't run it unless you are prepared to re-grant `ACCOUNT_USAGE` access to every role that needs it. Fixing the specific roles that over-inherit, as above, is the targeted move.

### Always verify as a non-ACCOUNTADMIN role

ACCOUNTADMIN reaches every Cortex service and every model regardless of your grants. A test that passes as ACCOUNTADMIN proves nothing about whether a restriction holds. Use a real target role, with `USE SECONDARY ROLES NONE`.

### Model restrictions do nothing until the bootstrap grant is gone

`CORTEX-MODEL-ROLE-ALL` on the `SNOWFLAKE.PUBLIC` *application* role keeps every model reachable by everyone. A plain `REVOKE APPLICATION ROLE` does not clear it and does not persist across upgrades — use `CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE('APP_ROLE', 'CORTEX-MODEL-ROLE-ALL')` and audit with `SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC`.

### Per-function grants do nothing while the blanket privilege is inherited

`USE AI FUNCTIONS` and `USE AI FUNCTION <name>` are ORed. Until the blanket privilege is off every path the role inherits, your per-function grants are decorative.

### Default role matters for Cortex Agents

Cortex Agents evaluate permissions against the user's **default role**, not their active session role. If a user's default role lacks the qualifying database role, agent calls fail even after the user switches to a privileged role in-session. Either set the Cortex role as the user's default or grant the database role to the default role.

### Missing one of the two grants looks like having neither

A role with the database role but no `USE AI FUNCTIONS`, or the reverse, errors the same way as a role with no Cortex access at all. When debugging an access failure, check both layers plus the model grant before concluding the database role did not apply.

### View latency is per-view, not one number

There is no single ACCOUNT_USAGE latency figure. Each view documents its own — in practice ranging from tens of minutes to several hours, with `METERING_DAILY_HISTORY` among the slower ones. Check the specific view's documentation page rather than assuming a flat value, and don't design an alert around a latency you have not confirmed. `ORGANIZATION_USAGE` views are generally slower than their `ACCOUNT_USAGE` counterparts.

Practical consequence: after revoking access, confirm the change with a direct `AI_COMPLETE` call as the target role. Do not wait on a usage view to tell you whether the revoke landed.

---

## Related Guides

- [Privileges and model access for Cortex AI functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access) — the reference for `CORTEX_USER`, `AI_FUNCTIONS_USER`, `USE AI FUNCTIONS`, and model RBAC
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup) — agent-specific privileges and the default-role requirement
- [Using SNOWFLAKE database roles](https://docs.snowflake.com/en/sql-reference/snowflake-db) — why database roles cannot be granted directly to users
- [Snowflake behavior change bundles](https://docs.snowflake.com/en/release-notes/behavior-changes) — where the allowlist retirement timeline is tracked

---

## External References

- [Cortex AI privileges and model access](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access)
- [Access control privileges (`USE AI FUNCTIONS`)](https://docs.snowflake.com/en/user-guide/security-access-control-privileges)
- [`CORTEX_CODE_CLI_USAGE_HISTORY` view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_cli_usage_history)
- [`CORTEX_CODE_DESKTOP_USAGE_HISTORY` view](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/cortex-code-desktop-usage-history-view)
- [`CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_snowsight_usage_history)
- [ACCOUNT_USAGE schema (per-view latency and retention)](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Cortex Code administration](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
- [Per-user AI credit quotas (`SNOWFLAKE.CORE.QUOTA`)](https://docs.snowflake.com/en/user-guide/cost-controlling-quotas)

---

Pair-programmed by SE Community + Cortex Code
