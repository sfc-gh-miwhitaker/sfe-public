> Simplified from: guide-cowork-only-users/README.md

## One-Sentence Version

There's no native "CoWork-only" user type in Snowflake — this guide shows the three-part workaround to give business users access to the AI chat interface without exposing the full data platform.

## The Story (analogy-driven)

Imagine a building with a lobby concierge desk (CoWork) and a full machine shop in the back (Snowsight/SQL). You want some visitors to only talk to the concierge — ask questions, get answers — without ever wandering into the machine shop.

There's no "lobby-only badge" you can buy. Instead, you do three things: give them a badge that only opens the concierge door (a restricted role), lock the machine shop entrance for their badge specifically (interface restriction), and tell the concierge which specialists they're allowed to ask (agent grants). If any one of these three is missing, the visitor silently gets more access than intended.

## The Cast (concept glossary)

- **CoWork** — Snowflake's AI chat interface for business users (formerly called Snowflake Intelligence).
- **COWORK_USER role** — A custom role you create that only grants access to the agent API, not the full data platform.
- **CORTEX_AGENT_USER** — The narrow database role that enables agent access specifically.
- **ALLOWED_INTERFACES** — A per-user setting that restricts which Snowflake surfaces they can reach (set to CoWork only).
- **CoWork object** — A Snowflake object that curates which agents appear in the CoWork interface.
- **DEFAULT_WAREHOUSE** — Required even though users never see it — agents need compute to run queries behind the scenes.

## What Changed

- Before: every Snowflake user could see the full platform, and giving someone agent access meant giving them everything.
- After: a three-part configuration pattern lets you provision users who can only reach the AI chat interface and see only the agents you choose.

## What to Watch Out For

- If any of the three parts is missing or reverted, users silently get more access. There's no single toggle that enforces this — you must maintain all three.
- The SQL commands still use "SNOWFLAKE_INTELLIGENCE" (the old product name). This is correct syntax, not a mistake.
- Users must have a default warehouse set, even though they never pick or see one. Without it, CoWork errors when agent tools try to run queries.
- By default, `CORTEX_USER` is granted to PUBLIC (all users). If you don't revoke it, existing users retain full Cortex access regardless of your new role setup.

## The One Thing to Remember

Send provisioned users to `https://ai.snowflake.com` — and remember that all three pieces (restricted role, interface lock, agent grants) must stay in place or the restriction silently breaks.

> For the full technical details, see the source document.
