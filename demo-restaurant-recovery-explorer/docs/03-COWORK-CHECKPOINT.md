# CoWork Delivery Checkpoint

Pair-programmed by SE Community + Cortex Code

## Implemented

The retained synthetic release `restaurant-recovery-v2.0.0-seed-417` passed local validation on 2026-09-21. All nine manifest entries passed checksum and byte-size checks. Eight data tables passed row counts, dictionary field validation, unique grains and foreign-key checks. Performance also passed calendar, complete-grid, lifecycle, availability and null/completeness checks. Workforce passed stock/flow, consecutive-week continuity, tenure and internal-transfer reconciliation.

The source generator package is incomplete. This is a validated retained fixture, not a reproducible v2 generation pipeline. Operations, ratings, reviews and promotions have structural validation only; their analytical checks remain deferred.

## Reference Answer

For 2026-07-20 through 2026-09-13 inclusive, compared with the calendar's explicit 52-week baseline mappings:

| Metric | Guest occasions |
|---|---:|
| Net paired change | -203,334 |
| Gross restaurant-level losses | 218,362 |
| Offsetting restaurant-level gains | 15,028 |
| Change excluding closures | -184,243 |

There are 72 excluded restaurant/week/daypart/channel pairs. Both current and baseline values are excluded when either observation is incomplete. No missing value is replaced with zero. These are synthetic descriptive results, not causal estimates.

## Reproduce

Run from the repository root with Python 3.12 or later. No third-party Python packages are required.

```bash
python3 demo-restaurant-recovery-explorer/tools/validate_release.py \
  demo-restaurant-recovery-explorer/local/restaurant-recovery-v2.0.0-seed-417 \
  --report demo-restaurant-recovery-explorer/local/release-validation.json
python3 -m unittest discover \
  -s demo-restaurant-recovery-explorer/tools -p 'test_validate_release.py'
```

The immutable fixture and generated validation report remain ignored under `local/`. The report includes restaurant-level expected answers for independent comparison with future live SQL.

## Blocker and Next Checkpoint

The CoWork tab opened, but embedded browser inspection and navigation both failed with `The WebView must be attached to the DOM and the dom-ready event emitted before this method can be called.` A targeted retry did not resolve it. Bring the CoWork browser tab into view in the desktop application; restore browser attachment before resuming live acceptance.

No project cloud objects, semantic view, agent or saved artifact have been created. Demo-account identity was verified read-only. Once browser access works, continue with the approved minimum data layer and one live answer, then save/reopen one chart and verify the closure-exclusion follow-up. Stop for review before adding ratings and turnover. Do not share artifacts or change account-level grants.
