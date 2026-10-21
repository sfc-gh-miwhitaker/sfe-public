![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--12--20-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Replicate a Snowflake Account from AWS to Azure

The shortest supported path to get a whole Snowflake account (databases, users, roles, warehouses, integrations, network policies, and account parameters) running as a live replica in an Azure region. You use one failover group and one client-redirect connection, refreshed every 10 minutes, and can make Azure the primary whenever you choose. The same steps work for disaster recovery (keep AWS primary) and for migration (cut over, then retire AWS).

**Audience:** Snowflake account administrators and organization administrators.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-10-21 | **Last verified:** 2026-10-21 | **Expires:** 2026-12-20 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

**Five scripts, four of them copy-and-run.** Cross-cloud replication uses the same commands as cross-region replication; nothing is AWS-to-Azure-specific until you fix up integrations afterward.

| # | Where | Who | Script | What it does |
| --- | --- | --- | --- | --- |
| 1 | AWS source | ACCOUNTADMIN | [`01_preflight.sql`](sql/01_preflight.sql) | Read-only: edition, Azure regions, existing groups, generated database list, objects that won't replicate |
| 2 | Org admin | ORGADMIN / GLOBALORGADMIN | [`02_create_target.sql`](sql/02_create_target.sql) | Creates the Business Critical Azure account; enables replication on both accounts |
| 3 | AWS source | ACCOUNTADMIN | [`03_source_aws.sql`](sql/03_source_aws.sql) | Creates the failover group (all replicable types, all eligible databases) and the connection |
| 4 | Azure target | ACCOUNTADMIN | [`04_target_azure.sql`](sql/04_target_azure.sql) | Creates the replicas; the first full refresh starts automatically |
| 5 | Azure target | ACCOUNTADMIN | [`05_verify_and_cutover.sql`](sql/05_verify_and_cutover.sql) | Checks refresh health; commented cutover block for when you're ready |

**What you type:** in step 2, the source account name, a temporary password, and an email address. In step 4, the two values that step 3 printed. Everything else, including the database list, is read from the account.

**Prefer clicking?** In Snowsight, **Admin » Accounts » Replication » Get started** opens the *Setup business continuity* wizard, which creates the same group and connection in one flow. It needs ACCOUNTADMIN, both accounts reachable over the public internet (not private connectivity), and steps 1–2 done first. Walkthroughs: [official Snowsight steps](https://docs.snowflake.com/en/user-guide/account-replication-config#create-a-replication-or-failover-group-using-snowsight) and a [screen-by-screen community walkthrough with screenshots](https://medium.com/towards-data-engineering/from-zero-to-dr-snowflake-disaster-recovery-using-the-snowsight-wizard-813ee7a57fbd) (third-party, April 2026).

Prefer plain language? Read [ELI5.md](ELI5.md).

## Before You Start

- **Edition.** Business Critical or higher on **both** accounts. Standard and Enterprise can replicate only databases and shares (replication groups, no failover). Accounts upgraded to Business Critical can take up to 12 hours before failover is available.
- **Region group.** AWS and Azure commercial regions are in the same region group, so this works with no support ticket. Commercial-to-government or VPS replication requires Snowflake Support.
- **Region enabled.** Step 1 lists the Azure regions available to your organization. If the one you want is missing, ask Snowflake Support to enable it.
- **Users and roles already in the target?** Don't create them by hand. On the first refresh, account objects in the target that have no match in the source are **dropped**. If the target already has them, see [Initial replication of users and roles](https://docs.snowflake.com/en/user-guide/account-replication-config#initial-replication-of-users-and-roles) and use `SYSTEM$LINK_ACCOUNT_OBJECTS_BY_NAME` before step 4. A brand-new account from step 2 avoids this.
- **Legacy database replication.** Databases enabled with `ALTER DATABASE ... ENABLE REPLICATION` must first be released with `SYSTEM$DISABLE_DATABASE_REPLICATION`. Data already replicated is not copied again.

## Why one group

Any database or account object type can belong to only one replication or failover group. One group that holds everything is the smallest configuration, it gives point-in-time consistency across all objects, and you promote it with a single statement. Split into several groups only when some databases need a different refresh frequency.

`REPLICATION_SCHEDULE = '10 MINUTE'` sets your typical recovery point. Shorten it only if your workload needs it: more frequent refreshes cost more compute. For a contractual RPO target, see [Optimized Refresh and RPO Assurance](https://docs.snowflake.com/en/user-guide/account-replication-config#optimized-refresh-and-rpo-assurance).

## What does not move: do these in Azure after step 4

Replication copies objects. It does not copy cloud-side trust, private networking, or MFA enrollments. Step 1, query 6, lists the tables affected in your account.

| Item | What to do in the Azure account |
| --- | --- |
| **Storage integrations** (S3 stages) | The replica has its own identity. Re-run `DESC INTEGRATION` in Azure and add the new principal to the S3 bucket's IAM trust policy. Data can stay in S3. |
| **API / external access integrations** | Grant the replicated integration's new identity access on the remote service. |
| **Auto-ingest pipes, directory table auto-refresh** | Create the notification path for the new account (SQS subscription for S3 buckets). Refresh pipes after switching. |
| **Private connectivity, Tri-Secret Secure** | Not enabled on targets by default. Configure Azure Private Link and TSS yourself, then add a DNS CNAME for the connection URL. |
| **MFA** | Users enroll again the first time they sign in to the Azure account. |
| **External tables, hybrid tables, event tables, temp tables** | Not replicated. Recreate them in Azure, or move them off before cutover. |
| **Inbound shares / Marketplace databases** | Not replicated. Get them again in Azure from the provider or listing. |
| **REPLICATE / FAILOVER privileges** | Not replicated. Grant them in both accounts if a non-ACCOUNTADMIN role will refresh or fail over. |
| **Account admin resource monitor emails** | Re-enable in the Azure account. |

Users and roles become **read-only** in the Azure account while it is secondary. Keep making changes in AWS; they arrive with the next refresh.

## Point clients at the connection URL now

Step 3 prints a URL like `<org>-primary_conn.snowflakecomputing.com`. Move drivers, BI tools, and your SAML IdP to this URL **before** you cut over. After that, promoting Azure needs no client changes. Check who has moved:

```sql
SELECT user_name, reported_client_type, connection, COUNT(*) AS logins
  FROM TABLE(INFORMATION_SCHEMA.LOGIN_HISTORY(DATEADD('hour', -72, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
 GROUP BY user_name, reported_client_type, connection
 ORDER BY connection NULLS FIRST, logins DESC;
```

Rows with a null `connection` are still using the account URL. Snowflake OAuth tokens are account-specific: users re-authenticate after a redirect unless the OAuth security integration is replicated (it is, in this configuration).

## Cut over (migration or DR test)

Section C of [`05_verify_and_cutover.sql`](sql/05_verify_and_cutover.sql), run in Azure:

1. `ALTER FAILOVER GROUP ACCOUNT_FG SUSPEND;` then wait for the running refresh to finish. Don't cancel a refresh that is in a `SECONDARY_DOWNLOADING_*` phase.
2. `ALTER FAILOVER GROUP ACCOUNT_FG PRIMARY;` and `ALTER CONNECTION PRIMARY_CONN PRIMARY;`
3. In AWS, now the secondary: `ALTER FAILOVER GROUP ACCOUNT_FG RESUME;` to keep a live fallback.
4. Through the connection URL: `SELECT CURRENT_REGION();` should return your Azure region.

To fail back, run the same two `PRIMARY` statements in AWS. To finish a migration, drop the secondary group in AWS, then retire the account.

**Warehouses arrive suspended.** They resume on first use as usual. Tasks run only in the primary account.

## Cost

Replication compute and data transfer are both billed in the **target** (Azure) account. The transfer rate is set by the **source** (AWS) region. The first refresh copies the full account. After that, cost scales with how much data changes and how often you refresh. The Azure account also pays storage for the replica, plus background maintenance for materialized views and search optimization. You are charged even for a refresh that fails, but data copied before the failure is reused if you retry within 14 days. Track it in the Azure account with `SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_GROUP_USAGE_HISTORY` (query in step 5). Suspending refreshes stops the charges. See [Understanding replication cost](https://docs.snowflake.com/en/user-guide/account-replication-cost).

## Related Guides

- [Introduction to replication and failover](https://docs.snowflake.com/en/user-guide/account-replication-intro)
- [Replicating databases and account objects](https://docs.snowflake.com/en/user-guide/account-replication-config)
- [Redirecting client connections](https://docs.snowflake.com/en/user-guide/client-redirect)
- [Failing over account objects](https://docs.snowflake.com/en/user-guide/account-replication-failover-failback)
- [Replication considerations](https://docs.snowflake.com/en/user-guide/account-replication-considerations)

## External References

- [CREATE FAILOVER GROUP](https://docs.snowflake.com/en/sql-reference/sql/create-failover-group)
- [CREATE CONNECTION](https://docs.snowflake.com/en/sql-reference/sql/create-connection)
- [CREATE ACCOUNT](https://docs.snowflake.com/en/sql-reference/sql/create-account)
- [Supported cloud regions](https://docs.snowflake.com/en/user-guide/intro-regions)
