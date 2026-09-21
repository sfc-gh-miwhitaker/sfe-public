---
name: restaurant-recovery-explorer
description: "Build and extend Restaurant Recovery Explorer: synthetic restaurant guest-loss attribution, pre-period peer matching, map navigation, evidence-backed briefs, and local browser tests."
---

# Restaurant Recovery Explorer

Pair-programmed by SE Community + Cortex Code

## Purpose

Demonstrate guest-loss breakdown, matched restaurant comparisons, and prospective action planning using explicit synthetic observations.

## Architecture

Versioned input contracts -> configured fixture provider -> immutable dataset index -> deterministic analytics -> snapshot-keyed evidence -> same-origin API -> linked map and brief.

## Key Files

| File | Responsibility |
| --- | --- |
| `app/contracts/dataset.ts` | Runtime validation and data types |
| `app/data/synthetic.ts` | Reproducible fictional observations |
| `app/lib/provider.ts` | Provider boundary and dataset revision |
| `app/lib/analytics.ts` | Paired contribution, lifecycle, matching, and operations |
| `app/lib/brief.ts` | Evidence records and reviewed rule-based narration |
| `app/components/explorer.tsx` | Shared state, filters, generation, and export |
| `app/tests/` | Unit and browser checks |

## Extension Playbook: New Input Provider

1. Read `docs/01-CONTRACTS-AND-METHODS.md`; preserve every grain and unit.
2. Implement `DatasetProvider.load()` with physical-to-contract mapping outside the UI.
3. Validate with `loadDataset`, then compute a new content revision.
4. Treat validated datasets as immutable; replace the dataset object after refresh.
5. Add parity tests against `JsonFixtureProvider`, including missing and duplicated rows.
6. Run unit, type, production-build, and browser checks.
7. A real-data provider additionally needs a revised provenance contract and an approved authentication/access design. It is not a label-only change.

## Extension Playbook: New Hypothesis

1. Specify measurable signals, counterevidence, and missing prerequisites.
2. Add evidence calculations before adding narrative wording.
3. Use signals, not fixture IDs or generator scenario labels, in brief rules.
4. Add positive, contradictory, incomplete, and no-peer tests.
5. Keep any intervention prospective and avoid causal or financial claims without evidence.

## Snowflake Objects

None. This release is local and synthetic-only. No deployment manifest or SQL scaffold is required until a separate demo-target deployment is approved. Never use the active account as an implicit target.

## Gotchas

- Ops hours are not additive over channels.
- Guest occasions are not unique people or orders.
- Peer matching is same-market and pre-period-only; outcome gaps are withheld for incomplete or lifecycle-changing peers.
- Missing is not zero; breakdowns are alternatives, not extra explanatory totals.
- Filter changes invalidate briefs; delayed requests must not attach to a new selection.
- Template-generated briefs are not AI output.
- Keep Next.js workspace-root and standalone-output settings when updating configuration.
- Run browser tests against the local synthetic app, never a live account endpoint by default.
