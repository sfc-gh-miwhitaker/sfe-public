# CoCo Build And Qualification Playbook

Pair-programmed by SE Community + Cortex Code

This is the primary deployment interface for the native path. Do not begin by pasting
every SQL file into a worksheet. Open the project in CoCo Desktop, connect to the target
account, and ask CoCo to execute these gates in order.

This file is the single definition of the gate sequence and the pilot command.
`path-native-coco.md` points here rather than restating them.

## Start Prompt

> Build the native Shopify path in the connected Snowflake account. Read `AGENTS.md`,
> this playbook, `path-native-coco.md`, and every file under `sql/shared/` and
> `sql/native/` first. Verify the current Shopify Bulk API and Snowflake
> external-access documentation. Execute one gate at a time, show evidence after each
> gate, and stop on the first failure. Do not resume any task or activate any store
> until every qualification gate passes.

## Gates

Order matters. Each gate's evidence is what justifies attempting the next one.

| # | Gate | CoCo action | Pass evidence |
| --- | --- | --- | --- |
| 1 | Documentation | Verify API version, client-credentials grant, bulk operation limits, Python runtime, secret API, and `put_stream` | Current first-party URLs; no contradicted syntax |
| 2 | Shared control plane | Deploy `sql/shared/01_store_registry.sql` and `02_analytics_contract.sql` | Registry exists; contract shows 14 rows |
| 3 | Security | Deploy `sql/native/01_landing.sql` and the network rule in `02_network_secrets.sql`; create each store secret through private SQL input; scan the repository | `DESC SECRET` metadata only, EAI allowlist correct, no secret values in any file |
| 4 | Compilation | Compile every DDL independently; parse the embedded Python; validate the GraphQL against one store | No compile or parser errors |
| 5 | Connectivity | Call the token endpoint through `PULL_STORE` | No 401, DNS, or EAI failure |
| 6 | Extraction | Start and poll a one-day order bulk query | `bulk_operation_id` recorded; status `COMPLETED` |
| 7 | Landing | Inspect `LIST @SHOPIFY_STAGE/...` | One non-empty JSONL result |
| 8 | Loading | Inspect the COPY result and raw rows | `ROWS_LOADED > 0`, no rejected rows |
| 9 | Contract | Deploy `sql/native/05_analytics_layer.sql`; query `V_CONTRACT_CONFORMANCE` | `CONTRACT_VIOLATIONS = 0`; required IDs, timestamps, and money fields present |
| 10 | Grain | Run the grain smoke test in `sql/shared/03_monitoring.sql` query E | Zero duplicate `(store_key, activity_date, currency_code)` rows |
| 11 | Reconciliation | Compare count and gross sales to the incumbent baseline when supplied | Delta within the agreed tolerance |
| 12 | Scheduling | Set the store active; `EXECUTE TASK`; then resume | Only after every prior gate passes |
| 13 | Rollback | Confirm task suspend and the dependency-ordered teardown are available | Tested commands on hand |

The first store is a deployment qualification test. Every later store follows the proven
playbook independently.

## Pilot Command

```sql
CALL SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE('STORE_ALPHA', NULL);

SELECT STORE_KEY, GATE_NAME, PASSED, EVIDENCE
FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
WHERE STORE_KEY = 'STORE_ALPHA'
ORDER BY CHECKED_AT, GATE_NAME;
```

For a migration, load the incumbent daily counts and gross sales into
`SHOPIFY_CONTROL.META.RECONCILIATION_BASELINE`, then pass its `SOURCE_NAME` instead of
`NULL`. CoCo explains timezone, refund, test-order, and history-window differences; it
does not wave them away.

## Promotion Prompt

> Review STORE_ALPHA's qualification evidence. If and only if every gate passed, mark
> the store active, execute the task once manually, verify freshness, contract
> conformance, and the typed Dynamic Tables, then resume the daily task. If any gate
> failed, diagnose and repair the root cause, rerun only the failed store's
> qualification, and present the before/after evidence.

```sql
UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY
SET IS_ACTIVE = TRUE
WHERE STORE_KEY = 'STORE_ALPHA' AND QUALIFICATION_STATUS = 'PASSED';

EXECUTE TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL;
ALTER TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL RESUME;
```

`EXECUTE TASK` proves the scheduled owner-role path before the schedule is enabled. The
`QUALIFICATION_STATUS = 'PASSED'` predicate in the `UPDATE` makes the promotion gate
impossible to bypass by accident.

## Add More Stores

After the pilot passes, add stores in batches of five. For each batch, CoCo validates
`config/stores.json`, regenerates secret bindings, confirms every secret exists and is
allowed by the EAI, redeploys the procedure, qualifies each store independently, and only
then activates the passing stores.
