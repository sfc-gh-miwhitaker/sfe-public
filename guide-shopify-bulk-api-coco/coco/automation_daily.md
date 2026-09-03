# Daily Shopify Pipeline Supervision

This is a read-only supervision run. Do not call the pull procedure, alter tasks, update
stores, or retrieve secrets.

1. Query `SHOPIFY_NATIVE.CONTROL.V_PIPELINE_HEALTH` and the last 24 hours of
   `PULL_RUN_LOG`.
2. Query zero-lag `SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY` for
   `DAILY_SHOPIFY_PULL`, pushing task/time filters into the table function.
3. For each failed or stale store, classify the first failing boundary using the
   troubleshooting playbook and cite the error/run ID.
4. Compare today's order count and net sales with the trailing 14-day same-weekday range.
   Flag anomalies; do not call them data loss without evidence.
5. Write a complete report (overwrite, do not append) to
   `/workspace/shopify/status-<current-date>.md`: lead with overall status, then affected
   stores, evidence, and the exact CoCo Desktop prompt to investigate each issue.
6. If everything is healthy, write a one-paragraph green report with last completion time
   and store count.
