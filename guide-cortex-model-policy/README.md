![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--12--05-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Choose Which AI Models Your Snowflake Users Can Use

Your organization decides which models it approves. Use Snowflake's model application roles to keep an explicit approved list, remove access to everything else, and prevent newly released models from becoming usable through an all-models grant. This guide starts with a read-only inventory, generates copy-ready commands from your account, and separates the access change from its verification.

**Audience:** Snowflake account administrators responsible for model approval and AI access.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-10-06 | **Last verified:** 2026-10-06 | **Expires:** 2026-12-05 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

**The policy: approve models explicitly, rather than allow everything except today's unwanted model.** There is no deny override that cancels an inherited all-models grant. `CORTEX-MODEL-ROLE-ALL` includes future models. Individual model grants do not. [Model access documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access#label-cortex-llm-rbac)

1. **Inventory.** Open [the read-only worksheet](sql/01_inventory.sql) in Snowsight using `ACCOUNTADMIN`. Run its sections in order and save the results privately. Nothing in this worksheet grants or revokes access.
2. **Choose.** Select the exact models your organization approves, including models required by existing AI functions and search workloads. The worksheet generates commands; it does not decide approval for you.
3. **Prepare.** Copy only the approved `GRANT_SQL` rows into a separate change worksheet. Grant these before removing broad access. Capture existing grants for recovery.
4. **Restrict.** Follow [the admin change sequence](#apply-the-policy): remove the automatic all-models grant, any customer-managed all-models grants, and existing grants for unapproved models; disable the legacy allowlist fallback.
5. **Prove.** Use [the acceptance checklist](#verify-the-result) with a real non-admin user: approved models work, excluded models fail authorization, and the actual application respects the policy.

**Want CoCo to prepare it?** Use the [approval-first prompt](#let-coco-prepare-the-change). Prefer plain language? Read [ELI5.md](ELI5.md).

This is an administrative guide, not a demo deployment. No database, warehouse, table, or service is created. **The change itself affects existing workloads across the account.** Test in a non-production account and schedule the production change with workload owners.

## Why a new model can appear

An account can inherit `CORTEX-MODEL-ROLE-ALL`, which authorizes all current and future Cortex models, subject to feature access, availability, and lifecycle restrictions. That is one documented explanation for new choices appearing without someone granting each model separately; inspect your grants before attributing a particular incident to it.

Snowflake's automatic grant can follow this path:

```text
All current and future model access
    -> SNOWFLAKE.PUBLIC (application role)
    -> PUBLIC (account role)
    -> users' effective privileges
```

There can also be a separate customer-managed grant directly to `PUBLIC` or another account role. **Both paths can exist at once.** Removing only one leaves the other intact. [Bootstrap documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access#label-cortex-model-role-all-bootstrap)

Seeing a model in a catalog or picker does not establish that it processed any data. Establish actual use from the relevant product's usage records, not from its presence in a list.

## Apply the Policy

### 1. Save the before-state

Use `ACCOUNTADMIN` to inventory the account. Keep the output in your organization's change record, not in this public repository.

```sql
USE ROLE ACCOUNTADMIN;
SHOW PARAMETERS LIKE 'CORTEX_MODELS_ALLOWLIST' IN ACCOUNT;
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
SELECT SYSTEM$BEHAVIOR_CHANGE_BUNDLE_STATUS('2026_07') AS model_rbac_bundle_status;
SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;
SHOW GRANTS TO ROLE PUBLIC;
SHOW GRANTS OF APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL";
SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;
```

The application role `SNOWFLAKE.PUBLIC` and account role `PUBLIC` are **different objects**. Inspecting just `SHOW GRANTS TO ROLE PUBLIC` is insufficient. Also inspect model-specific grants: removing `ALL` does not erase them.

### 2. Grant the approved models first

The [inventory worksheet](sql/01_inventory.sql) returns a model-role menu with `GRANT_SQL` and `INSPECT_SQL` columns. Copy only the grants for approved models. There are no model-name placeholders to replace and no hardcoded vendor recommendations.

The generated grants target **account role `PUBLIC`**: a shared approved baseline for users who already have the relevant Cortex feature privileges. They do not grant those feature privileges themselves. This baseline is not a ceiling on other roles.

**If approval differs by team, grant models to each existing execution role instead.** The worksheet also emits correctly quoted role identifiers in its last result. Use the exact execution-role names rather than creating another role hierarchy just for this walkthrough. The CoCo prompt below can prepare that mapping without hand-editing identifiers.

Check lifecycle and regional availability alongside the menu. A model role's existence is not approval, proof of general availability, or proof that it works in your region. Do not generate approval by a vendor prefix or by "everything except this name." Save the exact selected names as the policy record.

Before continuing, verify required grants for service users, stored procedures, Native Apps, and embedding/search workloads with their actual execution contexts. **Do not assume a `PUBLIC` grant reaches every execution context.** [Migration guidance](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access#label-cortex-llm-migrate-to-rbac)

### 3. Remove all-model access through both paths

**Automatic bootstrap:** if the before-state shows `CORTEX-MODEL-ROLE-ALL` on `SNOWFLAKE.PUBLIC`, remove it using the documented procedure:

```sql
USE ROLE ACCOUNTADMIN;
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
    'APP_ROLE',
    'CORTEX-MODEL-ROLE-ALL'
);
SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;
```

Confirm the grant is gone. A raw revoke from account role `PUBLIC` does **not** remove this bootstrap grant or persist the bootstrap opt-out across upgrades.

**Customer-managed grants:** the inventory worksheet produces `REVOKE_SQL` and `RESTORE_SQL` for direct all-model grants to account roles other than `ACCOUNTADMIN`. Review the recipients, save recovery commands privately, then execute the approved revokes. If there is a direct grant to `PUBLIC`, its revoke is:

```sql
REVOKE APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" FROM ROLE PUBLIC;
```

Use that statement only for a direct grant shown in the inventory. Inspect other recipient types separately; the generator deliberately does not revoke application-managed grants. Account-wide restriction requires closing every applicable non-admin path, not merely changing `PUBLIC`.

### 4. Remove existing grants for unapproved models

For each unapproved model, run its generated `INSPECT_SQL`. Follow any account-role recipients through `SHOW GRANTS OF ROLE` to find inheriting roles and users. Inspect nested application-role recipients too. Check the real user's secondary roles and any application/service execution role. Save the grants you intend to remove and review their workload impact.

Use the [targeted revoke generator](docs/01-OPERATIONS.md#generate-a-targeted-revoke) to produce paired removal/recovery commands from one model's current recipients. Repeat for **every model outside the approved list**. Removing an individual grant cannot counteract an `ALL` grant left elsewhere.

`ACCOUNTADMIN` always has access to all models, including when active as a secondary role. These controls restrict non-admin use; they do not impose an immutable ban on administrators. Grant administrators can also change the policy. [Access-control caveats](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access#label-cortex-llm-access-control)

### 5. Disable the legacy fallback

After approved grants are in place, remove the second authorization path while it still exists:

```sql
ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'None';
```

`'None'` means **no allowlist fallback**, not "deny every model regardless of grants." Before `2026_07` enforcement, a model can pass through RBAC **or** the legacy allowlist. After enforcement, RBAC alone controls access. Do not set a new comma-separated allowlist or try to restore its previous value. Since August 5, 2026, the only permitted parameter change is `'None'`.

As of October 6, 2026, the published `2026_07` bundle is disabled by default; its account-specific state determines enforcement. Default enablement is planned for October, with full retirement targeted for November 18, subject to change. **Do not enable an entire behavior-change bundle as an incidental step in model filtering.** It contains unrelated changes. [BCR-2378](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_07/bcr-2378) | [Bundle history](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_07_bundle)

## Verify the Result

Use a real non-admin user and the intended execution role. Select that role in Snowsight; do not test as `ACCOUNTADMIN` or a role with `MANAGE GRANTS` and interpret its catalog visibility as ordinary-user access.

```sql
USE SECONDARY ROLES NONE;
SELECT CURRENT_ROLE() AS testing_role, CURRENT_SECONDARY_ROLES() AS secondary_roles;
SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;
```

Always include `IN SCHEMA SNOWFLAKE.MODELS`. Without it, a current database elsewhere can cause an empty result that looks like a successful restriction.

The inventory worksheet generates `TEST_SQL` from model names before restriction. Save two commands: one approved text-generation model and one excluded, otherwise available text-generation model supported by `AI_COMPLETE`. **Run them separately**, using only the literal synthetic prompt. Do not execute test rows for every model or feed business data to the excluded-model test.

- [ ] The approved model returns a non-null `value` with no `error`.
- [ ] The excluded model returns an authorization error, either as a query failure or in the returned `error` field. A null response alone, unsupported-model error, unavailable-region error, timeout, or end-of-life failure is not proof of model RBAC enforcement.
- [ ] The user reconnects to the actual application with the intended role. CoCo's documented model picker behavior, across Snowsight/Desktop/CLI, is to show models the current role can access. Check both the picker and an actual request.
- [ ] The same restriction holds with the user's **normal secondary-role configuration**, not only the isolated test session. If enabling normal secondary roles restores access, resolve that grant path before declaring success.
- [ ] Existing approved workloads still work, including their execution roles and required embedding models.
- [ ] If the policy covers embedding models, `2026_07` is `ENABLED` or `RELEASED`, and an approved embedding operation succeeds while an excluded, otherwise supported embedding model fails authorization. If the bundle is `DISABLED`, embedding-model restrictions are **not enforced by model RBAC**; record that coverage gap and do not sign off account-wide approved-only coverage. Bundle enablement requires its own change review.
- [ ] Reinspection shows no unapproved model grants or broad grants reachable by the intended users. Record the account, user, role, secondary-role state, model IDs, results, and query IDs privately.

Run the same acceptance checks through each production surface you use. A SQL test alone does not certify every managed service, external API, or custom model endpoint. See [operational checks and recovery](docs/01-OPERATIONS.md).

## Let CoCo Prepare the Change

Connect CoCo to the **account you intend to configure**, then paste:

```text
Help me allow only organization-approved Cortex models in this account.
Start read-only. Confirm the account and active role. Show me the current
model catalog with lifecycle/region information and ask which exact models
and execution roles we approve; do not infer approval from a vendor name.

Inspect both PUBLIC the account role and SNOWFLAKE.PUBLIC the application
role, every CORTEX-MODEL-ROLE-ALL grant, and model-specific grants outside
the proposed approved list. Trace inherited roles, secondary roles, and
application/service execution contexts. Missing visibility is a blocker,
not evidence that no grants exist.

Prepare a minimal, ordered change: approved model grants first; bootstrap
opt-out using SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE when
present; reviewed direct broad/model-specific revokes; legacy allowlist
set to None if still applicable. Include before-state, workload impact,
targeted recovery commands, and approved/blocked synthetic tests. Explain
the ACCOUNTADMIN exception and models needed by existing managed features.

Show me the exact account and SQL for approval before changing anything.
Do not change feature privileges, cross-region routing, behavior-change
bundles, or model selections inside agents. Do not call an excluded model
without my approval, even for a test. After approval, verify with a real
non-admin user in isolated and normal secondary-role configurations and
in the actual application. Do not declare success from an empty catalog,
a null response, an unrelated error, or an administrator-only test.
```

## Model Origin Is Not Inference Location

Keep three decisions separate: **who developed the model**, **which model your organization approves**, and **where inference is processed**. A model's name or developer's location does not establish where your Snowflake request runs. Equally, acceptable hosting does not obligate your organization to approve that model.

Use model RBAC for the approved-model list. Review `CORTEX_ENABLED_CROSS_REGION` separately for processing-location boundaries, using the model's current availability and applicable legal terms. This guide deliberately does not widen routing to make a test pass. [Cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference)

## Keep New Models Opt-In

Maintain an explicit list of model IDs, approved execution roles, approver, review date, and required workloads in your change-management system. New releases require review and a new individual model grant. Recheck broad grants and perform the negative test after role changes, model migrations, and upgrades.

Do not schedule "grant all models except these names" automation: it turns future releases into implicit approvals. Model retirement also needs a review so an approved replacement is available before an existing dependency expires.

## Costs and Cleanup

Reading this guide and running the `SHOW` inventory creates no infrastructure. `SHOW` commands do not require a running warehouse. SQL post-processing can require an existing warehouse; use your normal administrative query environment. Executed inference tests consume credits if a call succeeds, including an unexpectedly successful excluded-model test. The generated text test caps output at 16 tokens; there is no batch inference in the inventory script.

There is no teardown script. Closing the worksheet does **not** undo grants. Keep the approved policy; recover individual workloads with the narrow grants in [recovery guidance](docs/01-OPERATIONS.md#recover-without-reopening-every-model).

## Development Tools

For Cortex Code and compatible tools, [AGENTS.md](AGENTS.md) describes this guide's maintenance boundaries and [.claude/skills/guide-cortex-model-policy/SKILL.md](.claude/skills/guide-cortex-model-policy/SKILL.md) provides the update playbook. Neither is needed to follow the guide.

## Related Guides

- [Snowflake model access controls](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access#label-cortex-llm-access-control)
- [Cortex Analyst model controls](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst#control-models-used-by-cortex-analyst)
- [Cross-region inference boundaries](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference)

## External References

- [BCR-2378: allowlist-to-RBAC enforcement](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_07/bcr-2378)
- [2026_07 bundle status](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_07_bundle)
- [Allowlist retirement and migration timeline](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2378)
- [SHOW CORTEX BASE MODELS](https://docs.snowflake.com/en/sql-reference/sql/show-cortex-base-models)
- [SHOW APPLICATION ROLES](https://docs.snowflake.com/en/sql-reference/sql/show-application-roles)
- [SHOW GRANTS](https://docs.snowflake.com/en/sql-reference/sql/show-grants)
- [AI_COMPLETE and error details](https://docs.snowflake.com/en/sql-reference/functions/ai_complete)
- [Model availability and lifecycle](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-regional-availability)
