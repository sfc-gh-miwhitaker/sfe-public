# Data Flow - Cortex Agent Chat (React UI)

Author: SE Community
Last Updated: 2025-12-15
Expires: 2026-01-14 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows how user messages flow from the React UI through the REST API to the Cortex Agent and how responses return to the user interface.

```mermaid
graph TB
    subgraph client [Client Layer - User's Browser]
        User[User]
        UI[React Chat UI<br/>localhost:3001]
        Input[Message Input<br/>Component]
        Display[Message List<br/>Component]
    end

    subgraph proxy [Backend Proxy - Localhost]
        BFF[Express Proxy<br/>localhost:4000]
        Signer[Key-Pair JWT Signer<br/>(private key server-side)]
    end

    subgraph sfapi [Snowflake Cloud - REST API]
        ThreadsAPI[/POST /api/v2/cortex/threads/]
        AgentRun[/POST /api/v2/databases/{db}/schemas/{schema}/agents/{agent}:run/]
    end

    subgraph sfproc [Snowflake Cloud - Processing]
        Agent[Cortex Agent<br/>SFE_REACT_DEMO_AGENT]
        LLM[Cortex LLM Engine<br/>Language Processing]
    end

    User -->|Types message| Input
    Input -->|User message| UI
    UI -->|HTTPS /api/threads<br/>/api/agent/run| BFF
    BFF -->|Generate KEYPAIR_JWT| Signer
    BFF -->|HTTPS (KEYPAIR_JWT)| ThreadsAPI
    BFF -->|HTTPS SSE (KEYPAIR_JWT)| AgentRun
    ThreadsAPI -->|thread_id| BFF
    AgentRun -->|Validate JWT| Agent
    Agent -->|Process with LLM| LLM
    LLM -->|Generated response| Agent
    Agent -->|Response SSE/JSON| AgentRun
    AgentRun --> BFF --> UI --> Display --> User

    style User fill:#e1f5ff
    style UI fill:#fff4e1
    style BFF fill:#e8f5e9
    style ThreadsAPI fill:#f3e5f5
    style AgentRun fill:#f3e5f5
    style Agent fill:#e3f2fd
    style LLM fill:#e8eaf6
```

## Component Descriptions

### Client Layer

**User**
- Purpose: End user interacting with the chat interface
- Technology: Web browser
- Location: User's machine
- Dependencies: Modern web browser (Chrome, Firefox, Safari, Edge)

**React Chat UI**
- Purpose: Single-page application providing chat interface
- Technology: React 18, Create React App
- Location: `src/` directory
- Dependencies: React DOM, CSS modules, environment configuration

**Message Input Component**
- Purpose: Text input field for user messages
- Technology: React functional component
- Location: `src/components/MessageInput.js`
- Dependencies: React state hooks, CSS styling

**Message List Component**
- Purpose: Displays conversation history
- Technology: React functional component with scrolling
- Location: `src/components/MessageList.js`
- Dependencies: Message component, auto-scroll logic

### Frontend & Proxy Layer

**snowflakeApi.js**
- Purpose: Frontend client calling the local backend proxy
- Technology: JavaScript Fetch API
- Location: `src/services/snowflakeApi.js`
- Dependencies: Backend proxy endpoints (`/api/threads`, `/api/agent/run`, `/api/agent/run/stream`)

**Backend Proxy (Express)**
- Purpose: Signs KEYPAIR_JWT tokens and proxies to Snowflake REST APIs
- Technology: Node.js + Express
- Location: `server/index.js`
- Dependencies: `.env.server.local` (private key), Snowflake REST API

**Environment Config**
- Purpose: Stores connection details (no secrets in frontend)
- Technology: Create React App environment variables
- Location: `.env.local` (frontend, gitignored) and `.env.server.local` (backend, gitignored)
- Dependencies: Backend proxy must have private key env var

### Snowflake REST API

**Threads API**
- Purpose: Creates/reads threads for multi-turn context
- Technology: Snowflake REST API v2
- Location: `/api/v2/cortex/threads`
- Dependencies: KEYPAIR_JWT auth, thread ownership by service user

**Agent Run Endpoint**
- Purpose: Runs Cortex Agent and streams responses
- Technology: Snowflake REST API v2
- Location: `/api/v2/databases/{db}/schemas/{schema}/agents/{agent}:run`
- Dependencies: KEYPAIR_JWT auth, agent grants

### Snowflake Processing

**Cortex Agent (SFE_REACT_DEMO_AGENT)**
- Purpose: AI-powered conversational agent
- Technology: Snowflake Cortex Agent
- Location: `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT.SFE_REACT_DEMO_AGENT`
- Dependencies: Cortex service, agent instructions, usage grants

**Cortex LLM Engine**
- Purpose: Natural language processing and generation
- Technology: Snowflake Cortex AI (managed LLM service)
- Location: Snowflake platform service
- Dependencies: Cortex feature enabled, compute resources

## Data Flow Stages

| Stage | Input | Transformation | Output |
|-------|-------|----------------|--------|
| User Input | Keyboard text | Component state update | Message object |
| Thread Setup | None | POST /api/threads (backend) | `thread_id` |
| Proxy Request | Message + thread_id + parent_message_id | Backend signs KEYPAIR_JWT and calls Snowflake REST | Snowflake streaming response |
| Agent Processing | User message | LLM inference, instruction following | AI response text |
| Streaming Response | SSE events | Accumulate deltas, capture metadata (message_id) | Final text + next parent_message_id |
| UI Rendering | Message object | React component render | Displayed message |

## Message Format

### Request Payload
```json
{
  "thread_id": 12345,
  "parent_message_id": 0,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What is Snowflake?"
        }
      ]
    }
  ]
}
```

### Response Payload
```json
{
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "Snowflake is a cloud-based data warehouse..."
      }
    ]
  }
}
```

## Performance Characteristics

- **API Latency**: 500ms - 3s (depends on message complexity)
- **Network Overhead**: ~2KB per message exchange
- **UI Responsiveness**: <50ms render time
- **Conversation State**: Snowflake thread (`thread_id` + `parent_message_id`)

## Error Handling

1. **Network Errors**: Retry logic, timeout handling
2. **Authentication Errors**: Clear error messages, PAT validation
3. **API Errors**: Display Snowflake error messages
4. **Parsing Errors**: Fallback to raw response display

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.

---

*SE Community • Cortex Agent Chat Tool • Created: 2025-12-15 • Expires: 2026-01-14*
