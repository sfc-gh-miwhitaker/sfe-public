> Simplified from: guide-agent-to-agent-orchestration/README.md

## One-Sentence Version

Snowflake has no special "agent bus" — to make one AI agent call another, you make the second agent look like a tool the first one can use.

## The Story (analogy-driven)

Imagine a team of specialists at a help desk. Each person has their own phone extension and their own set of reference binders. There's no switchboard operator routing calls automatically — if the billing specialist needs an answer from the shipping specialist, they just pick up the phone and dial shipping's extension directly.

That's agent-to-agent on Snowflake. Each agent has its own tools. To let Agent A call Agent B, you give Agent A a new tool that says "dial Agent B's extension and relay the answer back." The mechanism is a small saved function (`DATA_AGENT_RUN`) wrapped in a procedure. That's the whole trick.

For agents in separate installed applications, the story adds a security desk:

- By default, App B's agent has **zero** access to your data unless the admin explicitly grants it.
- Those grants **don't pass down the chain** — if A can see your sales data and calls B, B still can't see it unless B was independently granted access.

## The Cast (concept glossary)

- **Cortex Agent** — An AI assistant inside Snowflake that answers questions by reasoning and calling tools.
- **Tool** — One capability an agent can call (run a query, search documents, call a function).
- **DATA_AGENT_RUN** — A built-in function that runs a saved agent from SQL — the actual mechanism for one agent calling another.
- **Restricted Caller's Rights (RCR)** — A safety rule for installed apps: no data access unless explicitly granted.
- **MCP** — An open standard for AI tools to talk to each other; how agents reach outside systems.
- **CoWork** — The finished product for business users: a chat interface that quietly coordinates agents behind the scenes.

## What Changed

- Before: there was no documented way to have agents call agents in Snowflake.
- After: four patterns exist — same-account procedure calls (production-ready), cross-app agents with security controls (preview), MCP for external connectivity (production-ready), and CoWork for automatic coordination (production-ready).

## What to Watch Out For

- Permissions don't pass down the chain. If Agent A has data access and calls Agent B, B does NOT inherit that access. Each agent's permissions are checked independently. Teams routinely assume otherwise.
- Loops are capped at 10 hops. If agents accidentally call each other in a circle, Snowflake stops the chain after 10 calls.
- Google's A2A protocol has no native Snowflake support. You can bridge it with custom code, but there's no built-in interop.
- AI agents aren't perfectly repeatable. When you need guaranteed step-by-step behavior, drive calls from a scheduled task instead of letting one agent freely delegate.

## The One Thing to Remember

"One agent calling another" is just "an agent calling a tool" — the child agent is wrapped as a tool in the parent's list, and the whole thing uses existing permissions you already manage.

> For the full technical details, see the source document.
