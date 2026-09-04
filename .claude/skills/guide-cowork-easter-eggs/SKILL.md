---
name: guide-cowork-easter-eggs
description: "Guide for Snowflake CoWork power-user features and easter eggs. Covers the + menu, Deep Research, Extended Thinking, Personal Work Agent preview rollout, Artifacts, three-tier chart customization (Vega-Lite + viz policies), User Skills, User Memory, MCP connectors, Automations, Verified Answers, file upload, iOS mobile, and what's emerging. Use when updating this guide, writing CoWork demos, explaining CoWork features, or debugging CoWork configuration."
---

# guide-cowork-easter-eggs

## Purpose
Field guide for SEs and CoWork admins covering 15 status-aware CoWork capabilities, with current prerequisites, Common Misconceptions for demo prep, and a tracker for restricted-preview and roadmap features.

## Architecture

```
README.md (main guide)
├── Surface Map table — all features + where to find them in the UI
├── Features 1–15 (ranked: most-overlooked first)
│   ├── + menu (command center)
│   ├── Deep Research
│   ├── Extended Thinking
│   ├── File Upload
│   ├── Artifacts (live chart/table references)
│   ├── Shared Conversations (static snapshots)
│   ├── Chart Customization (3 tiers)
│   ├── User Skills (Preview)
│   ├── Automations (Preview, email delivery)
│   ├── MCP Connectors
│   ├── Document Generation (Preview)
│   ├── Verified Answers
│   ├── CoCo Skill and Plugin Catalog (Preview)
│   ├── Mobile App (iOS)
│   ├── Microsoft integration surfaces
│   └── Cost controls
├── Admin Tricks section
├── Common Misconceptions table
├── What's Still Emerging table (restricted preview and roadmap)
├── Related Guides
└── External References

WHAT-CAN-I-DO-NOW.md — outcome-based action menu with runnable prompts
ELI5.md — plain-language companion for non-technical readers
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Main guide — 15 feature sections + tables |
| `WHAT-CAN-I-DO-NOW.md` | Action-oriented menu of current outcomes, prompts, prerequisites, and troubleshooting |
| `ELI5.md` | Plain-language version for AEs, PMs, execs |
| `AGENTS.md` | Project instructions for AI assistants |

## Adding a New Feature Section

When CoWork ships a new capability and you need to add it to the guide:

1. Decide its **surprise value rank** relative to existing sections 1–15. The scale: 1 = "most people have no idea this exists," 15 = "everyone knows this."
2. Insert the new `### N. Feature Name` section at the appropriate rank.
3. Renumber following sections if inserting mid-list.
4. Write it with the standard pattern: short intro, operational details, prerequisites, and limitations.
5. If it is broadly usable Preview, label the numbered section `(Preview)`. If access is restricted or roadmap-only, add it to **What's Still Emerging** instead.
6. Update the **Surface Map** table at the top.
7. Update the **Common Misconceptions** table if the feature has a predictable wrong assumption (most do).
8. Run `pre-commit run --files guide-cowork-easter-eggs/README.md` before committing.

## Snowflake Objects

N/A — this is a documentation-only guide. No Snowflake objects are created or managed by this project. The CoWork objects being described (agents, semantic views, automations) live in the user's own account, not in any project schema.

## Gotchas

- The "Deep Research does not include web search" misconception is the most important fact in the whole guide. It must stay in the Misconceptions table AND in the Deep Research section body. Both places.
- Preview labels rot fast. Check public docs, release notes, and current internal launch signals at every expiry cycle (2026-12-04).
- The auto-routing / Personal Work Agent section describes a singleton restriction (one CoWork object per account). The actual parameter name is internal/undocumented — describe the behavior, not the parameter, if asked about it.
- Chart customization Tier 2/3 is publicly documented Preview. Do not document internal flags.
- The guide's "backslide-kickflip" framing is intentional and should be preserved in the intro. It's the positioning hook.
