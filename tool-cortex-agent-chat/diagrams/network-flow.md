# Network Flow - Cortex Agent Chat (React UI)

Author: SE Community
Last Updated: 2025-12-15
Expires: 2026-01-14 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows the network architecture and connectivity between the React application, Snowflake REST API, and Cortex Agent services, including security boundaries and protocols.

```mermaid
graph TB
    subgraph dev [Development Environment - localhost]
        Dev[Developer Machine<br/>IP: 192.168.1.x]
        Browser[Web Browser<br/>:80 or :443]
        React[React Dev Server<br/>:3001 HTTP]
        Backend[Express Proxy<br/>:4000 HTTP]
        Files[Local Filesystem<br/>.env.local (frontend)<br/>.env.server.local (backend)]
    end

    subgraph network [Network Layer]
        FW[Corporate Firewall<br/>Outbound HTTPS]
        DNS[DNS Resolution<br/>*.snowflakecomputing.com]
    end

    subgraph snowflake [Snowflake Cloud - account.snowflakecomputing.com]
        LB[Load Balancer<br/>:443 HTTPS]
        API[REST API Gateway<br/>TLS 1.2+]

        subgraph security [Security Layer]
            RBAC[Role-Based Access<br/>SYSADMIN grants]
        end

        subgraph compute [Compute Layer]
            WH[Warehouse<br/>SFE_TOOLS_WH<br/>X-SMALL]
        end

        subgraph services [Service Layer]
            Schema[Schema<br/>SFE_CORTEX_AGENT_CHAT]
            Agent[Cortex Agent<br/>SFE_REACT_DEMO_AGENT]
            Cortex[Cortex AI Service<br/>Managed LLM]
        end
    end

    Dev -->|HTTP| React
    React -->|HTTP /api/...| Backend
    Backend -->|HTTPS :443<br/>KEYPAIR_JWT| FW
    FW -->|HTTPS :443| DNS
    DNS -->|Resolved IP| LB
    LB -->|TLS Handshake| API
    API -->|Validate JWT| RBAC
    RBAC -->|Allocate| WH
    WH -->|Execute| Schema
    Schema -->|Invoke| Agent
    Agent -->|Process| Cortex
    Agent -->|Return| API
    API -->|HTTPS/SSE| Backend
    Backend -->|HTTP| React
    React --> Browser
    Files -.->|Load config| React
    Files -.->|Load secrets| Backend

    style Dev fill:#e1f5ff
    style Browser fill:#fff4e1
    style React fill:#e8f5e9
    style Backend fill:#e8f5e9
    style FW fill:#ffebee
    style API fill:#f3e5f5
    style Agent fill:#e3f2fd
    style Cortex fill:#e8eaf6
```

## Component Descriptions

### Development Environment

**Developer Machine**
- Purpose: Local development workstation
- Technology: macOS, Linux, or Windows
- Location: Developer's network
- Dependencies: Internet connectivity, modern OS
- Network: Outbound HTTPS required (port 443)

**Web Browser**
- Purpose: Renders React UI and handles HTTP requests
- Technology: Chrome, Firefox, Safari, Edge (modern versions)
- Location: localhost
- Dependencies: JavaScript enabled, local storage
- Ports: HTTP :80, HTTPS :443 (for external requests)

**React Dev Server**
- Purpose: Serves React application during development
- Technology: Create React App development server (Webpack)
- Location: localhost:3001
- Dependencies: Node.js 14+, npm packages
- Ports: HTTP :3001 (configurable)

**Backend Proxy (Express)**
- Purpose: Signs KEYPAIR_JWT tokens and proxies all Snowflake REST calls
- Technology: Node.js + Express
- Location: localhost:4000
- Dependencies: `.env.server.local` for Snowflake account, user, private key
- Ports: HTTP :4000 (configurable)

**Local Filesystem**
- Purpose: Stores configuration and credentials
- Technology: `.env.local` (frontend, no secrets) and `.env.server.local` (backend, contains private key)
- Location: Project root directory
- Dependencies: None
- Security: Must not be committed to version control; private key only in `.env.server.local`

### Network Layer

**Corporate Firewall**
- Purpose: Outbound traffic filtering and security
- Technology: Enterprise firewall (varies)
- Location: Network perimeter
- Dependencies: HTTPS outbound allowed to Snowflake
- Ports: :443 outbound required
- Configuration: Allow `*.snowflakecomputing.com`

**DNS Resolution**
- Purpose: Resolves Snowflake account hostnames
- Technology: DNS (Domain Name System)
- Location: Corporate or public DNS servers
- Dependencies: Connectivity to DNS servers
- Resolution: `{account}.snowflakecomputing.com` → IP address

### Snowflake Cloud

**Load Balancer**
- Purpose: Distributes incoming REST API requests
- Technology: Snowflake managed load balancer
- Location: Snowflake cloud infrastructure
- Dependencies: TLS certificates, health checks
- Ports: :443 HTTPS
- Protocol: TLS 1.2 or higher

