---
name: guide-model-agnostic-accuracy
description: "Best practices for semantic views and Cortex Agents achieving model-agnostic accuracy. Use when: configuring semantic views, building agents, optimizing accuracy, evaluating agents, model selection strategy."
---

# Guide: Model-Agnostic Accuracy for Semantic Views and Cortex Agents

## Purpose

Reference guide for configuring Snowflake semantic views and Cortex Agents to produce
consistent, correct results regardless of which LLM is used for orchestration.

## Architecture

Single README.md with 5 sections:
1. Semantic View (making SQL generation deterministic)
2. Agent Configuration (making routing obvious)
3. Evaluation (diagnosing where accuracy breaks)
4. Model Selection (performance decision, not accuracy decision)
5. Iteration (building a feedback loop)

## Key Files

| File | Role |
|------|------|
| README.md | The complete guide with all 5 sections + appendix |
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
- The "auto" model recommendation is correct for agents but Cortex Analyst within agents
  has a separate model selection path (see Service Consumption Table)
