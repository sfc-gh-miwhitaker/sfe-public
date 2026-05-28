# Right Tool for the Job: Decision Framework

Choose the extensibility mechanism that matches the scope and cost model you need. Each terminal node shows when to use it and how it affects your context budget.

```mermaid
flowchart TD
    Start["I need the agent to
    know or do something"] --> Q1{"Need it every session?"}

    Q1 -->|"Yes"| Q2{"Every project, or just one?"}
    Q1 -->|"No"| Q3{"What kind of capability?"}

    Q2 -->|"Every project"| ClaudeMd["~/.claude/CLAUDE.md
    Global always-on rules"]
    Q2 -->|"Just one project"| AgentsMd["AGENTS.md
    Project always-on context"]

    Q3 -->|"Multi-step procedure"| Skill[".cortex/skills/ or .claude/skills/
    On-demand skill"]
    Q3 -->|"External data"| MCP["MCP Server
    Live tool connection"]
    Q3 -->|"Parallel work"| Subagent["Subagent
    Isolated context window"]
```

## Cost Model

Each mechanism has a different impact on your context budget:

```mermaid
flowchart LR
    subgraph permanent ["Permanent Budget (every message)"]
        P1["CLAUDE.md
        Survives compaction"]
        P2["AGENTS.md
        Survives compaction"]
    end

    subgraph onDemand ["On-Demand Budget (when activated)"]
        O1["Skills
        Description evaluated per message
        Body loaded only when triggered"]
        O2["MCP Tools
        Schema loaded once
        Data per call"]
    end

    subgraph separate ["Separate Budget (own context)"]
        S1["Subagents
        Independent context window
        Zero impact on main session"]
    end
```

## When You've Picked the Wrong Tool

| Signal | Likely Misplacement | Better Fit |
|--------|--------------------:|:-----------|
| CLAUDE.md over 300 lines | Procedures in always-on rules | Extract to skills |
| Agent forgets conventions mid-session | Conventions in conversation only | Move to AGENTS.md |
| Skill fires but steps get skipped | Skill body too large (300+ lines) | Split skill + references/ |
| Skill fires when irrelevant | Description too vague | Narrow YAML description |
| Need data from GitHub/Jira/DB | Pasting data into conversation | Use MCP server |
| Two tasks block each other | Sequential in one session | Delegate to subagent |
