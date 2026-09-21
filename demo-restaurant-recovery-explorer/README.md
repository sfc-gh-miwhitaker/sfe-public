![Demo](https://img.shields.io/badge/type-demo-blue) ![Local First](https://img.shields.io/badge/runtime-local%20first-29B5E8) ![Expires](https://img.shields.io/badge/Expires-2026--10--18-orange) ![Status](https://img.shields.io/badge/Status-ACTIVE-green)

# Restaurant Recovery Explorer

Find where restaurant guest occasions changed, compare similar restaurants, and generate an evidence-backed action brief through a linked map. This working local application uses a reproducible fictional network, not customer data. Its application structure targets Snowflake App Runtime, but no Snowflake adapter or deployment is included in this release.

**Audience:** Regional operations leaders, restaurant analysts, and demo builders.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-18 | **Expires:** 2026-10-18 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.
> **Synthetic demonstration data.** Restaurant names, coordinates, performance, and operational events are fictional. Briefs are template-generated, not AI-generated. No causal findings or recovered-visit promises.

---

## Quick Start

Requires Node.js 22 or later and npm. From the repository root:

```bash
bash demo-restaurant-recovery-explorer/tools/start.sh
```

The script installs the locked dependencies if needed and opens a loopback-only application server on port 3217. Visit `http://127.0.0.1:3217`. Stop it with Ctrl+C. No database connection, credentials, map token, or AI provider is required. Package installation needs network access; application operation does not make external calls.

## Try the Workflow

1. Start in **Mesa Vale / Copper Table**. Inspect breakfast losses, operating hours, and the dated staffing event.
2. Open **Comparisons**. Inspect the selected peers, pre-period feature differences, exclusions, and descriptive performance gap.
3. Open **Action Brief**, generate the brief, follow an evidence citation, and export Markdown.
4. Switch to **Juniper Coast / Copper Grill**. Similar restaurants share the decline; the brief does not invent a uniquely store-specific explanation.
5. Switch to **Cedar Basin / Aspen Terrace**. Its unique format produces no credible peer set. The brief recommends investigation rather than a fabricated benchmark.

Map points and ranking rows select the same restaurant. Filters apply to the map, detail analysis, and brief. Changing the selection invalidates the prior brief. The map is fictional geography, not a trade-area model.

## What Is Implemented

- 48 fictional restaurants, three markets, 104 complete calendar weeks, four dayparts, and three channels. One deliberately incomplete extract tests missing-data handling.
- Four- or eight-week aligned prior-year comparisons; restaurant, daypart, channel, and combined-cell contribution analysis.
- Signed fleet reconciliation, comparable restaurant subtotal, openings, closures, gross losses, offsetting gains, and explicitly excluded observations.
- Same-market, same-format matching based on 26 pre-period weeks, with transparent distance weights and minimum peer requirements.
- Local rule-based action briefs with evidence IDs, numerical calculations, counterevidence, missing inputs, prospective test design, and Markdown export.
- Keyboard-operable map selection, pan/zoom controls, accessible ranking alternative, mobile layout, and stale-request protection.

See [input contracts and metric definitions](docs/01-CONTRACTS-AND-METHODS.md), [walkthrough and boundaries](docs/02-WALKTHROUGH-AND-BOUNDARIES.md), and [plain-language explanation](ELI5.md).

## Architecture

```text
Synthetic generator or JSON fixture provider
    -> runtime-validated versioned contracts
    -> deterministic loss, peer, and operations calculations
    -> snapshot-keyed evidence
    -> same-origin API
    -> map, ranking, comparisons, action brief
```

The contracts live in `app/contracts/dataset.ts`. `SyntheticProvider` and `JsonFixtureProvider` implement the same input boundary. The generated fixtures remain separate from the analytics modules. There is no scenario-label shortcut in the analytical outputs.

The web application uses the bundled Snowflake Apps template's Next.js standalone layout and workspace-root pin, adapted to the explicitly synthetic-only scope. Unused SQL routes, credential loading, and database dependencies are intentionally absent. No runtime authentication is claimed for the loopback-only local server.

## Verification

```bash
npm --prefix demo-restaurant-recovery-explorer/app ci --ignore-scripts
npm --prefix demo-restaurant-recovery-explorer/app test
npm --prefix demo-restaurant-recovery-explorer/app run typecheck
npm --prefix demo-restaurant-recovery-explorer/app run build
npm --prefix demo-restaurant-recovery-explorer/app run test:browser
```

Browser tests use an installed Google Chrome. For environments without Chrome, configure the browser channel in `app/playwright.config.ts` before testing. They cover map/list synchronization, three evidence outcomes, exports, filter invalidation, delayed responses, generation failure, mobile width, and keyboard selection.

Unit tests cover contract validation, provider equivalence, loss reconciliation, lifecycle effects, missing observations, zero baselines, operational grain, pre-period leakage, evidence references, and future-closure handling. The fixture is intentionally small; these tests are not a performance benchmark for a production data estate.

## Deployment Boundary

This is the approved local-first release. The deliberate exception to the monorepo SQL-demo layout is that there are **no** `deploy_all.sql`, `teardown_all.sql`, or empty `sql/` placeholders: no Snowflake objects exist to deploy or tear down.

Snowflake deployment is a separate step requiring an explicitly approved **demo account**, connection, role, resources, and costs. Never infer the target from the active IDE connection. Account identifiers and connection details belong in local configuration, not tracked files. Deployment manifests are locally ignored until the approved destination and publication boundary are reviewed.

A later Snowflake-backed implementation must generate its manifest using the current `snow app setup` flow against the approved target, retain build asset-copy steps, and verify target-specific permissions. For a database adapter, map data to the documented contracts, implement parameterized server-side queries, and test parity before changing the provider. Use the monorepo SQL orchestrator and scoped teardown when actual Snowflake data objects are introduced. Do not claim the unimplemented adapter or deployment has been validated.

## Limitations

- Guest occasions are visits, not unique guests. Acquisition, retention, and loyalty behavior cannot be inferred.
- Similarity matching is descriptive and uses same-market peers. It cannot identify why an entire market declined or estimate causal effects.
- Synthetic event chronology supports a hypothesis, not proof of causation. Staffing rules require several signals, not just an event label.
- Excluded cells are not estimated. Totals describe the complete paired subset when coverage is below 100%.
- No measured experiment results, statistical power, contribution margin, or ROI are supplied. These remain prospective requirements.
- No external data acquisition, live AI, campaign activation, sending, or identity integration is implemented.

## Development Tools

Project-specific guidance is in `AGENTS.md` and `.claude/skills/restaurant-recovery-explorer/SKILL.md`. Keep generated data and calculations separate from UI logic. Run the tests before changing formulas or matching eligibility.

## Related Guides

- [Snowflake App Runtime](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/about-snowflake-app-runtime)
- [Getting started with Snowflake App Runtime](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/getting-started)

## External References

- [Snowflake App Runtime deployment manifests](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/migrate-to-app-yml)
- [Next.js documentation](https://nextjs.org/docs)
- [Playwright test documentation](https://playwright.dev/docs/intro)
- [Zod validation](https://zod.dev/)
