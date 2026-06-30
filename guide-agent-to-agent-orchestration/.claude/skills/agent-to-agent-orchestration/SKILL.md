---
name: agent-to-agent-orchestration
description: "Guide to agent-to-agent orchestration on Snowflake. Use when: a customer or builder asks how one Cortex Agent calls another, DATA_AGENT_RUN vs AGENT_RUN, inter-app agents, RCR/GRANT CALLER, MCP servers as the interop fabric, CoWork multi-agent, or Google A2A on Snowflake."
---

# Agent-to-Agent Orchestration on Snowflake

## Purpose

Help SEs position, and builders implement, one Cortex Agent invoking another on Snowflake. Routes the reader to the right mechanism (same-account wrapper, inter-app, MCP, CoWork) and is honest about what isn't native (Google A2A). Companion working spec for the GA same-account case.

## Architecture

Two self-contained markdown docs, no deployable objects:

- `README.md` — decision tree + "Need → Use" table; the 5 layers; honest-gaps table; customer-framing section; references.
- `same-account-agent-to-agent.md` — illustrative working spec: child agent → `EXECUTE AS OWNER` wrapper proc → `DATA_AGENT_RUN` → parent agent `generic`/`procedure` tool, plus a gotchas table.

## Key Files

| File | Role |
|---|---|
| `README.md` | Router + positioning + the five layers + honest gaps |
| `same-account-agent-to-agent.md` | GA same-account working spec (4 steps + gotchas) |
| `AGENTS.md` | Project instructions + verified-facts list |

## The mental model (lead with this)

Snowflake ships **no proprietary agent-to-agent bus**. Every path makes the child agent look like a **tool** in the parent's plan→act loop — either a SQL wrapper proc calling `DATA_AGENT_RUN`, or an MCP server. "Agent → agent" and "agent → system" converge on the same two primitives.

## Decision shortcut

| Where do the agents live? | Path | Maturity |
|---|---|---|
| Same account | Wrapper proc + `DATA_AGENT_RUN` as a tool | GA |
| Different Native Apps | Inter-app agents (RCR + `GRANT CALLER`) | Preview (Open) |
| Reaching/exposing external systems | MCP (managed / SPCS / connectors) | GA (managed) |
| End-user "just ask" | CoWork + Cortex Sense | GA |
| Non-Snowflake framework (Google A2A) | Custom MCP bridge | No native A2A |

## Extension Playbook: add a new orchestration layer or mechanism

1. Confirm the mechanism against current docs first (this area changes monthly) — `snowflake_product_docs` for the exact DDL/function and its maturity label.
2. Decide if it's a *new layer* (add a `### N.` section in README's "The Layers") or a *new row* in the decision table — don't duplicate.
3. State maturity (GA / Preview) explicitly and add any new **gotcha** as its own callout (the value of this guide is the gotchas, not the syntax).
4. If it warrants runnable detail, add a sibling deep-dive `.md` (like `same-account-agent-to-agent.md`) and link it from the table — keep README a router.
5. Update the verified-facts list in `AGENTS.md` with the new claim + the date you checked it.

## Gotchas

- **Caller grants don't chain** through an owner's-rights wrapper proc — each RCR agent's grant requirement is independent. #1 inter-app design error.
- **`DATA_AGENT_RUN` (named) vs `AGENT_RUN` (objectless)** — for agent→agent use `DATA_AGENT_RUN`. Both are non-streaming.
- **Max recursion depth = 10** on MCP/agent loops — design tool graphs acyclic.
- **RCR enforcement began June 5, 2026** — past now; pre-cutoff Native App versions are grandfathered.
- **No native Google A2A** — never imply otherwise; it's a custom bridge only.
- The **`AGENT_RUN` "no tool execution"** report is a community claim, not documented — say "validate in POC," don't assert.
