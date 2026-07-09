> Simplified from: guide-cortex-agent-versioning/README.md

## One-Sentence Version

Snowflake gives AI agents a built-in versioning system — you develop on a mutable draft, freeze it into an immutable snapshot when it works, label that snapshot "production," and roll back by moving the label.

## The Story (analogy-driven)

Think of your agent's configuration as a recipe you're perfecting. You keep a working copy on the kitchen counter (LIVE) that you scribble changes on. When the recipe tastes right, you photocopy it and file it in a binder (VERSION$1, VERSION$2, etc.) — once filed, nobody can change those pages.

You put a sticky note labeled "production" on the page your restaurant currently serves from. If tonight's special gets complaints, you peel the sticky note off and stick it on yesterday's page. Dinner is fixed in seconds.

The catch: the moment you photocopy your working copy into the binder, the working copy on the counter disappears. You have to pull a fresh sheet from the binder to keep scribbling. Forget that step and you have no draft to work on.

Two teams operate this differently:

- **Solo cooks** — scribble on the counter, photocopy when ready.
- **Restaurant chains** — keep the master recipe in a shared Google Doc (GitHub), only add a page to the binder after the head chef approves the edit (pull request).

## The Cast (concept glossary)

- **LIVE version** — The mutable working draft of your agent; the thing you edit during development.
- **VERSION$N** — An immutable, numbered snapshot that never changes once created.
- **Alias** — A human-readable label (like "production") you stick on a version to direct traffic to it.
- **DEFAULT** — The version that gets used when a caller doesn't specify which version they want.
- **COMMIT** — The act of freezing LIVE into the next VERSION$N. Destroys LIVE in the process.
- **Git repository object** — A Snowflake mirror of a GitHub repo that Snowflake can read spec files from.

## What Changed

- Before: you edited an agent and hoped the change worked. No way to roll back except manually remembering what the old config was.
- After: every known-good state is preserved as an immutable version. Rolling back is one command. Git integration adds code review and CI/CD on top.

## What to Watch Out For

- COMMIT destroys LIVE. If you forget to recreate LIVE afterward, you have no draft to develop on. This trips up everyone the first time.
- DEFAULT_VERSION does not accept alias names — you must use the system ID (like 'VERSION$3').
- DESCRIBE AGENT shows the default version after you commit, not LIVE. This is misleading during development.
- The spec file in Git must be named exactly `agent_spec.yaml` — anything else is ignored.

## The One Thing to Remember

Always follow a COMMIT with `ADD LIVE VERSION ... FROM LAST` — otherwise you've frozen your agent and lost the ability to keep developing.

> For the full technical details, see the source document.
