![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Status](https://img.shields.io/badge/Status-Active-success)

# Govern AI Coding Tools

A hands-on workshop teaching teams to govern AI coding tools like Cortex Code, Cursor, and Claude Code. Six steps, 75 minutes, and you walk out with a complete governance stack: org-level MDM policy, user-level standards, project-level guardrails, a red-team exercise, and a distribution playbook.

**Author:** SE Community
**Time:** ~75 minutes | **Steps:** 6 | **Result:** Complete governance stack + distribution playbook

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

IT leaders, team leads, and developers responsible for AI tool governance. You should already have Cortex Code installed -- this workshop teaches *governance*, not *usage*.

**New to Cortex Code?** [Install the CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) and read the [extensibility guide](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) first.

---

## Read the Source First

Cortex Code follows the same configuration model as Claude Code. Before starting this workshop, read the official documentation on the concepts we build on:

- **[Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings)** -- Configuration scopes (managed, user, project, local), managed policy deployment, and how scopes interact
- **[Claude Code Memory (CLAUDE.md)](https://docs.anthropic.com/en/docs/claude-code/memory)** -- How CLAUDE.md files work, writing effective instructions, and `.claude/rules/`
- **[Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills)** -- Skill format, creation, sharing, and invocation control

This workshop does not re-explain these concepts. It focuses on what the official docs don't cover: **enterprise deployment via MDM, Snowflake-specific standards, red-team testing, operational distribution, and dual-surface enforcement (CLI + Snowsight)**.

---

## The Workshop

| Step | What You Build | What's Unique Here |
|------|----------------|-------------------|
| [1. Visibility](prompts/01_visibility.md) | Inspect the hierarchy | CoCo-specific paths that extend Claude Code |
| [2. Org Policy](prompts/02_org_policy.md) | managed-settings.json + MDM | Cortex Code policy schema, Intune/Jamf/Ansible deployment |
| [3. User Standards](prompts/03_user_standards.md) | CLAUDE.md + team skill | Snowflake SQL standards (QUALIFY, sargable, secrets) |
| [4. Project Scope](prompts/04_project_scope.md) | AGENTS.md constraints | Snowflake RBAC, schema governance, business logic |
| [5. Assurance](prompts/05_assurance.md) | Red team exercise | Systematic validation of every governance layer |
| [6. Distribution](prompts/06_distribution_playbook.md) | Operational playbook | Onboarding, change management, emergency procedures |

### Artifacts You'll Build

| Artifact | Purpose |
|----------|---------|
| `managed-settings.json` | Org-level policy enforced by IT via MDM |
| `~/.claude/CLAUDE.md` | User-level standards applied every session |
| Team-standards skill | Procedural checks for credentials, destructive ops, naming |
| Project AGENTS.md | Per-project constraints and guardrails |
| Distribution playbook | How to onboard new users and projects |

---

## Quick Start

```bash
cd guide-ai-tool-rollout
cortex
```

Then open [WORKSHOP.md](WORKSHOP.md) and follow along -- or tell CoCo: *"Walk me through the governance workshop step by step."*

---

## Dual-Surface Deployment (CLI + Snowsight)

For teams using Cortex Code on both CLI and Snowsight, see the [dual-surface deployment guide](docs/dual-surface-deployment.md). It covers how `AGENTS.md` and skills in a GitHub repo are read automatically on both surfaces, and how GitHub's collaboration features (PRs, Issues, branch protection) become the standards management layer.

---

## References

| Resource | URL |
|----------|-----|
| Claude Code Settings (scopes, managed policy) | https://docs.anthropic.com/en/docs/claude-code/settings |
| Claude Code Memory (CLAUDE.md) | https://docs.anthropic.com/en/docs/claude-code/memory |
| Claude Code Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Cortex Code CLI Settings | https://docs.snowflake.com/en/user-guide/cortex-code/settings |
| Cortex Code Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Data Governance Skills | https://docs.snowflake.com/en/user-guide/governance-skills |
| Cortex Code CLI | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