**REST API Gateway**
- Purpose: Handles REST API requests and routing
- Technology: Snowflake REST API v2
- Location: `https://{account}.snowflakecomputing.com/api/v2/`
- Dependencies: Valid authentication, request validation
- Endpoints: `/databases/{db}/schemas/{schema}/agents/{agent}:run`

### Security Layer

**KEYPAIR_JWT Validation**
- Purpose: Validates RS256 JWT signed by backend proxy
- Technology: Snowflake authentication service
- Location: Snowflake identity platform
- Headers: `Authorization: Bearer <jwt>` and `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT`

**Role-Based Access Control (RBAC)**
- Purpose: Validates user permissions for agent usage
- Technology: Snowflake grants and roles
- Location: Access control metadata
- Dependencies: USAGE grant on agent, appropriate role
- Required Grants: `GRANT USAGE ON AGENT ... TO ROLE`

### Compute Layer

**Warehouse (SFE_TOOLS_WH)**
- Purpose: Provides compute resources for operations
- Technology: Snowflake virtual warehouse
- Location: Snowflake compute layer
- Dependencies: Active warehouse, available credits
- Size: X-SMALL (sufficient for agent operations)
- Auto-suspend: 60 seconds

### Service Layer

**Schema (SFE_CORTEX_AGENT_CHAT)**
- Purpose: Logical container for agent objects
- Technology: Snowflake schema
- Location: `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT`
- Dependencies: Database existence, schema permissions

**Cortex Agent (SFE_DEMO_AGENT)**
- Purpose: Conversational AI agent instance
- Technology: Snowflake Cortex Agent
- Location: Within schema
- Dependencies: Cortex service enabled, agent instructions

**Cortex AI Service**
- Purpose: Managed LLM inference service
- Technology: Snowflake Cortex AI platform
- Location: Snowflake managed service
- Dependencies: Cortex feature enabled, sufficient compute

## Network Security

### Transport Security

| Layer | Protocol | Encryption | Port |
|-------|----------|------------|------|
| Browser → Dev Server | HTTP | None (localhost) | 3001 |
| React → Backend Proxy | HTTP | None (localhost) | 4000 |
| Backend Proxy → Snowflake | HTTPS | TLS 1.2+ | 443 |
| API → Cortex | Internal | Snowflake managed | N/A |

### Authentication Flow

1. **Proxy Signing**: Backend signs KEYPAIR_JWT using private key from `.env.server.local`
2. **Frontend Call**: React calls local proxy (`/api/threads`, `/api/agent/run`)
3. **Token Transmission**: Proxy sends JWT as Bearer token to Snowflake
4. **Token Validation**: Snowflake validates signature, issuer/subject, expiration
5. **Permission Check**: RBAC validates usage grants on agent
6. **Request Processing**: Agent invocation proceeds if authorized

### Firewall Requirements

**Outbound Rules (Required):**
```
Protocol: HTTPS (TCP)
Port: 443
Destination: *.snowflakecomputing.com
Direction: Outbound
```

**Inbound Rules (Development Only):**
```
Protocol: HTTP
Port: 3001 (frontend), 4000 (backend proxy)
Source: localhost (127.0.0.1)
Direction: Inbound (local only)
```

## Production Considerations

### Network Policy Hardening

```sql
-- Restrict to specific IP ranges (recommended for production)
CREATE NETWORK POLICY SFE_CORTEX_CHAT_POLICY
    ALLOWED_IP_LIST = (
        '203.0.113.0/24',     -- Corporate office
        '198.51.100.0/24'     -- VPN range
    )
    BLOCKED_IP_LIST = (
        '192.0.2.0/24'        -- Known bad actors
    );
```

### CORS Configuration

Not applicable for this architecture—PAT authentication avoids CORS issues. If hosting React app on a web server (production), ensure proper domain configuration.

### Rate Limiting

Snowflake REST API includes built-in rate limiting:
- Consult Snowflake documentation for current limits
- Implement client-side retry with exponential backoff
- Monitor usage via `ACCOUNT_USAGE.REST_EVENT_HISTORY`

## Troubleshooting Network Issues

### Cannot Reach Snowflake

**Symptoms:** Network timeouts, DNS errors
**Check:**
1. Firewall allows outbound HTTPS (:443)
2. DNS resolution works: `nslookup {account}.snowflakecomputing.com`
3. No corporate proxy blocking Snowflake domains

### 401 Unauthorized

**Symptoms:** Authentication failure
**Check:**
1. PAT is valid and not expired
2. PAT user has network policy assigned
3. Request IP is in network policy ALLOWED_IP_LIST

### 403 Forbidden

**Symptoms:** Permission denied
**Check:**
1. User has USAGE grant on agent
2. Role associated with PAT has appropriate permissions
3. Network policy allows connection

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.

---

*SE Community • Cortex Agent Chat Tool • Created: 2025-12-15 • Expires: 2026-01-14*
