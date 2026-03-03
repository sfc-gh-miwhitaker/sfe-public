# Guidance Hierarchy: Where Cortex Code Finds Its Instructions

Cortex Code (and compatible tools like Cursor and Claude Code) look for guidance in multiple locations, layered from broadest to narrowest scope. Higher layers override lower ones.

```mermaid
flowchart TB
    subgraph org ["Organization (IT-managed)"]
        ManagedSettings["managed-settings.json
        /Library/Application Support/Cortex/"]
    end

    subgraph user ["User (your machine)"]
        UserClaude["~/.claude/CLAUDE.md
        Always-on rules"]
        UserSkills["~/.claude/skills/
        Personal skills library"]
        UserCortex["~/.snowflake/cortex/skills/
        CoCo-specific skills"]
    end

    subgraph project ["Project (repo root)"]
        AgentsMd["AGENTS.md or CLAUDE.md
        Project context and standards"]
        ProjectSkills[".claude/skills/ or .cortex/skills/
        Project-specific skills"]
    end

    subgraph session ["Session (ephemeral)"]
        TempSkills["Temporary skills
        Added via /skill add"]
        SessionConfig["/plan mode, /model overrides
        Session-only settings"]
    end

    subgraph builtin ["Built-in"]
        BundledSkills["~11 bundled skills
        Semantic views, dbt, docs, etc."]
    end

    org -->|"overrides"| user
    user -->|"overrides"| project
    project -->|"overrides"| session
    session -->|"overrides"| builtin
```

## Always-On vs On-Demand

```mermaid
flowchart LR
    subgraph alwaysOn ["Always-On: Loaded Every Conversation"]
        A1["AGENTS.md / CLAUDE.md
        at project root"]
        A2["~/.claude/CLAUDE.md
        user-level rules"]
        A3["managed-settings.json
        org policy"]
    end

    subgraph onDemand ["On-Demand: Invoked Explicitly"]
        B1["Skills
        /skill list to see them"]
        B2["Subagents
        explore, plan, custom"]
        B3["MCP Tools
        GitHub, Jira, etc."]
    end

    alwaysOn -->|"sets the baseline"| AI["AI Behavior"]
    onDemand -->|"extends on request"| AI
```

## Shared Files Across Tools

```mermaid
flowchart TB
    subgraph shared ["Shared: Works in All Tools"]
        S1["AGENTS.md"]
        S2[".claude/skills/"]
        S3["~/.claude/CLAUDE.md"]
        S4["~/.claude/skills/"]
    end

    subgraph cocoOnly ["CoCo-Specific"]
        C1["~/.snowflake/connections.toml"]
        C2["~/.snowflake/cortex/settings.json"]
        C3[".cortex/skills/"]
        C4["~/.snowflake/cortex/skills/"]
    end

    shared --> CoCo["Cortex Code CLI"]
    shared --> Cursor["Cursor"]
    shared --> ClaudeCode["Claude Code"]

    cocoOnly --> CoCo
```

## Key Takeaway

Write your project guidance in `AGENTS.md` and your skills in `.claude/skills/` -- this ensures compatibility with Cortex Code CLI, Cursor, and Claude Code. Use `.cortex/`-specific paths only for CoCo-only functionality.
