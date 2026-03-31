# What Cortex Code Adds to the Claude Code Configuration Model

Cortex Code reads all the same configuration files as Claude Code. For the base model (scopes, CLAUDE.md, skills, managed settings), see [Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings) and [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory).

This diagram shows the Cortex Code-specific paths that extend the shared model.

```mermaid
flowchart TB
    subgraph shared ["Shared: Works in CoCo, Cursor, Claude Code"]
        S1["AGENTS.md"]
        S2[".claude/skills/"]
        S3["~/.claude/CLAUDE.md"]
        S4["~/.claude/skills/"]
    end

    subgraph cocoOnly ["Cortex Code Adds"]
        C1["~/.snowflake/connections.toml"]
        C2["~/.snowflake/cortex/settings.json"]
        C3[".cortex/skills/"]
        C4["~/.snowflake/cortex/skills/"]
        C5["/Library/Application Support/Cortex/managed-settings.json"]
    end

    shared --> CoCo["Cortex Code CLI"]
    shared --> Cursor["Cursor"]
    shared --> ClaudeCode["Claude Code"]

    cocoOnly --> CoCo
```

Write project guidance in `AGENTS.md` and skills in `.claude/skills/` for cross-tool compatibility. Use `.cortex/` paths only for CoCo-only functionality (Snowflake connections, CoCo settings).
