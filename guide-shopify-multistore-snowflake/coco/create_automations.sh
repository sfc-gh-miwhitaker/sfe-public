#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEZONE="${SHOPIFY_AUTOMATION_TIMEZONE:-America/Los_Angeles}"

cortex automation create \
  --name shopify_pipeline_daily \
  --prompt-file "${PROJECT_ROOT}/coco/automation_daily.md" \
  --schedule "daily at 7am" \
  --timezone "${TIMEZONE}"

cortex automation create \
  --name shopify_pipeline_weekly \
  --prompt-file "${PROJECT_ROOT}/coco/automation_weekly.md" \
  --schedule "every Monday at 8am" \
  --timezone "${TIMEZONE}"

cortex automation create \
  --name shopify_pipeline_monthly \
  --prompt-file "${PROJECT_ROOT}/coco/automation_monthly.md" \
  --schedule "0 9 1 * *" \
  --timezone "${TIMEZONE}"

cortex automation list
