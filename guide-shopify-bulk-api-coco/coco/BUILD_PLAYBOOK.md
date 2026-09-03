# CoCo Build And Qualification Playbook

Pair-programmed by SE Community + Cortex Code

This is the primary deployment interface. Do not begin by pasting every SQL file into a
worksheet. Open the project in CoCo Desktop, connect to the target account, and ask CoCo
to execute these gates in order.

## Start Prompt

> Build this Shopify pipeline in the connected Snowflake account. Read `AGENTS.md`, this
> playbook, and every SQL file first. Verify the current Shopify Bulk API and Snowflake
> external-access documentation. Execute one gate at a time, show evidence after each
> gate, and stop on failure. Do not resume any task or activate any store until every
> qualification gate passes.

## Gates

| Gate | CoCo action | Pass evidence |
|---|---|---|
| Documentation | Verify API version, client-credentials grant, Bulk Operation limits, Python runtime, secret API, and `put_stream` | Current first-party URLs and no contradicted syntax |
| Security | Deploy `01` and `02`; create the store secret through a private SQL input; scan the repository | `DESC SECRET` metadata, EAI allowlist, no secret values in files |
| Compilation | Compile every DDL independently; parse embedded Python; validate GraphQL against one store | No compile/parser errors |
| Connectivity | Call the token endpoint through `PULL_STORE` | No 401, DNS, or EAI failure |
| Extraction | Start and poll a one-day order bulk query | `bulk_operation_id`, `COMPLETED` |
| Landing | Inspect `LIST @SHOPIFY_STAGE/...` | One non-empty JSONL result |
| Loading | Inspect COPY result and raw rows | `ROWS_LOADED > 0`, no rejected rows |
| Contract | Query required fields (`id`, `updatedAt`, money fields) | `DATA_CONTRACT = TRUE` |
| Reconciliation | Compare count and gross sales to the incumbent baseline when supplied | Delta within the agreed tolerance |
| Scheduling | Set store active; resume task | Only after all prior gates pass |
| Rollback | Suspend task and document teardown order | Tested commands available |

## Pilot Command

```sql
CALL SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE('STORE_ALPHA', NULL);

SELECT STORE_KEY, GATE_NAME, PASSED, EVIDENCE
FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
WHERE STORE_KEY = 'STORE_ALPHA'
ORDER BY CHECKED_AT, GATE_NAME;
```

## Promotion Prompt

> Review STORE_ALPHA's qualification evidence. If and only if every gate passed, mark
> the store active, execute the task once manually, verify freshness and typed Dynamic
> Tables, then resume the daily task. If any gate failed, diagnose and repair the root
> cause, rerun only the failed store qualification, and present the before/after evidence.

## Add More Stores

After the pilot passes, add stores in batches of five. For each batch, CoCo validates
`config/stores.json`, regenerates secret bindings, confirms every secret exists and is
allowed by the EAI, redeploys the procedure, qualifies each store independently, and only
then activates the passing stores.
