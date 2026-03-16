# Governance Hierarchy

Visual representation of how Cortex Code finds and applies governance rules.

## Priority Order (Highest to Lowest)

```mermaid
flowchart TB
    subgraph org ["1. Organization (Highest Priority)"]
        ManagedSettings["managed-settings.json
        ─────────────────
        macOS: /Library/Application Support/Cortex/
        Linux: /etc/cortex/
        ─────────────────
        IT deploys via MDM
        Users CANNOT override"]
    end

    subgraph user ["2. User Level"]
        UserClaude["~/.claude/CLAUDE.md
        Always-on rules"]
        UserSkills["~/.claude/skills/
        Personal skills library"]
        UserCortex["~/.snowflake/cortex/
        CoCo settings & skills"]
    end

    subgraph project ["3. Project Level"]
        AgentsMd["AGENTS.md
        Project constraints"]
        ProjectSkills[".cortex/skills/
        Project-specific skills"]
    end

    subgraph session ["4. Session Level"]
        SessionSkills["Temporary skills
        via /skill add"]
        SessionConfig["/plan mode
        Model overrides"]
    end

    subgraph builtin ["5. Built-in (Lowest Priority)"]
        BundledSkills["~50+ bundled skills
        semantic-view, dbt, governance, etc."]
    end

    org -->|"overrides"| user
    user -->|"overrides"| project
    project -->|"overrides"| session
    session -->|"overrides"| builtin
```

## What Each Layer Controls

```mermaid
flowchart LR
    subgraph controls ["Governance Controls by Layer"]
        direction TB
        
        subgraph orgControls ["Org Layer"]
            O1["Bypass prevention"]
            O2["Account restrictions"]
            O3["Version requirements"]
            O4["Sandbox enforcement"]
        end
        
        subgraph userControls ["User Layer"]
            U1["SQL quality rules"]
            U2["Security standards"]
            U3["Destructive op warnings"]
            U4["Review workflows"]
        end
        
        subgraph projectControls ["Project Layer"]
            P1["Schema restrictions"]
            P2["Role discipline"]
            P3["Business logic"]
            P4["Naming conventions"]
        end
    end
```

## Always-On vs On-Demand

```mermaid
flowchart LR
    subgraph alwaysOn ["Always-On (Every Conversation)"]
        A1["managed-settings.json"]
        A2["~/.claude/CLAUDE.md"]
        A3["AGENTS.md"]
    end

    subgraph onDemand ["On-Demand (Invoked Explicitly)"]
        B1["Skills"]
        B2["Subagents"]
        B3["MCP tools"]
    end

    alwaysOn -->|"sets baseline"| AI["AI Behavior"]
    onDemand -->|"extends when needed"| AI
```

## Key Insight

**Higher layers can't be overridden by lower layers.**

- A user can't bypass org policy (managed-settings.json)
- A project can't override user standards (~/.claude/CLAUDE.md)
- Session settings don't persist beyond the session

This is intentional: IT can enforce policy without trusting individual users or projects.
