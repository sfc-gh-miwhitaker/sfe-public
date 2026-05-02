# Multi-Connection Workshop

**Audience:** Partner SEs working across multiple customer Snowflake accounts
**Goal:** Clean, isolated CoCo launch per project — right account, right context, every time
**Time:** ~45 minutes total

---

## How to Use This Guide

You can work through it two ways:

**With CoCo (recommended):**
Tell CoCo: *"Walk me through Part 1 of the multi-connection workshop."* It will read the prompt file, guide you step by step, and verify each piece as you go.

**Self-guided:**
Open each `prompts/` file in order and follow the instructions manually.

---

## The Parts

| # | File | What You Do | Output |
|---|------|-------------|--------|
| 1 | [01_anatomy.md](prompts/01_anatomy.md) | Inspect your current config.toml | Know what you have |
| 2 | [02_connections_setup.md](prompts/02_connections_setup.md) | Add one named connection per customer | `~/.snowflake/config.toml` |
| 3 | [03_cli_launch.md](prompts/03_cli_launch.md) | Learn every launch pattern | One-liner per project |
| 4 | [04_project_agents.md](prompts/04_project_agents.md) | Add connection hints to AGENTS.md | Project-locked context |
| 5 | [05_isolation.md](prompts/05_isolation.md) | Isolate memory and sessions | No cross-project bleed |

---

## Prerequisites

- Cortex Code CLI installed (`cortex --version` returns a version)
- At least one Snowflake account you can log into
- A text editor for editing `~/.snowflake/config.toml`

---

## Quick Reference Card

After completing all parts, your daily workflow will look like this:

```bash
# Start CoCo for a specific customer project
cortex -c acme-prod --workdir ~/projects/acme

# Or use a shell alias (set up in Part 3)
coco-acme

# Verify which account you're on
cortex connections list
```

Each project gets its own connection, its own AGENTS.md, and optionally its own memory path. No cross-customer contamination.
