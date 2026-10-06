# ELI5 — Cortex AI Access Control

Snowflake's AI features — the coding assistant (Cortex Code), the chat agents, the
ask-your-data tools, and the AI functions you call from SQL — are switched on for
everyone by default. This guide shows an admin how to decide who gets which parts,
turn the rest off, and then watch what people actually use.

Pair-programmed by SE Community + Cortex Code

## The short version

1. Decide how much AI each team really needs — all of it, just the SQL functions, or just the agents
2. Remove the default "everyone gets everything" permission
3. Give each team the narrower permission that matches its job
4. Separately, choose which AI models they can use
5. Optionally, cap how many credits each person can burn per day
6. Watch usage with the built-in SQL queries

## Four different dials, not one

People assume there is a single AI on/off switch. There are four, and they stack:

- **Which Cortex services** — a permission called `CORTEX_USER` gives everything.
  `AI_FUNCTIONS_USER` gives only the SQL functions. `CORTEX_AGENT_USER` gives only agents.
- **Which AI functions** — a separate account-level permission. You need this *and*
  one of the above. Having only one of the two looks exactly like having neither.
- **Which models** — controlled independently. A team can have full permission to
  call AI and still be refused every single model.
- **How much spend** — daily per-person credit caps for the coding assistant.

## Why would you do this?

- Control AI credit spend before it surprises you
- Give a new team the AI functions they asked for without also handing them agents,
  document search, and the full chat surface
- Keep expensive top-tier models restricted to the teams that need them
- Satisfy an internal approval process before rolling a new tool out

## What's the catch?

**Turning off the default permission is not enough on its own.** Two side doors stay
open, and both are common:

- **Secondary roles.** People can have more than one role active at a time. If any
  of the extra ones still has AI access, they still get in.
- **A blanket "import everything" grant.** Some roles are given wholesale access to
  Snowflake's shared database, which quietly includes the AI permission. Removing the
  AI permission from "everyone" does nothing for those roles — you have to fix them
  one at a time.

**Testing as the top-level admin proves nothing.** An ACCOUNTADMIN always gets
through, no matter what you switched off. Test as a normal role, with the extra
secondary roles switched off, or you will believe a lockdown worked when it didn't.

**Model restrictions need a special command.** There's a built-in grant that gives
everyone every model. A normal "revoke" does not remove it and it comes back after
an upgrade — you have to call a specific stored procedure instead.

**The monitoring views lag behind.** How far behind depends on which view you're
reading — there is no single number. Don't confirm a change by refreshing a usage
query; confirm it by trying an AI call as the affected role.

> For the full technical details, see `README.md`.
