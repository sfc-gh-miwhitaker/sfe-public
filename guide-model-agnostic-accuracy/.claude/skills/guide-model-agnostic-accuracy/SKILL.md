---
name: guide-model-agnostic-accuracy
description: "Best practices for semantic views and Cortex Agents achieving model-agnostic accuracy. Use when: configuring semantic views, building agents, optimizing accuracy, evaluating agents, model selection strategy."
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
|------|------|
| README.md | The complete guide with five sections, trust guidance, and appendix |
| AGENTS.md | Project-specific editing conventions |
| ELI5.md | Plain-language companion for non-technical stakeholders |

## Snowflake Objects

None. This is a documentation-only guide with no deployed infrastructure.

## Extension Playbook

### Adding a new section or practice

1. Identify the official doc URL that grounds the claim
2. Find a practitioner blog post that validates it in production
3. Write the "why" framing (cause-and-effect, not prescription)
4. Add the practice to the relevant section table
5. Add to the appendix checklist (practice only, no explanation)

## Gotchas

- Semantic view docs and agent docs use different terminology for the same concepts
  (e.g., "custom_instructions" in YAML vs "orchestration instructions" in agent spec)
- Blog posts may reference YAML-based semantic models (stage files) — the guide covers
  native semantic views (schema-level objects), which are the current recommended path
- Start Agent orchestration with `auto`; verify named models with `SHOW CORTEX BASE MODELS`
- Comparable evaluations must target a committed Agent version and pin one exact metric version
- Native Agent evaluations do not currently exercise MCP tools
- Official metrics should prefer governed certified sources, with grain and policy scope documented
- Certification uses `SNOWFLAKE.TAGS.CERTIFICATION_STATUS`; the legacy `SNOWFLAKE.CORE` tag is planned for deprecation
- Guide expiration: 2027-03-04
