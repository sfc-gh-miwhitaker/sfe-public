![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--02--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake CoWork: The Easter Egg Compendium

Snowflake CoWork (`ai.snowflake.com`) is a governed, enterprise-ready AI work agent — and it does a lot more than answer data questions. This guide documents the **GA feature set** with emphasis on the moves that aren't obvious: the depth-mode toggles, the power-user menus, the configuration patterns that change how the agent thinks, and the capabilities that are live now but not yet famous.

Think of this as a field guide for the person who already knows CoWork exists but hasn't found the backslide-kickflip yet.

**Audience:** SEs, SAs, and CoWork admins who want to demo the full capability surface and know which levers to pull.

**Created:** 2026-08-04 | **Expires:** 2027-02-01 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use.

---

## The One-Paragraph TL;DR

CoWork is a multi-agent system with a single conversational face. Underneath that face is: a chart engine backed by the full Vega-Lite spec, an investigation mode (Deep Research) that runs parallel sub-queries for up to ten minutes, a persistent artifact layer that keeps charts alive without regenerating them, MCP connectors that reach into Slack/GDrive/Salesforce via OAuth, and a native iOS app that follows you everywhere. Most people use 20% of this. This guide covers the other 80% — what's GA today. A separate [What's Coming](#whats-coming) section covers the PrPr pipeline.

---

## Start Here

**Already know CoWork exists?** Start with [The `+` Menu](#1-the--menu-is-your-command-center) and [Deep Research](#2-deep-research--the-investigation-mode). Those two sections alone change most demos.

**About to show this to a customer?** Read [Common Misconceptions](#common-misconceptions-to-correct-in-demos) first. Fixing the "Deep Research includes web search" assumption before a demo will save you a live awkward moment.

**Configuring for an enterprise rollout?** Jump to [Admin Tricks](#admin-tricks) and [Chart Customization](#6-chart-customization--tell-the-agent-how-to-chart) for the patterns that separate a polished deployment from a default one.

---

## Surface Map (GA)

| Layer | What it is | Where to find it |
|---|---|---|
| Chat | Standard Q&A, follow-up threads | Main window |
| Agent picker | Choose a specific specialist agent | `+` menu → Agent |
| Deep Research | Multi-step investigation mode | `+` menu → Deep Research |
| Extended Thinking | Slower, more thorough single-answer mode | Toggle in chat window |
| File upload | Drop a PDF/XLSX/PPTX for ad-hoc analysis | `+` menu → Upload file |
| Artifacts | Saved, shareable, live-refreshing charts/tables | Artifacts tab in sidebar |
| Skill Catalog | Browse and install shared CoCo skills from within CoWork | `Catalog > Skills & Plugins` in Snowsight · `+` menu in CoWork |
| MCP Connectors | OAuth connections to Slack, Drive, Salesforce | Account admin → Settings |
| Mobile | Full-parity iOS app | App Store: "Snowflake CoWork" |

---

## What You Can Do Today

### 1. The `+` Menu Is Your Command Center

The unassuming `+` button to the left of the chat input is where most of the advanced surface lives. If a user has never pressed it, they've never left beginner mode.

What's in there (varies by account configuration):
- **Deep Research** — the mode for hard, multi-part questions
- **Upload file** — ad-hoc PDF/XLSX/PPTX/CSV analysis
- **Agent** — manually select and lock to a specific specialist agent
- **Skills** — browse and install skills from the Skill Catalog (see [Section 9](#9-skill-catalog--browse-and-install-shared-skills))

Most users don't know the `+` menu exists. Most demos don't show it. Show it.

---

### 2. Deep Research — The Investigation Mode

Standard chat asks a question and returns an answer. Deep Research **decomposes the question** into multiple sub-investigations, runs them in parallel across structured and unstructured data, and synthesizes everything into a **citable report** with every claim traced to its source.

**How to trigger it:** `+` menu → Deep Research. Up to 10 minutes; you get a progress view while it runs.

**Things that are non-obvious:**

- **Deep Research does not include web search automatically.** It only searches the data sources on the agent. To include web search in Deep Research, the web search tool must be explicitly enabled on the agent by an admin. This surprises customers who expect it to "just search the internet."
- **Follow-ups after Deep Research are fast.** Once the report is in the thread, follow-up questions like "break that down by region" run as standard chat turns — they don't re-trigger the full 10-minute investigation.
- **Extended Thinking stacks.** You can enable Extended Thinking at the same time as Deep Research. Combined mode = deeper per-step reasoning inside a wider multi-step investigation. Use it for the hardest questions.
- Deep Research runs **parallel sub-investigations** under the hood. The UI renders each one as a collapsible section in the thread, consistent across web, mobile, and Teams.

---

### 3. Extended Thinking — The Slow Lane (That's Often Worth It)

Extended Thinking tells the orchestrator to reason harder on a single answer — validating SQL logic, considering more join paths, and exploring more options before committing to an answer.

**How to trigger it:** Toggle in the chat window (the lightbulb/brain icon).

**The one thing everyone misses:** The setting **persists**. Once you turn it on, it stays on for subsequent messages. Turn it off if you're doing quick lookups.

Use it for: questions where you suspect the standard answer is wrong, complex SQL that involves multiple joins, or any question where you want to see more of the agent's reasoning.

---

### 4. File Upload — Your User Stage, Seamlessly

You can upload files directly in the chat window. The agent reads the content and uses it to answer questions or augment analysis against Snowflake data.

**What's supported:** CSV, DOCX, JSON, PDF, PPTX, TXT, XLSX. Up to **50 MB per file**, up to **5 files per thread**.

**Things that are non-obvious:**

- Uploaded files go to **your personal user stage** (`@~`). They persist for the life of the thread and are cleaned up when the thread is deleted or expires.
- Complex documents (PDFs with heavy formatting, for example) may trigger **Snowpark** on your default warehouse to process them. You may see warehouse spin-up.
- Files are subject to **standard Snowflake data governance** — same access controls as any other customer data. Uploaded documents are not readable by other users unless you share them.
- This is the right move for: "I just got an email with a spreadsheet — analyze it against our Q3 numbers."

---

### 5. Artifacts — Live Dashboards That Don't Need Regenerating

An Artifact is a chart or table that CoWork saves, not just renders. When you ask a question and CoWork generates a visualization, you can **save it as an Artifact**. It stays alive, respects your access controls, and can be shared with colleagues without them re-asking the question.

**Things that are non-obvious:**

- **The Artifacts gallery is on the CoWork home page.** It's below the fold on most screens — scroll down to find it.
- **Artifacts are live.** They refresh with new data each time they're opened. They're not screenshots.
- **Admins can disable sharing account-wide.** CoWork Settings → Data controls → toggle off "Sharing artifacts and chats." This is the kill switch for organizations not ready for peer-to-peer sharing.

---

### 6. Chart Customization — Tell the Agent How to Chart

CoWork's chart engine is backed by the full [Vega-Lite](https://vega.github.io/vega-lite/examples/) spec, which supports area charts, heatmaps, box plots, dual-axis charts, faceted small-multiples, error bars, and text annotations — well beyond bar/line/pie.

**What works today — Soft text guidance in Agent Instructions:**

Write natural language in the agent's orchestration instructions. Example:
```
Always prefer bar charts for category comparisons. Use a dual-axis chart when showing volume and rate together. Never use pie charts for more than 6 categories.
```

**Quick win (zero config needed):** Add this to any agent's orchestration instructions:
```
Whenever you can answer visually with a chart, always choose to generate a chart even if the user didn't specify to.
```
This single line makes CoWork chart-first by default, which is almost always what business users want.

> **More is coming:** Vega-Lite template deep-merge (enforce brand colors/styles per chart) and a viz policy engine (deterministic rules independent of the LLM) are in Private Preview. See [What's Coming](#whats-coming).

---

### 7. Verified Answers — The Green Shield

When a data team **certifies** a question-and-answer pair, users who ask a related question see a **green shield** on the response. This is the signal that says: "a human expert checked this; it's the official answer."

**Things power users do with this:**
- Certify the top 20 KPI questions first. Revenue definition, headcount, ARR. These are the questions that explode in Slack if the agent answers wrong.
- CoWork **proactively suggests** questions to verify based on what users are actually asking. Over time, more answers get the green shield without manual curation work.
- You can ask **"how was this answer generated?"** on any response (verified or not) to get a plain-language explanation of the data source, filters, and SQL logic the agent used.

---

### 8. MCP Connectors — The "No IT Ticket" Integrations

CoWork ships with GA MCP connectors for **Slack, Google Drive, and Salesforce**. Users connect them via OAuth — no admin-built custom tool, no IT ticket.

**The power user move:** These connectors turn CoWork into a cross-system work agent. The canonical journey:
> "Prep me for my 3pm customer call" → CoWork pulls usage data from Snowflake, reads the last 3 Slack threads with the customer, searches Google Docs for the last QBR, and synthesizes it all into a briefing.

**Important:** Web search is **separate** from MCP connectors and must be **explicitly enabled per agent** by an admin. It is not on by default and it is not part of Deep Research unless configured. Customers frequently assume it is.

---

### 9. Skill Catalog — Browse and Install Shared Skills

As of July 2026, CoWork and CoCo can discover and install shared skills directly through the Skill Catalog. Skills are packaged as **Cortex Extension objects** — shareable via a `snow://skill_catalog/...` URI — and can be browsed, certified, and governed at the account level.

**Where to find it:**
- **CoWork / CoCo in Snowsight:** `+` menu displays Local, Built-in, and Skill Catalog skills
- **Admin view:** `Catalog > Skills & Plugins` in Snowsight — usage counts, certification, RBAC

**Things that are non-obvious:**

- **Sharing is intra-account only.** Cross-account sharing of skills is not yet supported.
- **Access and discoverability are independent controls.** A skill can be shared with a specific role (not browsable by others) or published to PUBLIC and discoverable by everyone. These are separate toggles.
- **Certified badge.** Admins can certify a specific skill version — users browsing the catalog see the latest certified version first. Useful for distinguishing the "official" org skill from user-contributed variants.
- **Skill Catalog ≠ CoWork User Skills.** The catalog manages CoCo markdown skills (workflows for the coding agent). CoWork-native "create a repeatable workflow from conversation" is a separate feature still in PrPr. See [What's Coming](#whats-coming).

---

### 10. Mobile App — Full Parity, Voice Input, QR Login

The iOS app (App Store: "Snowflake CoWork") supports everything the web app does:
- All agents, Deep Research, Extended Thinking, file attachments
- **Voice input** — dictate your question
- **QR code login** — on the web app, trigger a QR from settings; scan with the phone app to authenticate instantly without re-entering credentials
- **iPad support** — works at tablet scale

Android availability is currently on the roadmap; several large enterprise customers are waiting on it.

---

### 11. Integration Surfaces — CoWork Is Bigger Than the Browser

CoWork isn't just `ai.snowflake.com`. It also appears as:
- **Teams integration** — fully functional via Microsoft Teams; some customers use this as their primary CoWork surface
- **Cortex Agent API** — the same engine that powers CoWork is publicly accessible. Any app, any surface.

---

## Admin Tricks

### The "Always Chart First" Agent Instruction

Add this to any agent's orchestration instructions:

```
Whenever you can answer visually with a chart, always choose to generate a chart even if the user didn't explicitly request one.
```

This single line dramatically improves the first-time user experience — most business users expect visualizations and don't think to ask for them.

### Name Your CoWork Instance

When a user asks "who are you?", CoWork identifies itself using the **SI Object name**. If you haven't renamed it, users see "Snowflake Intelligence." Rename the SI Object to something that fits your brand: "Acme Analytics," "FanGraph Intelligence," etc.

### Surfacing Suggested Prompts

CoWork will suggest follow-up prompts and conversation starters. These can be configured as part of agent instructions — seed them with the 5-10 questions your users most need answered to drive early adoption.

### Resource Budgets

CoWork supports **resource budgets** at the account level — set maximum token consumption limits before an alert fires. Essential for controlling cost before broad rollout. See `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` in ACCOUNT_USAGE for per-request telemetry.

---

## What's Coming

These features are in Private or Public Preview as of August 2026. Each is labeled with its current status; verify availability with your account team before promising them in a deal.

| Feature | What it does | Status |
|---|---|---|
| Personal Work Agent / auto-routing | Single entry point — CoWork routes to the right agent automatically, no picker required. Snowflake announced this at Summit 2026 as multi-agent orchestration "behind the scenes." | PrPr |
| User Skills (workflow creation) | Say "make this a repeatable skill" in a CoWork conversation to codify a multi-step workflow; invoke by name or from `+` menu. Separate from the GA Skill Catalog. | PrPr |
| User Memory | State a preference once ("always show numbers in millions"); CoWork applies it across all future sessions without being reminded. | PrPr |
| Automations | Turn any question into a scheduled subscription — re-run with fresh data on a cron, deliver by email or Slack. | Limited Preview |
| Conversation Sharing | Share a full thread (context + citations) with a colleague as a link; they can continue from where you left off. | Preview |
| CoWork Dashboards (Artifacts 2.0) | Analysts author a multi-pane dashboard in CoCo, publish it to CoWork. Business users consume it conversationally: "show me the Q3 dashboard," then ask follow-ups against any panel. | PrPr |
| Chart Customization Tier 2 — Vega-Lite templates | Inject a brand config block that deep-merges into every generated chart — enforce corporate colors, scales, and mark styles without overwriting data encoding. | PrPr |
| Chart Customization Tier 3 — Viz policy engine | Deterministic rules that fire independent of the LLM: enforce sort order, number format, axis range, specific color mappings per value. | PrPr |
| PDF / PPT / Google Doc generation | Ask CoWork to produce a finished file and get it back without leaving the chat. | Preview soon |
| Cortex Sense | Auto-generated context layer across your full data estate — feeds every CoWork and CoCo session automatically without manual semantic model authoring. | PrPr |
| Slack App | CoWork as a first-class Slack citizen with deep links back to full-context threads. | PrPr |
| Android mobile app | Full parity with iOS. | Roadmap |

---

## Common Misconceptions to Correct in Demos

| Misconception | Reality |
|---|---|
| "Deep Research includes web search" | Web search is a separate capability, configured per agent. Deep Research only searches agent data sources by default. |
| "Artifacts are just saved screenshots" | Artifacts are live — they refresh with current data every time they're opened and respect access controls. |
| "Extended Thinking resets every turn" | The toggle persists until you turn it off. Turn it off for quick lookups. |
| "Charts are limited to bar/line/pie" | Full Vega-Lite spec. Area, heatmap, dual-axis, box plot, faceted charts, error bars. Geographic maps are the only exception. |
| "File uploads go somewhere I can't see" | Files land in your user stage (`@~`). They follow standard Snowflake governance. |
| "MCP connectors include web search" | Web search must be explicitly enabled per agent by an admin. It is not bundled with the Slack/Drive/Salesforce connectors. |

---

## Related Guides

- [Snowflake CoWork documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork) — official feature reference
- [Cortex Agents overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents) — the underlying agent API that powers CoWork
- [Semantic views overview](https://docs.snowflake.com/en/user-guide/views-semantic/overview) — the data layer CoWork queries
- [Chart customization in CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/chart-customization) — Tier 1 chart instructions reference

---

## External References

- [Snowflake CoWork overview docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork)
- [Artifacts in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/artifacts)
- [Chart Customization](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/chart-customization)
- [Snowflake CoWork on the App Store](https://apps.apple.com/us/app/snowflake-intelligence/id6755540372)
- [Getting Started with Snowflake CoWork](https://www.snowflake.com/en/developers/guides/getting-started-with-cowork/)
- [Snowflake CoWork Summit 2026 announcement](https://www.snowflake.com/en/blog/snowflake-cowork-personal-work-agent/)
