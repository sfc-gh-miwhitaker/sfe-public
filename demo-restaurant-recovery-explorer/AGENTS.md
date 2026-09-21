# Restaurant Recovery Explorer

Pair-programmed by SE Community + Cortex Code

<!-- Global rules apply via ~/.claude/CLAUDE.md and rules/. Keep this project-specific. -->

## Architecture

`app/data/synthetic.ts` generates fictional observations. `app/contracts/dataset.ts` validates the input boundary. `app/lib/analytics.ts` computes deterministic metrics; `app/lib/brief.ts` turns snapshot-keyed evidence into reviewed templates. API routes expose only synthetic outputs. Client components do not import server calculation modules at runtime.

## Conventions

- Synthetic-only local release. No Snowflake objects or deployment are authorized by project files.
- Future Snowflake work requires an explicitly approved demo connection and resource review. Never use the active connection implicitly.
- Do not remove synthetic or template-generated disclosures.
- Missing observations stay missing; operational hours are not repeated across channels.
- Matching uses same-market, same-format, pre-period features only. Outcome/lifecycle incompleteness withholds the gap rather than replacing peers after observing outcomes.
- Treat datasets as immutable once indexed. Snapshot IDs incorporate dataset revision, filters, restaurant, and analysis version.
- Do not let synthetic generator scenario labels flow into analytical or brief decision logic.
- Do not introduce external map tiles or font/network dependencies into the runtime.

## Key Commands

Run from the repository root:

```bash
bash demo-restaurant-recovery-explorer/tools/start.sh
npm --prefix demo-restaurant-recovery-explorer/app test
npm --prefix demo-restaurant-recovery-explorer/app run typecheck
npm --prefix demo-restaurant-recovery-explorer/app run test:browser
```

## Key Files

- `docs/01-CONTRACTS-AND-METHODS.md`: metric definitions and matching assumptions.
- `app/components/explorer.tsx`: shared filters, selection, evidence navigation, and stale-generation guard.
- `app/components/restaurant-map.tsx`: bundled fictional geography and keyboard selection.
- `app/tests/`: analytical tests and browser journeys.

## Release Boundary

The local-only package intentionally omits SQL deployment placeholders. The public reader site publishes documentation, not this application or hidden tooling. No commit, push, publication, or deployment is implicit in a local build.
