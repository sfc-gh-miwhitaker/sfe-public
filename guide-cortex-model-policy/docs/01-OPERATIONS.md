# Operational Checks and Recovery

Pair-programmed by SE Community + Cortex Code

Use the [main guide](../README.md) for the ordered change. This page covers exceptions and evidence, not a second deployment path.

## Generate a Targeted Revoke

Run a model's `INSPECT_SQL` from the inventory menu. Immediately afterward, run the query below in the **same worksheet session**, with no intervening statement. It reads that last `SHOW GRANTS OF APPLICATION ROLE` result. For each direct account-role recipient, it generates a revoke and its inverse; it executes neither.

```sql
SELECT "role" AS model_application_role,
       "grantee_name" AS account_role,
       'REVOKE APPLICATION ROLE ' || "role" || ' FROM ROLE "'
           || REPLACE("grantee_name", '"', '""') || '";' AS revoke_sql,
       'GRANT APPLICATION ROLE ' || "role" || ' TO ROLE "'
           || REPLACE("grantee_name", '"', '""') || '";' AS restore_sql
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "granted_to" = 'ROLE' AND "grantee_name" <> 'ACCOUNTADMIN'
ORDER BY account_role;
```

The `role` column is the fully qualified model application-role identifier returned by Snowflake. The generator quotes the recipient identifier and preserves embedded double quotes. Inspect the generated text before execution; save recovery text in your private change record.

**Zero generated rows does not certify denial.** This query excludes application-role recipients, including the bootstrap path. Review the original result, all-model grants, inherited and secondary roles, and any remaining allowlist fallback. Trace nested grants with `SHOW GRANTS OF APPLICATION ROLE` and `SHOW GRANTS OF ROLE`; do not stop at direct grants. Use the application owner's documented grant-management mechanism rather than inventing a revoke for a Snowflake-managed object.

## Verification Must Match the Surface

| Surface | What to check |
| --- | --- |
| SQL AI functions and Cortex inference REST API | Feature privileges remain intact; approved model succeeds; excluded model produces a model authorization failure. Match the API's actual role to the intended policy. |
| CoCo in Snowsight, Desktop, and CLI | Check the connected account and role, start a fresh session, inspect the model picker, and make an approved request. The documented picker filters to models accessible to the current role. |
| Cortex Analyst | Model-level RBAC is supported, but Analyst chooses among supported accessible models. Restricting the list reduces fallback options; no supported configuration means a failed request. Test representative questions, not just SQL inference. |
| Cortex Agents and CoWork | Test the actual agent/application and its tools with the real consumer identity. Validate each required model and execution context; do not infer complete coverage from a CoCo picker or one SQL call. |
| Embeddings and Cortex Search | `2026_07` adds embedding-model RBAC enforcement. With the bundle disabled, do not claim that model RBAC blocks excluded embedding models. After separately reviewed enablement, test an approved embedding operation and an excluded, otherwise supported embedding model. Preserve approved dependencies and test service refresh as well as query behavior. An already-indexed search query alone does not prove refresh will succeed. |
| Native Apps and stored procedures | Verify the actual execution role. `PUBLIC` grants do not reach all contexts. The model access docs specifically note that restricted-caller stored procedures do not evaluate RCR caller grants for model RBAC; do not substitute caller-grant configuration for model grants. |
| External provider APIs and custom-hosted models | Outside this Cortex base-model grant recipe. Review their credentials, integrations, services, and application controls separately. |

Sources: [model access and supported features](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access), [Analyst model selection](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst#control-models-used-by-cortex-analyst), [embedding enforcement](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_07/bcr-2378).

## Troubleshooting

| Symptom | Next check |
| --- | --- |
| Excluded model still works | Check the account, active role, secondary roles, `ACCOUNTADMIN`, both all-model grant paths, direct model grants, nested roles, and legacy fallback. |
| Picker still shows an excluded model | Reconnect and confirm account/role. Compare with scoped `SHOW CORTEX BASE MODELS` as the same non-admin identity and test the actual request. If behavior disagrees, capture product/version, query or request ID, and sanitized grants for Support. |
| Catalog is empty | Include `IN SCHEMA SNOWFLAKE.MODELS`; verify the approved grants. Empty output is not a sufficient acceptance test. |
| Approved model fails | Distinguish missing model privileges from missing feature privileges, region constraints, lifecycle, and unsupported surface/model combinations. Do not widen routing or grant `ALL` as a diagnostic shortcut. |
| `AI_COMPLETE` query succeeds but returns null | Use `return_error_details => TRUE` and inspect `value` and `error`; statement success is not inference success. |
| Granting one approved model did not restrict anything | Grants add permissions; they do not override other grants. Complete broad-grant and unapproved-grant removal. |
| Model role missing | As `ACCOUNTADMIN`, use the documented refresh procedure below, then repeat inventory. Do not guess the role name. |
| A grant cannot be inspected or changed | Stop and involve the account/application administrator. Incomplete visibility is not an empty grant set. |

Refresh only when a newly available model's application role is missing:

```sql
CALL SNOWFLAKE.MODELS.CORTEX_BASE_MODELS_REFRESH();
SHOW APPLICATION ROLES LIKE 'CORTEX-MODEL-ROLE-%' IN APPLICATION SNOWFLAKE;
```

The model catalog refreshes daily automatically. The refresh procedure does not represent organization approval of every model it discovers.

## Recover Without Reopening Every Model

**Preferred recovery:** grant the missing, approved model to the workload's actual execution role and retest. If the workload requires an unapproved model, its owner must select an approved alternative or obtain an explicit policy exception. An operational failure is not implicit approval.

Keep before/after grants and the paired `RESTORE_SQL` commands before any revocation. Only restore grants actually removed by this change. Restoring an all-model grant reopens unapproved models and future releases, so it requires explicit authorization and is **not** the default rollback.

If an authorized emergency recovery specifically requires restoring the automatic bootstrap that this change removed, its documented inverse is:

```sql
CALL SNOWFLAKE.LOCAL.GRANT_TO_PUBLIC_APPLICATION_ROLE(
    'APP_ROLE',
    'CORTEX-MODEL-ROLE-ALL'
);
```

That restores the bootstrap path, not every direct grant. It also abandons the approved-only boundary while present. Remove it again through the corresponding revoke procedure after remediation.

There is no reliable transaction rollback for this multi-statement administrative change. Review after each phase. Do not try to roll back by resetting `CORTEX_MODELS_ALLOWLIST` to `'All'` or its old list: new values are no longer permitted. Restore required permissions through RBAC instead.

## Record a Defensible Outcome

Save the approved model IDs and recipients, before/after grants, bundle state, timestamps, successful approved-model evidence, excluded-model authorization evidence, production-surface checks, and documented exceptions. Do not include customer data in test prompts.

If policy prohibits even a synthetic request to an excluded model, omit that call and record that the evidence consists of grant inspection and application visibility, not a demonstrated execution denial. Do not silently substitute a deliberately misspelled or unavailable model as the negative test.

Check the actual production secondary-role configuration and service identities. A successful isolated-role check proves that role's behavior in that session, not the absence of alternative privilege paths for the user.
