# Distribution Channels

How governance configuration flows from central management to end users.

## Three-Tier Distribution Model

```mermaid
flowchart TB
    subgraph central ["Central Management"]
        Org["Organization Policy"]
        Team["Team Standards"]
        Templates["Project Templates"]
    end

    subgraph channels ["Distribution Channels"]
        subgraph orgChannel ["Org-Level (IT Pushed)"]
            MDM["MDM
            (Jamf, Intune)"]
            ConfigMgmt["Config Management
            (Ansible, Chef, Puppet)"]
            SCCM["SCCM / 
            Group Policy"]
        end

        subgraph userChannel ["User-Level (Self-Service)"]
            Curl["curl one-liner"]
            ZIP["ZIP download"]
            SkillAdd["/skill add git-url"]
            SharedDrive["Shared drive"]
        end

        subgraph projectChannel ["Project-Level (Team Managed)"]
            Git["Git clone"]
            ZIPProj["ZIP share"]
            Stage["Snowflake stage"]
            Wiki["Confluence/SharePoint"]
        end
    end

    subgraph targets ["Target Locations"]
        ManagedSettings["/Library/Application Support/Cortex/
        managed-settings.json"]
        UserFiles["~/.claude/
        CLAUDE.md + skills/"]
        ProjectFiles["<project>/
        AGENTS.md + .cortex/"]
    end

    Org --> MDM --> ManagedSettings
    Org --> ConfigMgmt --> ManagedSettings
    Org --> SCCM --> ManagedSettings

    Team --> Curl --> UserFiles
    Team --> ZIP --> UserFiles
    Team --> SkillAdd --> UserFiles
    Team --> SharedDrive --> UserFiles

    Templates --> Git --> ProjectFiles
    Templates --> ZIPProj --> ProjectFiles
    Templates --> Stage --> ProjectFiles
    Templates --> Wiki --> ProjectFiles
```

## Channel Selection Guide

```mermaid
flowchart TD
    Start["What are you distributing?"] --> Q1{Org policy?}
    
    Q1 -->|Yes| Q2{Have MDM?}
    Q2 -->|Yes| MDM["Use MDM
    (Jamf, Intune, SCCM)"]
    Q2 -->|No| ConfigMgmt["Use Config Management
    (Ansible, Chef, Puppet)"]
    
    Q1 -->|No| Q3{User standards?}
    Q3 -->|Yes| Q4{Users have terminal access?}
    Q4 -->|Yes| Curl["curl one-liner"]
    Q4 -->|No| ZIP["ZIP download + instructions"]
    
    Q3 -->|No| Q5{Project config?}
    Q5 -->|Yes| Q6{Team uses git?}
    Q6 -->|Yes| Git["Git repo
    (commit AGENTS.md)"]
    Q6 -->|No| Wiki["Wiki/SharePoint
    + manual copy"]
```

## Update Flow

```mermaid
sequenceDiagram
    participant Owner as Policy Owner
    participant Central as Central Repo
    participant MDM as MDM/Config Mgmt
    participant Devices as User Devices
    participant Users as End Users

    Owner->>Central: Update policy
    Central->>MDM: Push new version
    MDM->>Devices: Deploy config
    Note over Devices: managed-settings.json updated
    Devices->>Users: Banner shows new version
    
    Owner->>Central: Update user standards
    Central->>Central: Update download URL
    Owner->>Users: Notify via email/Slack
    Users->>Central: Pull new version
    Note over Users: ~/.claude/ updated
```

## Air-Gapped / High-Security Environments

```mermaid
flowchart LR
    subgraph secure ["Secure Environment"]
        SharedDrive["Network Share
        \\server\governance\"]
        
        subgraph files ["Configuration Files"]
            MS["managed-settings.json"]
            CM["CLAUDE.md"]
            SK["skills/"]
        end
    end

    subgraph users ["User Workstations"]
        U1["User 1"]
        U2["User 2"]
        U3["User 3"]
    end

    SharedDrive --> U1
    SharedDrive --> U2
    SharedDrive --> U3

    Note1["IT manually updates
    network share"] --> SharedDrive
    Note2["Users copy to
    local directories"] --> users
```

## Verification Points

```mermaid
flowchart LR
    subgraph verify ["How Users Verify"]
        V1["Banner text
        shows version"]
        V2["/skill list
        shows team skill"]
        V3["Test query
        enforces rules"]
    end

    subgraph report ["How IT Monitors"]
        R1["MDM compliance
        reports"]
        R2["Version in
        banner text"]
        R3["Periodic
        audits"]
    end
```
