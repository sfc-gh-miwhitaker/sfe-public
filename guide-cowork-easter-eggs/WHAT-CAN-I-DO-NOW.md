# What Can I Do Now in CoWork?

An action menu for readers of the [CoWork feature guide](README.md). Choose an
outcome, check its prerequisites, then try the prompt with data you are authorized
to use. These examples reorganize the guide; they do not certify that a feature
is enabled in your account or refresh its technical verification date.

**Audience:** CoWork users and SEs preparing a walkthrough.

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use.
> Availability and limitations follow the [Surface Map](README.md#surface-map).

## Start Here

| I want to... | Start with | Check first |
| --- | --- | --- |
| Understand a metric | Ask a focused question in chat | The selected agent has the relevant data and you have access. |
| Investigate why something changed | [Deep Research](README.md#2-deep-research----the-investigation-mode) | Relevant sources are configured; web search is separate. |
| Analyze a document | [File upload](README.md#4-file-upload----thread-scoped-working-context) | The file is approved for upload and meets the guide's limits. |
| Revisit a chart or table | [Artifacts](README.md#5-artifacts----live-references-not-screenshots) | Artifact sharing is permitted; recipients need underlying data access. |
| Share the reasoning from a conversation | [Shared conversations](README.md#6-shared-conversations----static-shareable-context) | A static snapshot, rather than a live result, is appropriate. |
| Repeat a workflow | [User Skills](README.md#8-user-skills----reusable-personal-workflows-preview) | Preview access and required agent tools are available. |
| Receive recurring updates | [Automations](README.md#9-automations----fresh-reports-by-email-preview) | Preview access, required privileges, and a verified email address. |
| Turn findings into a deliverable | [Document generation](README.md#11-document-generation----pdf-and-powerpoint-preview) | Preview access and the agent's code execution tool are enabled. |

## Try a Focused Question

Use a topic covered by your selected agent. This prompt avoids guessing a table
or business definition:

```text
Which business questions can you answer from your configured sources? Suggest
three starting questions and identify the source for each. Do not assume access
to data or tools that are not configured.
```

Choose one suggestion. Inspect the answer's sources and query before relying on
it. See [Verified Answers](README.md#12-verified-answers----the-trust-signal) for
the difference between reviewed query paths and ordinary generated answers.

## Investigate a Change

Select Deep Research from the `+` menu, then ask:

```text
Investigate the largest change in the metric we just discussed. Compare the last
two complete periods. Separate measured facts from possible explanations, cite
the supporting sources, and identify what evidence is missing. Do not treat a
correlation as proof of cause.
```

If sources are missing, check the agent configuration rather than assuming a
more detailed prompt will make them available. Deep Research does not
automatically enable internet search.

## Work With an Approved File

Upload a suitable file, then ask:

```text
Summarize this document's main decisions, unresolved questions, and next actions.
Cite the relevant passages. If an owner or deadline is absent, mark it as missing
rather than inventing one.
```

Keep sensitive material within your organization's approved handling rules.
Uploaded context is thread-scoped; see the [file-upload section](README.md#4-file-upload----thread-scoped-working-context)
for retention and access details.

## Reuse a Successful Analysis

Start from a result you have already checked. Choose the appropriate output:

- Save a chart/table artifact when you need to revisit the result.
- Share a conversation only when its static snapshot is the intended output.
- Use a personal skill for a repeatable workflow with the same structure.
- Create an automation only after confirming the question, schedule, and delivery.

For a skill draft:

```text
Draft a reusable skill for the analysis we just completed. Preserve its business
definitions, required inputs, source checks, and output structure. List the tools
it requires. Show me the draft before creating it.
```

For an automation proposal:

```text
Propose a weekly email update using the question we just validated. Include the
reporting period, sources, and what should happen when data is missing. Ask me to
confirm the schedule and timezone before creating the automation.
```

These prompts do not bypass Preview enrollment, privileges, or tool setup. CoWork
User Skills and the CoCo Skill Catalog are separate features.

## Package Reviewed Findings

With document generation enabled, ask:

```text
Create a concise PDF brief from the findings we have reviewed. Include the main
conclusion, supporting evidence, source references, and unresolved questions.
Do not add unsupported facts or send the file to anyone.
```

Review the output before distributing it. For recurring styling or a deck,
follow the [document-generation section](README.md#11-document-generation----pdf-and-powerpoint-preview).

## If Something Is Missing

| Symptom | First check |
| --- | --- |
| A menu item is absent | Check the Surface Map, agent configuration, and account availability with an administrator. |
| A source cannot be queried | Confirm the selected agent, configured sources, and your current permissions. |
| A connected service is unavailable | Check administrator setup and your Sources-panel authorization; see [MCP connectors](README.md#10-mcp-connectors----governed-connections-not-zero-setup). |
| A saved conversation looks stale | Shared conversations are static; use the appropriate artifact refresh flow for a chart or table. |
| An automation or document request fails | Check the prerequisites in its guide section before retrying. |

Before a demo, read [Common Misconceptions](README.md#common-misconceptions-to-correct-in-demos).
For an account rollout, use [Admin Tricks](README.md#admin-tricks) and the
[cost-control guidance](README.md#15-cost-controls----budgets-quotas-and-usage-history).
