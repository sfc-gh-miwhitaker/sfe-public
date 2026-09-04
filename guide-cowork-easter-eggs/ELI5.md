> Simplified from: [Snowflake CoWork: The Easter Egg Compendium](README.md)

# Snowflake CoWork: What It Can Really Do

## One-Sentence Version

CoWork looks like a chat box, but it can investigate hard questions, remember reusable workflows, refresh saved charts, schedule reports, create files, connect to other systems, and enforce Snowflake permissions while it works.

---

## The Story

Imagine you hire a capable assistant. At first, you only ask quick questions. Later, you discover the assistant can research a problem for ten minutes, save a chart that stays connected to current data, email you a fresh report every Monday, package a workflow as a reusable skill, and turn the result into a PDF or presentation.

That is CoWork. The chat box is only the front door. The `+` menu, Artifacts hub, Automations tab, and agent settings expose the larger system.

Some features are generally available. Others are Preview and may change. Seeing a button does not mean every account has the same feature stage or configuration.

---

## The Cast

| Term | What it means |
|---|---|
| **Deep Research** | Breaks a hard question into smaller investigations and builds a cited report |
| **Extended Thinking** | Spends more reasoning effort on one answer and stays selected until turned off |
| **Artifact** | A saved chart or table whose query can run again with the viewer's permissions |
| **Shared conversation** | A static snapshot of a thread, not a live dashboard |
| **User Skill** | A personal, repeatable CoWork workflow created in chat or uploaded |
| **Automation** | A scheduled question that reruns with fresh data and currently delivers by email |
| **MCP Connector** | An admin-configured connection to an external tool; each user authorizes with OAuth |
| **Document generation** | Preview support for creating PDF and PowerPoint files from an analysis |
| **Chart policies** | Preview rules that control chart color, formatting, sorting, and axis ranges |
| **CoCo Skill Catalog** | A separate account catalog for sharing CoCo skills and plugins |

---

## What Most Users Miss

- Deep Research can take up to ten minutes and follow-up questions do not rerun the investigation.
- Web search is not automatic; the agent needs a separately enabled web-search tool.
- Artifacts are live references, but automatic refresh occurs after more than 12 hours since the viewer's last view, or when refreshed manually.
- Shared conversations are static snapshots and disappear when their source conversation is deleted.
- Automations support hourly, daily, weekly, and monthly schedules, but Preview delivery is email-only.
- User Skills and PDF/PowerPoint generation need the agent's code execution tool for scripted or file-producing work.
- MCP connectors are not zero setup. Admins create integrations, grants, and agent connections before users complete OAuth.
- The iOS app is GA. Android remains roadmap.

---

## What to Watch Out For

**Preview is not GA.** User Skills, Automations, chart templates and policies, and document generation are usable open previews, not finished GA contracts.

**Live does not mean constantly rerun.** An Artifact keeps its query and can refresh against current data. A shared conversation is only a snapshot.

**Permissions still matter.** File analysis, skills, automations, artifacts, and external tools run under Snowflake access controls. A feature cannot bypass data the user is not allowed to see.

**Budgets are not instant brakes.** CoWork budgets use credit thresholds and can take hours to enforce. Per-user quotas are the better fit for daily or monthly user limits.

**The catalog names are confusing.** CoWork User Skills are personal workflows. The Cortex Extension catalog distributes CoCo skills and plugins inside an account.

---

## Still Emerging

Personal Work Agent auto-routing, implicit memory behavior, multi-pane CoWork Dashboards, Cortex Sense, the Slack app, and Android are still in preview or roadmap stages. Verify availability before showing them as current account behavior.

---

## The One Thing to Remember

Press the `+` button, then check the feature label and prerequisites before promising what it can do.

---

> For technical details and official references, see the [source document](README.md).
