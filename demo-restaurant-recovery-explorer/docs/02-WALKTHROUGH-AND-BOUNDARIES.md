# Walkthrough and Release Boundaries

Pair-programmed by SE Community + Cortex Code

## Demonstration Cases

| Selection | Intended learning |
| --- | --- |
| Mesa Vale / Copper Table | Breakfast losses, dated staffing association, unchanged hours, and descriptive peer gap can justify investigating a bounded service-coverage test. |
| Mesa Vale / Orchard Table | Reduced hours must be visible before interpreting every lost occasion as lower demand. |
| Mesa Vale / River Kitchen | Closure contributes to fleet change but is not an active restaurant recovery opportunity. |
| Mesa Vale / Summit Kitchen | Opening changes the comparison population; percentage change against a zero baseline is undefined. |
| Mesa Vale / Aspen Kitchen | An incomplete extract is excluded, not replaced by zero. |
| Mesa Vale / Willow Table | A positive total does not justify inventing a recovery problem. |
| Juniper Coast / Copper Grill | Shared peer decline does not support a uniquely restaurant-specific cause. |
| Cedar Basin / Aspen Terrace | A unique format has insufficient peers; investigation is the correct outcome. |

These are fictional generator scenarios for testing the workflow. They are not discovered facts about actual businesses. The application reads measured fixture observations, not this walkthrough, when selecting brief outcomes.

## Public Package

The root README links to the runnable demo source. The reader-site build publishes Markdown documentation under its existing policy, not application code, dependencies, or project instructions. The application is not embedded or deployed by changing the catalog.

## Local Operation

The server binds to `127.0.0.1` and uses port 3217. It does not open database connections, read Snowflake credential files, or call an external AI service. Stop the foreground start script with Ctrl+C; no Snowflake teardown is needed.

Markdown exports are local downloads. They include synthetic disclosure, filter context, revision/snapshot identifiers, and evidence. The application never sends them or activates campaigns.

## Explicitly Deferred

- Snowflake resource creation, live data adapter, deployment manifest, cloud deployment, and share grants.
- AI narration, natural-language querying, model selection, or open-ended recommendations.
- Guest identity, loyalty, acquisition/retention analysis, external foot traffic, drive times, and real trade areas.
- Experiment execution, margin modeling, power calculations, activation, and messaging.

For any Snowflake extension, approve a demo account, explicit connection, role, resource scope, and costs first. Store actual target details only in local configuration. The existing IDE account is never a deployment default for this project.
