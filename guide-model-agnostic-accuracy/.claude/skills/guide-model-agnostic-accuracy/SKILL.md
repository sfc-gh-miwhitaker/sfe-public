---
name: guide-model-agnostic-accuracy
description: "Maintain the model-agnostic accuracy guide for semantic views and Cortex Agents. Use when editing this guide's SQL-accuracy practices, evaluation methodology, model-selection guidance, or plain-language companion."
---

# Guide: Model-Agnostic Accuracy for Semantic Views and Cortex Agents

Pair-programmed by SE Community + Cortex Code

## Purpose

Reference guide for configuring and evaluating Snowflake semantic views and Cortex Agents
to reduce avoidable model sensitivity and diagnose regressions across model changes.

## Architecture

README.md with five numbered sections plus trust guidance:

1. Semantic View (reducing SQL-generation ambiguity)
2. Agent Configuration (making routing intent explicit)
3. Evaluation (isolating Analyst and Agent failures)
4. Model Selection (measured performance and quality decision)
5. Iteration (building a feedback loop)

The unnumbered mental-model section includes governed-source certification, grain,
provenance, and policy scope.

## Key Files

| File | Role |
| ------ | ------ |
| README.md | The complete guide with five sections, trust guidance, and appendix |
| AGENTS.md | Project-specific editing conventions |
| ELI5.md | Plain-language companion for non-technical stakeholders |

## Snowflake Objects

None. This is a documentation-only guide with no deployed infrastructure.

## Workflow

1. Read README.md, ELI5.md, and AGENTS.md in this project before proposing edits.
2. Check the affected feature in current official Snowflake documentation, including
   release notes for pending evaluation-default changes and judge retirements.
3. Report the exact correction and its source. Apply edits when the user has
   authorized them; keep evaluation advice distinct from executable configuration.
4. Update affected practice summaries, appendix items, and plain-language explanations.
5. Run the repository checks listed in AGENTS.md and inspect the scoped diff.

## Adding a New Section or Practice

1. Identify the official documentation URL that grounds the claim.
2. Add practitioner evidence when available, without treating it as product-status authority.
3. Explain why the practice matters, then add it to the relevant section table.
4. Add the practice to the appendix checklist and update ELI5.md if its main story changes.

## Stopping Points

For audit-only requests, stop after findings and proposed edits. Existing approval
covers the agreed edits; ask only if a new decision materially changes their scope.
This guide's maintenance workflow does not deploy objects or launch evaluations.

## Output

Return the changed files, validation results, and unresolved limitations. An audit
returns findings with file locations and sources rather than repository edits.

## Gotchas

- Semantic-view `module_custom_instructions.sql_generation` and
  `question_categorization` have different scopes from Agent
  `instructions.orchestration` and `instructions.response`. Migrate legacy
  `custom_instructions` to `module_custom_instructions.sql_generation`; these
  fields are not interchangeable. See the README's custom-instructions reference.
- Blog posts may reference YAML-based semantic models (stage files) — the guide covers
  native semantic views (schema-level objects), which are the current recommended path
- Start Agent orchestration with `auto`; check named models with
  `SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS` and verify feature support separately
- Comparable evaluations must target a committed Agent version and pin one exact metric version
- Native Agent evaluations do not currently exercise MCP tools
- Official metrics should prefer governed certified sources, with grain and policy scope documented
- Certification uses `SNOWFLAKE.TAGS.CERTIFICATION_STATUS`; the legacy `SNOWFLAKE.CORE` tag is planned for deprecation
- Analyst evaluations withhold all selected VQRs together; compare runs using the same selection
- Metric failures identify investigation paths, not unique root causes
- Judge retirement can invalidate pinned evaluations; check system metric versions and custom models separately
- Read review and expiry dates from the README header rather than duplicating them here
