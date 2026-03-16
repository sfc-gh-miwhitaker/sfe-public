# Progressive Unlock Flow

```mermaid
stateDiagram-v2
    [*] --> Blocked: Initial State

    state "MCP Blocked" as Blocked {
        note right of Blocked
            No managed-settings.json deployed
            Agent reports NOT READY
            GitHub tools unavailable
        end note
    }

    state "Governance Deployed" as Governed {
        note right of Governed
            managed-settings.json active
            Banner: Managed by IT
            Bypass mode disabled
            Agent reports PARTIAL
        end note
    }

    state "MCP Configured" as Connected {
        note right of Connected
            mcp.json with GitHub server
            1Password or PAT auth
            Agent reports PARTIAL→READY
        end note
    }

    state "Toolsets Scoped" as Scoped {
        note right of Scoped
            Only approved toolsets enabled
            Audit trail complete
            Agent reports READY
            GitHub integration active
        end note
    }

    Blocked --> Governed: IT deploys managed-settings.json
    Governed --> Connected: Developer configures mcp.json
    Connected --> Scoped: Admin selects toolset profile
    Scoped --> [*]: Full governance + GitHub
```
