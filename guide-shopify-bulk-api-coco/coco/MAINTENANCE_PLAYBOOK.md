# CoCo Maintenance Playbook

Pair-programmed by SE Community + Cortex Code

## Add A Store

> Add STORE_BRAVO using `config/stores.json`. Validate the Shopify domain and secret FQN,
> regenerate the EAI and procedure bindings, confirm the secret exists without reading it,
> deploy with the task suspended, qualify one day of orders, reconcile if a baseline is
> available, and activate only after every gate passes.

## Add An Object Or Field

> Add Shopify inventory levels. First verify the current GraphQL object, required scope,
> Bulk API compatibility, and nesting limits. Update the query and typed Dynamic Table,
> compile-check both, test on one store, compare existing outputs for regressions, then
> extend all-store scheduling and monitoring.

If the Shopify scope changes, release and reinstall the app before testing. A successful
secret does not imply the token has the new scope.

## Backfill History

> Backfill STORE_ALPHA orders after `read_all_orders` approval. Verify the app was released
> and reinstalled, run a bounded backfill with `SINCE_TS`, tag the queries, validate oldest
> order date and counts, and do not advance the regular incremental watermark on failure.

## Rotate Credentials

> Rotate STORE_ALPHA credentials. Keep the task suspended for that store, replace the
> PASSWORD secret through private SQL input, run a token/connectivity qualification, run
> one bounded pull, and restore active state only after success. Never display the secret.

## Pause Or Retire A Store

Set `IS_ACTIVE = FALSE` first. Preserve raw and typed history. Drop the secret only after
confirming no procedure binding or EAI allowlist references it; regenerate bindings.

## API Version Review

The monthly automation reports changes; CoCo Desktop performs the upgrade:

1. Verify the target Shopify API release and deprecations from first-party docs.
2. Search every GraphQL field in the procedure.
3. Change `API_VERSION` on a branch.
4. Compile and qualify one store.
5. Compare old/new row contracts and business totals.
6. Roll through remaining stores only after the pilot passes.
