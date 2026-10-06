# CoCo Maintenance Playbook

Pair-programmed by SE Community + Cortex Code

## Add A Store

> Add STORE_BRAVO using `config/stores.json`. Validate the Shopify domain and secret FQN,
> regenerate the EAI and procedure bindings, confirm the secret exists without reading it,
> deploy with the task suspended, qualify one day of orders, reconcile if a baseline is
> available, and activate only after every gate passes.

The store must already be registered in the shared registry
(`CALL SHOPIFY_CONTROL.META.ADD_STORE(...)`), which the generator's MERGE also maintains.
Registration never activates a store.

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

Set `IS_ACTIVE = FALSE` in `SHOPIFY_CONTROL.META.STORE_REGISTRY` first. Preserve raw and
typed history. Drop the secret only after confirming no procedure binding or EAI allowlist
references it; regenerate bindings.

## API Version Review

The pinned version is `2026-01`, the floor at which each app gets five concurrent bulk
query operations per shop and polling by operation ID is required. 2026-01 is supported
until at least 2027-01-01. The monthly automation reports changes; CoCo Desktop performs
the upgrade:

1. Verify the target Shopify API release and deprecations from first-party docs.
2. Search every GraphQL field in the procedure against the target version.
3. Change `API_VERSION` on a branch.
4. Compile and qualify one store.
5. Compare old and new row contracts and business totals, and confirm
   `SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE` still reports zero violations.
6. Roll through the remaining stores only after the pilot passes.

## Switch Implementation Paths

The store registry, the reconciliation baseline, and the analytics contract are shared,
so a path switch is not a rebuild:

1. Stand up the other path alongside this one. Do not tear anything down yet.
2. Both paths write the same two published views. Only one may own them at a time, so
   deploy the new path's analytics file last, after reconciling at the raw layer.
3. Reconcile at least three daily cycles through
   `SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY`.
4. Run the other path's teardown. Leave `SHOPIFY_CONTROL` in place.

Downstream reports read the published view name and do not change.
