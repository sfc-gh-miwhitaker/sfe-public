---
name: guide-cowork-easter-eggs
description: "Guide for Snowflake CoWork power-user features and easter eggs. Covers the + menu, Deep Research, Extended Thinking, auto-routing (Personal Work Agent PrPr), Artifacts, three-tier chart customization (Vega-Lite + viz policies), User Skills, User Memory, MCP connectors, Automations, Verified Answers, file upload, iOS mobile, and what's in preview. Use when updating this guide, writing CoWork demos, explaining CoWork features, or debugging CoWork configuration."
---

# guide-cowork-easter-eggs

## Purpose
Field guide for SEs and CoWork admins covering the full CoWork feature surface — 15 features organized by surprise value, with a Common Misconceptions table for demo prep and a What's Coming tracker for preview features.

## Architecture

```
README.md (main guide)
├── Surface Map table — all features + where to find them in the UI
├── Features 1–15 (ranked: most-overlooked first)
│   ├── + menu (command center)
│   ├── Personal Work Agent / auto-routing (PrPr)
│   ├── Deep Research
│   ├── Extended Thinking
│   ├── File Upload
│   ├── Artifacts (live dashboards)
│   ├── Chart Customization (3 tiers)
│   ├── Verified Answers
│   ├── User Skills (PrPr)
│   ├── User Memory (PrPr)
│   ├── MCP Connectors
│   ├── Automations
│   ├── Conversation Sharing
│   ├── Mobile App (iOS)
│   └── Integration Surfaces (Teams, Slack app, API)
├── Admin Tricks section
├── Common Misconceptions table
├── What's Coming table (preview features)
├── Related Guides
└── External References

ELI5.md — plain-language companion for non-technical readers
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Main guide — 15 feature sections + tables |
| `ELI5.md` | Plain-language version for AEs, PMs, execs |
| `AGENTS.md` | Project instructions for AI assistants |

## Adding a New Feature Section

When CoWork ships a new capability and you need to add it to the guide:

1. Decide its **surprise value rank** relative to existing sections 1–15. The scale: 1 = "most people have no idea this exists," 15 = "everyone knows this."
2. Insert the new `### N. Feature Name` section at the appropriate rank.
3. Renumber following sections if inserting mid-list.
4. Write it with the standard pattern: 2-sentence intro → "**Things that are non-obvious:**" bullet list → any admin/config note in a blockquote.
5. If it's a Preview feature, label inline as `(PrPr)` and add a row to the **What's Coming** table.
6. Update the **Surface Map** table at the top.
7. Update the **Common Misconceptions** table if the feature has a predictable wrong assumption (most do).
8. Run `pre-commit run --files guide-cowork-easter-eggs/README.md` before committing.

## Snowflake Objects

N/A — this is a documentation-only guide. No Snowflake objects are created or managed by this project. The CoWork objects being described (agents, semantic views, automations) live in the user's own account, not in any project schema.

## Gotchas

- The "Deep Research does not include web search" misconception is the most important fact in the whole guide. It must stay in the Misconceptions table AND in the Deep Research section body. Both places.
- Preview feature labels rot fast. Check Snowflake release notes and the CoWork product team Slack at every expiry cycle (2027-02-01). Items in **What's Coming** move to GA, get renamed, or get cancelled.
- The auto-routing / Personal Work Agent section describes a singleton restriction (one CoWork object per account). The actual parameter name is internal/undocumented — describe the behavior, not the parameter, if asked about it.
- Chart customization Tier 2/3 is gated behind internal GS feature flags during PrPr rollout. Don't document those flag names; document the capability and label it Preview.
- The guide's "backslide-kickflip" framing is intentional and should be preserved in the intro. It's the positioning hook.
