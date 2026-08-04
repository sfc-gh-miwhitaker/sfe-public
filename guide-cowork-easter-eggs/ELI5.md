> Simplified from: [Snowflake CoWork: The Easter Egg Compendium](README.md)

# Snowflake CoWork: What It Can Really Do

## One-Sentence Version

CoWork looks like a chat box for asking data questions — but under the hood it's a full work agent with investigation modes, saved dashboards, automations, external tool connections, and a memory system, most of which most users have never touched.

---

## The Story

Imagine you hire an incredibly capable assistant. On day one, you learn they can answer questions about your data. So every morning you type questions and get answers. That's useful. But six months later you realize: this assistant could have been running your weekly reports automatically. They could have remembered that you always want numbers in millions. They could have connected to Slack and Salesforce and synthesized everything into a pre-call briefing. They could have saved your best analysis as a live dashboard that refreshes itself. You were using 20% of their capability.

That's CoWork. The chat box is real. The answers are good. But there's a full control panel behind the `+` button that most users never open — and this guide is the map to that panel.

The three deepest features are: **Deep Research** (where you ask a hard, multi-part question and CoWork runs a proper 10-minute investigation across all your data, with every claim cited), **Artifacts** (where charts stay alive and refresh automatically instead of disappearing when you close the tab), and **auto-routing** (coming soon in Private Preview — makes the whole experience feel like one smart assistant instead of a drawer full of specialized tools you have to pick from).

Everything else — scheduling, file uploads, branded charts, tool connections, mobile app — layers on top of those three.

---

## The Cast

| Term | What it actually means |
|------|------------------------|
| **CoWork** | Snowflake's AI work agent — lives at `ai.snowflake.com`, talks to your governed data |
| **`+` menu** | The button to the left of the chat input; this is where the advanced features live |
| **Deep Research** | Investigation mode — CoWork breaks a hard question into sub-questions, runs them all, and produces a citable report |
| **Extended Thinking** | A toggle that makes CoWork think harder and slower before answering; stays on until you turn it off |
| **Artifact** | A saved chart or table that stays live, refreshes with new data, and can be shared with a link |
| **Auto-routing agent** | A coming feature (Private Preview) — one invisible router that sends your question to the right specialist automatically, so you never have to pick an agent |
| **User Skills** | Macros you create in conversation: "run my Monday recap" becomes a one-click workflow |
| **User Memory** | CoWork remembers your preferences across sessions once you state them |
| **MCP Connectors** | OAuth connections to Slack, Google Drive, and Salesforce — no IT ticket, no custom code |
| **Automations** | Turn any question into a scheduled email or Slack message, re-run with fresh data |
| **Verified Answers** | Questions certified by your data team get a green shield — the official, trusted answer |
| **Chart tiers** | Three levels of chart control: ask in English → inject a brand style template → enforce deterministic rules |

---

## What Changed (What Most Users Don't Know Exists)

- The `+` menu next to the chat box opens Deep Research, file upload, agent selection, and Skills — most users never press it
- Charts support heatmaps, dual-axis, box plots, and faceted grids — not just bar/line/pie
- An uploaded PDF or spreadsheet goes to your personal file area and can be analyzed against your Snowflake data in the same thread
- Artifacts (saved charts) are live — they pull fresh data every time they're opened; they're not screenshots
- The iOS app has voice input and a QR code login — scan from the web app to authenticate instantly on your phone
- Conversations can be shared with a link that includes full context and citations, not just a copy-paste
- CoWork works in Microsoft Teams as a fully functional integration, not just a notification feed
- Deep Research does **not** automatically search the internet — web search is a separate option that must be enabled by an admin

---

## What to Watch Out For

**Deep Research and web search are separate.** This is the one thing that catches people off guard in live demos. Deep Research investigates your company data deeply. It does not browse the internet unless an admin has specifically enabled web search on the agent. Don't promise "it'll search the web" unless you've confirmed it's configured.

**Extended Thinking stays on.** Once you enable it, it applies to every following message. This is great for hard questions and annoying for quick lookups. Turn it off when you're done with the complex question.

**Artifacts 2.0 (full multi-pane dashboards) is still in Private Preview** as of this writing. The current GA version saves individual charts/tables. Full analyst-authored dashboards published to CoWork are coming but aren't generally available yet.

**Several of the best features are still in preview.** Auto-routing, User Memory, and User Skills are Private or Public Preview — available to accounts that are enrolled, not everyone by default. Check with your account team on what's enabled.

---

## The One Thing to Remember

Press the `+` button — the whole guide is basically a tour of what's in there and what it can do when properly configured.

---

> For the full technical details, see the [source document](README.md).
