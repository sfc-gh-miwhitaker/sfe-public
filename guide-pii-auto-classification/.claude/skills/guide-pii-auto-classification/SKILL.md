---
name: guide-pii-auto-classification
description: "Maintain the new-admin guide for native Snowflake sensitive data classification: classification profiles, system tags, tag maps, custom classifiers, tag-based masking, Trust Center, cost, and troubleshooting."
---

# PII Auto-Classification Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Show a new Snowflake administrator how to find, tag, and mask PII in
structured data automatically with native features only, in both the Trust
Center and SQL.

## Architecture

Governance schema (tag with ALLOWED_VALUES, string masking policy on the tag,
custom classifier, classification profile with auto_tag + tag map + custom
classifier + exclusion setting) -> SYSTEM$CLASSIFY with the profile for an
immediate result -> ALTER SCHEMA SET CLASSIFICATION_PROFILE for scheduled
(Autopilot) classification -> analyst role sees masked columns.

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Seven side-by-side steps, operate, misconceptions |
| `ELI5.md` | Plain-language version |
| `sql/walkthrough.sql` | One Run All, re-runnable, synthetic data |
| `sql/teardown.sql` | Removes only guide objects |
| `tests/test_guide.py` | Documentation and SQL invariants |

## Extension Playbook

1. Re-read classify-intro, classify-auto, classify-ui-trust-center,
   classify-custom-using, classify-auto-exclude, classify-results,
   classify-troubleshooting, and tag-based-masking-policies.
2. Check Preview status of Autopilot and AI mode; update labels.
3. Change SQL in walkthrough.sql, run it twice on mwhitaker_aws (re-run
   proves idempotency), confirm tags and masked rows, then update README.
4. Run tests and `expire-projects.py --check`.

## Snowflake Objects

Roles PII_CLASSIFICATION_ADMIN, PII_ANALYST; warehouse
SFE_PII_CLASSIFICATION_WH; schemas SNOWFLAKE_EXAMPLE.PII_GOVERNANCE (tag
PII_SENSITIVITY, policy MASK_PII_STRING, classifier EMPLOYEE_IDS, profile
PII_PROFILE) and SNOWFLAKE_EXAMPLE.PII_DATA (table CUSTOMERS).

## Gotchas

- CREATE OR REPLACE on a profile still set on a database/schema fails with
  398036 "attached to one or more entities"; unset first (verified).
- SYSTEM$CLASSIFY with a profile that has auto_tag applies tags; with NULL it
  applies none (verified: tag_applied false, zero tag references).
- Setting any schedule key switches the profile to scheduling_mode CUSTOM
  and turns Autopilot off.
- Tag map: first matching entry wins; manual tag values are never
  overwritten (MANUALLY_APPLIED_VALUE_PRESENT tagging error).
- One masking policy per data type per tag; system tags cannot carry a
  masking policy; a direct column policy beats a tag-based one.
- Scheduled runs start about 1 hour after setting the profile;
  DATA_CLASSIFICATION_LATEST lags up to 3 more hours. Use
  INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS for immediate checks.
- Trust Center UI needs TRUST_CENTER_ADMIN or TRUST_CENTER_VIEWER;
  DATA_SECURITY_* roles alone are not enough.
