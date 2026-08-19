![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--02--19-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex Code Access Control and Observability

Cortex Code (CoCo) — across Desktop, CLI, and Snowsight — is enabled for **every user** in a new Snowflake account by default. This guide shows an administrator how to restrict access to a specific role, roll it out progressively without surprises, and monitor ongoing usage with copy-paste SQL queries.

**Audience:** Snowflake administrators (ACCOUNTADMIN or SECURITYADMIN) responsible for governing AI tool usage.
**Created:** 2026-08-19 | **Expires:** 2027-02-19 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use. Every SQL claim was verified against Snowflake documentation on the created date above.

---

## Start Here

| If you want to... | Jump to |
|---|---|
| Understand what controls CoCo access | [How Access Works](#how-cortex-code-access-works) |
| Lock it down to one role right now | [Lockdown Procedure](#lockdown-procedure) |
| Roll out gradually without breaking things | [Progressive Rollout](#progressive-rollout-for-the-paranoid) |
| Cap daily credit spend per user | [Spend Limits](#spend-limits-daily-credit-caps) |
| See who is using CoCo today | [Observability Queries](#observability-queries) |
| Avoid common mistakes | [Gotchas](#gotchas-and-faq) |

---

## How Cortex Code Access Works

Three layers must ALL pass for a user to invoke Cortex Code:

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: CORTEX_USER database role                             │
│  Gates access to ALL Cortex AI features (CoCo, Agents,         │
│  Analyst, Search, Fine-tuning). Granted to PUBLIC by default.   │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: USE AI FUNCTIONS account privilege                    │
│  Gates AI function calls (AI_COMPLETE, AI_EXTRACT, etc.).       │
│  Granted to PUBLIC by default.                                  │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Model RBAC (application roles)                        │
│  Controls which LLMs are available. CORTEX-MODEL-ROLE-ALL is    │
│  bootstrapped to SNOWFLAKE.PUBLIC → PUBLIC by default.          │
└─────────────────────────────────────────────────────────────────┘
```

**The single most impactful action:** revoking `SNOWFLAKE.CORTEX_USER` from `PUBLIC` disables Cortex Code (and all Cortex AI) for anyone without an explicit grant.

> Important: `CORTEX_USER` is a database role on the `SNOWFLAKE` database. Database roles cannot be granted directly to users — they must be granted to account-level roles.

---

## Lockdown Procedure

Run these statements as `ACCOUNTADMIN`. Each step is independent and reversible.

### Step 1 — Revoke CORTEX_USER from PUBLIC

```sql
USE ROLE ACCOUNTADMIN;

REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
```

This immediately removes Cortex Code access from every role that inherited it through PUBLIC. Users with an explicit grant elsewhere retain access.

### Step 2 — Create a dedicated role

```sql
CREATE ROLE IF NOT EXISTS CORTEX_CODE_USER_RL
  COMMENT = 'Grants access to Cortex Code (all surfaces)';
```

### Step 3 — Grant the required database role

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE CORTEX_CODE_USER_RL;
```

### Step 4 — Grant USE AI FUNCTIONS

```sql
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE CORTEX_CODE_USER_RL;
```

If you also revoked `USE AI FUNCTIONS` from PUBLIC (optional, separate action), this step is required. If you only revoked `CORTEX_USER`, this step is unnecessary because `USE AI FUNCTIONS` still flows through PUBLIC.

### Step 5 — Grant model access

```sql
-- Option A: All models (simplest)
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE CORTEX_CODE_USER_RL;

-- Option B: Specific models only
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-CLAUDE-4-SONNET" TO ROLE CORTEX_CODE_USER_RL;
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-LLAMA3.1-70B" TO ROLE CORTEX_CODE_USER_RL;
```

If you did NOT revoke the CORTEX-MODEL-ROLE-ALL bootstrap from SNOWFLAKE.PUBLIC, model access still flows to everyone via PUBLIC. To restrict models:

```sql
-- Remove the bootstrap grant (use the stored procedure, not plain REVOKE)
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
  'APP_ROLE',
  'CORTEX-MODEL-ROLE-ALL'
);
```

### Step 6 — Assign to users

```sql
GRANT ROLE CORTEX_CODE_USER_RL TO USER alice;
GRANT ROLE CORTEX_CODE_USER_RL TO USER bob;
```

Or grant to an existing role that a group already uses:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ENGINEERING_RL;
```

### Step 7 — Verify

Switch to a test user or role and confirm:

```sql
USE ROLE CORTEX_CODE_USER_RL;
SELECT AI_COMPLETE('llama3.1-70b', 'Say hello');
-- Should succeed

USE ROLE PUBLIC;
SELECT AI_COMPLETE('llama3.1-70b', 'Say hello');
-- Should fail with access denied
```

---

## Progressive Rollout for the Paranoid

For administrators who want certainty before making changes.

### Phase 1 — Observe (7-14 days)

**Change nothing.** Run the observability queries below to answer:
- Who is already using Cortex Code?
- How many credits per day?
- Which surfaces and models?

This establishes a baseline and identifies stakeholders you need to notify.

### Phase 2 — Pilot (7 days)

1. Create `CORTEX_CODE_USER_RL` per the lockdown procedure above.
2. Grant it to every user identified in Phase 1 (they should notice no change).
3. Revoke `CORTEX_USER` from PUBLIC.
4. Announce internally: "Cortex Code now requires an explicit role grant. Current users are already granted. New users request access via [your process]."
5. Monitor for 7 days — watch for support tickets or broken automation.

### Phase 3 — Steady State

1. Formalize onboarding (request form, manager approval, SCIM group mapping, etc.).
2. Set up a Snowflake ALERT on the usage views to catch anomalies (see query #9 below).
3. Periodically review the "unused access" query (#8) to right-size grants.

### Rollback (any phase)

One command restores the original state:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;
```

---

## Spend Limits (Daily Credit Caps)

Independently from RBAC, Snowflake provides per-surface daily credit limits. These are rolling 24-hour caps — when a user's estimated usage hits the limit, that surface blocks until usage rolls off.

### Parameters

| Parameter | Controls |
|---|---|
| `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo CLI |
| `CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo Desktop |
| `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER` | CoCo in Snowsight |

### How it works

| Value | Behavior |
|---|---|
| `-1` (default) | No limit — unlimited access |
| `0` | Blocked entirely |
| Positive number | Blocked when rolling 24-hour estimated usage exceeds this value |

User-level settings override account-level settings for that user.

### Pattern A — Set a default cap for everyone

```sql
USE ROLE ACCOUNTADMIN;

-- 20 credits/day/user across all surfaces
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

### Pattern B — Block by default, allow specific users

```sql
USE ROLE ACCOUNTADMIN;

-- Block Desktop for everyone
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;

-- Allow specific users with a per-user override
ALTER USER power_user SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
ALTER USER team_lead  SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

### Pattern C — Unlimited for pilots, capped for everyone else

```sql
USE ROLE ACCOUNTADMIN;

-- Conservative default
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 10;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 10;

-- Pilot users get unlimited
ALTER USER pilot_user_1 SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = -1;
ALTER USER pilot_user_1 SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = -1;
```

### Removing limits

```sql
-- Remove account-level limit (restores default unlimited)
ALTER ACCOUNT UNSET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- Remove user-level override (account-level applies instead)
ALTER USER jsmith UNSET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;
```

### Spend limits vs RBAC — when to use which

| Goal | Use |
|---|---|
| Completely block CoCo for unauthorized users | RBAC (revoke CORTEX_USER from PUBLIC) |
| Allow access but prevent runaway spend | Spend limits |
| Block one surface but allow others | Spend limits (set 0 on the blocked surface) |
| Both restrict who AND cap how much | Combine both — RBAC for access, limits for guardrails |

> Note: Spend limits are a complementary mechanism to RBAC. A user needs **both** a qualifying database role AND a non-zero credit limit to use a surface.

---

## Observability Queries

All queries use `SNOWFLAKE.ACCOUNT_USAGE` views (up to 1-hour latency, 365-day retention).

The full query set is in [`sql/observability.sql`](sql/observability.sql). Below is a summary of what each query answers:

| # | Question |
|---|---|
| 1 | Who is using Cortex Code today? (user, requests, credits, first/last seen) |
| 2 | Which surface is most popular? (CLI vs Desktop vs Snowsight) |
| 3 | What models are being consumed? (token breakdown per model) |
| 4 | Monthly credits per user (3-month trend) |
| 5 | Peak usage hours (hour-of-day distribution) |
| 6 | Top 10 heaviest users (last 30 days) |
| 7 | What roles are people using CoCo with? |
| 8 | Users with access who have NEVER used CoCo (unused license audit) |
| 9 | Daily credit trend (last 30 days — good for alerting) |
| 10 | New users in the last 7 days (adoption tracking) |
| 11 | Inference region distribution (regional vs global routing) |

> **Tip:** `SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY` combines CLI, Desktop, and Snowsight into a single view. If available in your account, use it instead of UNION ALL across the three individual views. The queries in the SQL file use the individual views for maximum compatibility.

---

## Gotchas and FAQ

### Secondary roles bypass restrictions

A user with `ACCOUNTADMIN` as a **secondary role** can still access Cortex Code even if their primary role lacks `CORTEX_USER`. To test restrictions accurately:

```sql
USE SECONDARY ROLES NONE;
USE ROLE <role_to_test>;
SELECT AI_COMPLETE('llama3.1-70b', 'test');
```

### Default role matters for Cortex Agents

Cortex Agents evaluate permissions against the user's **default role**, not their active session role. If a user's default role lacks CORTEX_USER, agent calls fail — even if the user switches to a privileged role in their session. Ensure the CoCo role is either set as users' default role or granted to it.

### Don't revoke IMPORTED PRIVILEGES on SNOWFLAKE unless you mean it

You may see guidance elsewhere to run `REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE PUBLIC`. This removes PUBLIC access to **everything** in the shared SNOWFLAKE database — including the ACCOUNT_USAGE views these observability queries depend on. Revoking `CORTEX_USER` from PUBLIC is sufficient to block CoCo; don't revoke IMPORTED PRIVILEGES unless you're prepared to selectively re-grant ACCOUNT_USAGE access to every role that needs it.

### View latency

- ACCOUNT_USAGE views: up to **1 hour** latency
- ORGANIZATION_USAGE views: up to **24 hours** latency
- Retention: **365 days** for both

Don't expect real-time visibility. If you just revoked access and want to confirm it worked, test with a direct `AI_COMPLETE` call rather than waiting for the usage views to update.

### CORTEX_AGENT_USER is narrower than CORTEX_USER

If your goal is to only allow Cortex **Agents** (not CoCo, not AI functions), use `SNOWFLAKE.CORTEX_AGENT_USER` instead of `SNOWFLAKE.CORTEX_USER`. This grants access to agents only.

### Model RBAC revocation requires a stored procedure

A plain `REVOKE APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" FROM ROLE PUBLIC` does NOT remove the **bootstrap grant** from `SNOWFLAKE.PUBLIC`. You must use:

```sql
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
  'APP_ROLE',
  'CORTEX-MODEL-ROLE-ALL'
);
```

Verify with: `SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;`

---

## Related Guides

- [Privileges and model access for Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access) — full reference for CORTEX_USER, USE AI FUNCTIONS, model RBAC
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup) — agent-specific privileges and default role requirements
- [CORTEX_CODE_CLI_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_cli_usage_history) — column reference
- [CORTEX_CODE_DESKTOP_USAGE_HISTORY view](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/cortex-code-desktop-usage-history-view) — column reference
- [CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_snowsight_usage_history) — column reference
- [Using SNOWFLAKE database roles](https://docs.snowflake.com/en/sql-reference/snowflake-db) — why database roles can't be granted directly to users
