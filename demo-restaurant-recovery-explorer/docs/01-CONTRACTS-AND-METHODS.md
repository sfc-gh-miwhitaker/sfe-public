# Input Contracts and Analytical Methods

Pair-programmed by SE Community + Cortex Code

## Input Boundary

Contract version 1.0 is defined and runtime-validated in `app/contracts/dataset.ts`. The server accepts a configured provider, not arbitrary browser file uploads. `JsonFixtureProvider` demonstrates replacement through serialized contract-compliant inputs; it is not a live customer connector.

| Collection | Unique grain | Required meaning |
| --- | --- | --- |
| restaurants | restaurant ID | Fictional name, market, geographic point, IANA timezone, opening/closure dates, format |
| calendar | week start | Contiguous local-business weekly buckets, explicit earlier baseline mapping, completeness and exception flags |
| performance | restaurant/week/daypart/channel | Integer guest occasions, USD net sales excluding tax, completeness |
| operations | restaurant/week/daypart | Open and labor hours; optional service minutes and observation count |
| events | event ID | Restaurant, effective interval, type, optional daypart, source |
| metadata | dataset | Contract/scenario version, seed, as-of date, synthetic provenance, units, attribution |

Dayparts and channels must be mutually exclusive and collectively exhaustive for the supplied business definition. Guest occasions count restaurant visits, not orders, checks, or unique people. An adapter must document any conversion rather than silently substituting another measure. Net sales exclude taxes and tips and are net of refunds posted in the corresponding week; negative net sales are allowed. This fixture contains no refunds.

The synthetic calendar uses 104 Monday-start weeks from 2024-09-16 through 2026-09-07. Its later-year baseline mapping is an explicit 52-week lag. The same weekday is aligned; this is not a general solution for every fiscal or holiday calendar. Actual adapters must supply the correct mapping and exception flags. A missing mapping inside the requested window fails with an actionable error rather than shifting the analysis to earlier weeks. All fixture restaurants use one IANA timezone; aggregation happens before data enters the contract.

Missing extract values are null and incomplete. Complete zero rows outside opening/closure dates represent documented inactivity. Absent records are excluded, never synthesized as zero. A selected restaurant with no paired observations returns an explicit unavailable result instead of a zero-change brief. Complete calendar periods must end on or before the as-of date. Partial-week lifecycle changes require upstream weekly aggregation rules; the fixture uses week-boundary events. A closure inside the final analysis week is included using the exclusive end of that week.

## Reconciliation

Each eligible complete paired cell contributes `current guests - baseline guests`. Restaurant contributions sum to the displayed market net change. Gross losses sum negative restaurant changes in absolute magnitude; offsetting gains sum positive restaurant changes. `Gains - losses = net change`.

Loss share uses gross losses as its denominator. It is not a percentage of net decline. A restaurant can have offsetting subsegment gains and losses; the gross-loss KPI is at restaurant grain, not a sum of every negative daypart cell.

Daypart and channel are alternative breakdowns of one total. Never add the breakdown totals together. Combined cells reconcile as well. Rates use summed numerators and denominators. A zero baseline produces no percentage rate.

The fleet bridge separates comparable restaurants, openings, closures, and restaurants outside the comparison. Completeness is an independent property, not a fifth additive lifecycle bucket. If cells are missing, the bridge reconciles only the observed paired subset; no complete-fleet estimate is claimed. The comparable subtotal is visible above the fleet metrics.

Operational hours are collected once per restaurant/week/daypart, not joined across channel rows. Guest occasions per open hour always use all channels for the selected dayparts and require complete performance and operations. A channel filter does not change operational hours.

## Matching Policy pre26-v1

Candidates must have the same market and format as the focal restaurant and complete active coverage over the 26 weeks before the analysis window. Same-market matching is a design assumption for this demo: it identifies within-market differences and deliberately does not estimate market-level external demand effects.

Five features are computed strictly before the analysis window:

| Feature | Weight | Scale floor |
| --- | --- | --- |
| Mean weekly guests | 0.30 | 300 guest occasions |
| Breakfast guest mix | 0.20 | 0.05 fraction |
| Delivery guest mix | 0.15 | 0.05 fraction |
| Mean weekly open hours | 0.20 | 15 hours |
| Last 13 / first 13 pre-period guest ratio minus one | 0.15 | 0.05 fraction |

Each distance is the sum of weighted absolute feature differences divided by the eligible pre-period population standard deviation or its floor, whichever is larger. The maximum accepted distance is 1.0. Select up to five peers, require at least three, and break ties by stable restaurant ID. These thresholds are demonstration choices, not statistically calibrated confidence limits.

Selection never reads post-period outcomes. If selected peers later have missing data or lifecycle changes affecting the baseline/outcome comparison, withhold the comparative gap; do not rematch using knowledge of their outcomes. Selected peers remain inspectable. UI filters for daypart/channel do not change matching features, but changing the analysis-window length changes the pre-period cutoff.

The peer change is the equal-weight mean of each selected restaurant's own aligned change rate. The gap is focal change rate minus peer change rate, in percentage points. The trend index divides each restaurant's weekly guests by its own mean over the matching pre-period, then averages peer indices equally. Missing values are gaps, not interpolated points.

## Evidence and Narration

Dataset content is hashed into a revision. A snapshot combines that revision, filter selection, restaurant, and analysis version. Every calculated brief metric carries a snapshot-keyed ID, formula, unit, source, population, period labels, and coverage.

Brief rules do not use restaurant IDs or generator scenario names. A staffing candidate requires a preceding dated event, declining affected daypart, negative peer gap, unchanged open hours, reduced labor, complete evidence, and a lower all-channel guest/open-hour rate. It still requires operational review and does not establish exact decline onset or causation.

A shared decline requires a negative peer change and a small descriptive gap. Insufficient coverage, inadequate peers, lifecycle changes, and positive totals have distinct outcomes. The brief retains missing economics and test-design prerequisites. No AI inference or experiment analysis occurs.

## Replacing Inputs

Implement `DatasetProvider.load()` and call `loadDataset(provider)` to validate it. Keep returned datasets immutable, recompute the content revision for a new dataset, and run both analytical fixtures and end-to-end journeys. Adapt physical columns at the provider boundary, not in UI components.

The current schema explicitly accepts synthetic data only. A real-data extension must revise provenance handling, access control, authentication, sensitive-data policy, and tests before changing that restriction. Do not merely flip a label or use the loopback demo as a production host. A future Snowflake provider and deployment are not implemented or tested here.
