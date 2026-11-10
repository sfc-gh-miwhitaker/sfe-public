![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--01--09-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Network Policies from Login History for the Strong Authentication Deadline

Snowflake is removing single-factor password sign-in: human users need MFA, and service users cannot use passwords at all. The most common replacement for a password service account is a programmatic access token (PAT), and by default a service user can only generate and use a PAT while a network policy applies to it. This guide turns the sign-in history you already have into one reviewed network policy per service user, then migrates each user off its password in an order that surfaces mistakes before they cause an outage.

**Audience:** Snowflake account administrators working through the Strong Authentication Hub.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-10 | **Last verified:** 2026-11-10 | **Expires:** 2027-01-09 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

Decide per service user first. The network policy is the answer for the PAT row and good hygiene for every other row.

| The job is... | Use | Network policy |
| --- | --- | --- |
| Running in AWS, Azure, or GCP, or able to present an OIDC token | Workload identity federation | Recommended, not required |
| A driver or tool that supports key pair (most Snowflake drivers, many ETL tools) | Key pair | Recommended, not required |
| A tool or REST client that can only send a secret string where a password went | PAT | **Required by default** for TYPE=SERVICE |
| A BI tool connecting on behalf of people | OAuth (Snowflake or External) | Policy on the security integration |
| Actually a person | MFA or SSO; not this guide | Optional |

Then follow the scripts in order. Each one opens with what it does and runs as-is.

| Step | Script | Changes your account? |
| --- | --- | --- |
| 1. Find who is at risk | [`sql/01_find_at_risk_users.sql`](sql/01_find_at_risk_users.sql) | No |
| 2. Inventory each user's client IPs | [`sql/02_inventory_ips_per_user.sql`](sql/02_inventory_ips_per_user.sql) | No |
| 3. Draft rules and policies, plus advisor calls | [`sql/03_recommend_and_generate.sql`](sql/03_recommend_and_generate.sql) | No, returns SQL text |
| 4. Rehearse on a practice user | [`sql/00_practice_service_user.sql`](sql/00_practice_service_user.sql) | Creates practice objects only |
| 5. Dry run, attach, migrate one user | [`sql/04_evaluate_attach_migrate.sql`](sql/04_evaluate_attach_migrate.sql) | Yes, one user at a time |
| 6. Monitor | [`sql/05_monitor.sql`](sql/05_monitor.sql) | No |
| Clean up the rehearsal | [`sql/99_teardown.sql`](sql/99_teardown.sql) | Removes practice objects only |

Prefer plain language? Read [ELI5.md](ELI5.md).

## Before You Start

- **Know your date.** Open **Governance & security » Trust Center » Overview** and select **View hub** in the Strong authentication tile. The hub lists at-risk users, shows your account's enforcement dates, and lets an administrator with MODIFY on the account extend them. Viewing it needs the `SNOWFLAKE.TRUST_CENTER_ADMIN` or `TRUST_CENTER_VIEWER` application role (ACCOUNTADMIN has it).
- **What changes when.** Per the [deprecation plan](https://docs.snowflake.com/en/user-guide/security-mfa-rollout), the final phase rolls out per account from August 2026: human users cannot sign in with a password alone, password sign-in is blocked for every non-human user, and `LEGACY_SERVICE` users are converted to `SERVICE`. The previous phase (May to July 2026, per account) already made `LEGACY_SERVICE` unavailable for new or altered users. Dates vary by account and can be extended where migrations need more time.
- **Roles.** The read-only scripts need ACCOUNTADMIN, or a role with the `SNOWFLAKE.SECURITY_VIEWER` and `GOVERNANCE_VIEWER` database roles. Creating network policies and running the advisor needs SECURITYADMIN or higher.
- **Data lag.** `ACCOUNT_USAGE.LOGIN_HISTORY` lags up to 2 hours and keeps 1 year. The advisor reads ingress history, which lags up to 4 hours.
- **Pick a lookback that covers your slowest job.** The scripts default to 90 days. A quarterly extract needs more; the maximum is 365.
- **Keep a way back in.** Make sure at least one administrator signs in with SSO or MFA from a known network before you change any account-level policy. Only Snowflake Support can grant a user a temporary network-policy bypass.

## How it fits together

```text
LOGIN_HISTORY (who signed in, from where, how)
      │
      ├── 01 at-risk users ──> which accounts need a decision
      ├── 02 IP inventory  ──> STABLE / STALE / ONE_OFF / FAILED_ONLY per address
      └── 03 draft DDL     ──> one network rule + one policy per service user
                 │
                 ├── RECOMMEND_NETWORK_POLICY      (native advisor, CIDR merge)
                 └── EVALUATE_CANDIDATE_NETWORK_POLICY  (dry run, nothing enforced)
                                  │
04 attach to the user ──> canary ──> PAT or key pair ──> TYPE=SERVICE ──> verify
                                  │
                              05 monitor: blocked sign-ins, expiring tokens
```

A **network rule** holds addresses. A **network policy** lists which rules are allowed or blocked. Nothing is restricted until the policy is attached to the account, a user, or a security integration. A user-level policy **replaces** the account-level policy for that user; it does not add to it.

## Step 1: Find who is at risk

Run [`sql/01_find_at_risk_users.sql`](sql/01_find_at_risk_users.sql). It returns:

1. **Every user needing a decision**, with a recommended action: `LEGACY_SERVICE` users to migrate, `SERVICE` users with no credential and no network policy (a PAT cannot be issued to them yet), and human password users without MFA.
2. **Password sign-ins in the last 90 days** by user and client type. Rows where `SECOND_AUTHENTICATION_FACTOR` is NULL break on enforcement day.
3. **Untyped users that never use Snowsight.** A user whose `TYPE` was never set is treated as a person, so enforcement demands MFA from it. When it signs in only from drivers, it is almost always a service account. Set `TYPE` first; it decides which path the user takes.
4. **Network policies already in force**, account and user level.

The values Snowflake records in `FIRST_AUTHENTICATION_FACTOR` include `PASSWORD`, `RSA_KEYPAIR`, `PROGRAMMATIC_ACCESS_TOKEN`, `OAUTH_ACCESS_TOKEN`, and `WORKLOAD_IDENTITY`. Use them to confirm a migration later.

## Step 2: Inventory each user's client IPs

Run [`sql/02_inventory_ips_per_user.sql`](sql/02_inventory_ips_per_user.sql). By default it covers every `SERVICE` and `LEGACY_SERVICE` user. To include the untyped accounts from Step 1, change `user_types` to `'SERVICE,LEGACY_SERVICE,NULL'`.

Each address gets a review flag:

| Flag | Meaning | Usual decision |
| --- | --- | --- |
| `STABLE` | Seen on 3 or more days, most recently within 30 | Keep |
| `REVIEW` | Seen on 2 days, recently | Ask the job owner |
| `ONE_OFF` | Seen on a single day | Usually a laptop or a test; leave out |
| `STALE` | Not seen in 30 days | Confirm the job or host still exists |
| `FAILED_ONLY` | Never succeeded | Never allowlist without an owner's answer |

The script also rolls IPv4 addresses up to `/24`. Several addresses inside one `/24` usually mean a cloud NAT pool or a vendor's egress range. For any SaaS, BI, or ETL vendor, use the range the vendor publishes rather than the addresses you happened to observe; observed addresses change without notice. The third result lists failed sign-ins by IP and error so a broken job and credential stuffing do not get mixed up.

Snowsight worksheets and Snowpark Container Services sessions are recorded with the client IP `0.0.0.0`. The scripts drop it. Never put it in a network rule.

## Step 3: Draft rules and policies

Run [`sql/03_recommend_and_generate.sql`](sql/03_recommend_and_generate.sql). It creates nothing. It returns three grids:

1. **Draft DDL**, one statement per row: a `CREATE NETWORK RULE` per user and address family built from `STABLE` and `REVIEW` addresses only, and a `CREATE NETWORK POLICY` per user. Copy the `STATEMENT` column into a new worksheet, edit it with what you learned in Step 2, then run it. The default rule location is `SECURITY.NETWORK_RULES`; change `rule_schema` to put rules in your own governance schema.
2. **Users that need a human decision**: users signing in over private connectivity, and users with no stable address.
3. **Native advisor and dry-run calls**, one per user, ready to run.

### The native advisor

`SNOWFLAKE.NETWORK_SECURITY.RECOMMEND_NETWORK_POLICY` reads successful ingress for a lookback window (optionally one user), merges addresses into CIDR blocks, and returns SQL text. It never changes your account. Treat it as a second opinion next to the draft from grid 1:

- **It allowlists every address with any successful sign-in.** In testing it proposed six addresses for a user where only one was `STABLE`; the others were one-off and stale. Review before running.
- **Its output always uses the same names**, `RECOMMENDED_INGRESS_NETWORK_RULE` and `RECOMMENDED_INGRESS_NETWORK_POLICY`, with `CREATE OR REPLACE`. Run it unchanged for a second user and you overwrite the first. Rename both objects every time.
- **The rule name is not schema-qualified**, so it lands in whatever schema your worksheet is using.
- It returns IPv4 rules only and stops with an error above 1,000 CIDR blocks. Script 03 drafts IPv6 rules when IPv6 addresses appear.

## Step 4: Rehearse on a practice user

Run [`sql/00_practice_service_user.sql`](sql/00_practice_service_user.sql). It creates a `TYPE=SERVICE` user with no password, one role, a network rule holding only the address you are connected from (`CURRENT_IP_ADDRESS()`), and a policy that is created but not attached. Then run [`sql/04_evaluate_attach_migrate.sql`](sql/04_evaluate_attach_migrate.sql) unchanged: its defaults point at the practice objects, so Run All walks every step end to end and issues a real 90-day PAT you can throw away. Remove it all with [`sql/99_teardown.sql`](sql/99_teardown.sql).

## Step 5: Dry run, attach, and migrate one user

Change the three `SET` lines in script 04 to your user, its job role, and its policy, then run **one step at a time**.

| Step | What you run | Why this order |
| --- | --- | --- |
| A. Inspect | `DESCRIBE USER`, `DESCRIBE NETWORK POLICY` | If the user already has a policy, you are replacing it: merge its rules first |
| B. Dry run | `EVALUATE_CANDIDATE_NETWORK_POLICY(POLICY_NAME, LOOKBACK_DAYS, USER_NAME)` | Every row with `IS_ALLOWED = 'NO'` is a real past sign-in that would have failed. Resolve each one |
| C. Attach | `ALTER USER ... SET NETWORK_POLICY` | Affects only this user. The password still works, now only from allowlisted addresses |
| D. Canary | failed sign-ins for this user since attach | Wait one full job cycle. A miss here costs a retry, not an outage, because you have not changed the credential yet |
| E. Credential | `ALTER USER ... ADD PROGRAMMATIC ACCESS TOKEN ... ROLE_RESTRICTION ... DAYS_TO_EXPIRY` or set `RSA_PUBLIC_KEY` | A PAT for a service user needs the policy from C and, by default, a role restriction. The secret appears once; store it in the job's secret manager |
| F. Cut over | update the job, confirm it runs, then `SET TYPE = SERVICE` and `UNSET PASSWORD` | `SERVICE` users cannot sign in with a password. There is no way back to `LEGACY_SERVICE` once it can no longer be set |
| G. Verify | newest successful sign-ins for the user | `FIRST_AUTHENTICATION_FACTOR` should read `PROGRAMMATIC_ACCESS_TOKEN` or `RSA_KEYPAIR`, never `PASSWORD` |

Rollback statements for C and E are at the bottom of the script.

### An account-level policy, if you want one

Do it after every service user has its own policy, because a user-level policy replaces the account policy for that user. Build it from Step 2 for human users (office and VPN egress), then dry-run it for the whole account with `EVALUATE_CANDIDATE_NETWORK_POLICY(POLICY_NAME => '...')` and confirm your own administrator address is allowed before `ALTER ACCOUNT SET NETWORK_POLICY`. Undo it with `ALTER ACCOUNT UNSET NETWORK_POLICY`.

## Step 6: Monitor

Run [`sql/05_monitor.sql`](sql/05_monitor.sql) weekly. It returns:

1. **Rejected sign-ins in the last 7 days.** `ERROR_CODE` 390422 (`INCOMING_REQUEST_BLOCKED`) is a network-policy block; a new address for a known job usually means its host or vendor range changed.
2. **PATs expiring within 14 days.** The default expiry is 15 days and the maximum is 365. An expired token fails as surely as a blocked address, so rotate early with `ALTER USER ... ROTATE PROGRAMMATIC ACCESS TOKEN`.
3. **Service users with no network policy at all.**

To automate it, wrap query 1 in a [Snowflake alert](https://docs.snowflake.com/en/user-guide/alerts) that fires when a 390422 row appears for a service user.

## Gotchas

- **Snowflake OAuth ignores user-level policies on token requests.** Only the integration-level and account-level policies apply, so restrict BI tools on the security integration.
- **Private connectivity wins.** If a request arrives over private connectivity and the policy allows an `AWSVPCEID` or `AZURELINKID` rule, IPv4 and IPv6 rules are ignored for it. Script 03 flags users that sign in this way.
- **Snowpark Container Services** with customer-provided credentials is evaluated only against `COMPUTE_POOL` rules. IPv4 rules never apply to it.
- **An empty policy blocks everything.** Per the docs, creating an empty network policy allows no IPv4 address at all. Script 03 never drafts an empty rule.
- **A rule in use cannot be replaced.** `CREATE OR REPLACE NETWORK RULE` fails with 098509 while a policy references the rule. Change it with `ALTER NETWORK RULE ... SET VALUE_LIST`.
- **Blocked always beats allowed.** An address in both lists is blocked.
- **The auth policy can relax the PAT requirement** (`PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED)`). That removes the guardrail this guide relies on; prefer a real policy.
- **Internal stages on AWS** are covered by network rules only after `ENFORCE_NETWORK_RULES_FOR_INTERNAL_STAGES` is enabled.
- **IP addresses appear as `0.0.0.0`** for Snowsight and Snowpark Container Services sessions. Filter them out of every inventory.

## Related Guides

- [Strong Authentication Hub](https://docs.snowflake.com/en/user-guide/strong-authentication-hub)
- [Planning for the deprecation of single-factor password sign-ins](https://docs.snowflake.com/en/user-guide/security-mfa-rollout)
- [Network policy advisor](https://docs.snowflake.com/en/user-guide/network-policy-advisor)
- [Using programmatic access tokens for authentication](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [Workload identity federation](https://docs.snowflake.com/en/user-guide/workload-identity-federation)
- [Key-pair authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)

## External References

- [Controlling network traffic with network policies](https://docs.snowflake.com/en/user-guide/network-policies)
- [RECOMMEND_NETWORK_POLICY](https://docs.snowflake.com/en/sql-reference/stored-procedures/recommend_network_policy)
- [EVALUATE_CANDIDATE_NETWORK_POLICY](https://docs.snowflake.com/en/sql-reference/stored-procedures/evaluate_candidate_network_policy)
- [LOGIN_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/login_history)
- [INGRESS_NETWORK_ACCESS_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/ingress_network_access_history)
- [CREDENTIALS view](https://docs.snowflake.com/en/sql-reference/account-usage/credentials)
- [ALTER AUTHENTICATION POLICY (PAT_POLICY)](https://docs.snowflake.com/en/sql-reference/sql/alter-authentication-policy)
