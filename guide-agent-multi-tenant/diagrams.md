# Multi-Tenant Snowflake Agent - Visual Diagrams

Visual representations of the multi-tenant architecture using Azure AD OAuth and Row Access Policies.

## 1. High-Level System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        A[React Application]
        A1[MSAL Library]
        A -->|Uses| A1
    end

    subgraph "Identity Provider"
        B[Azure AD]
        B1[JWT Token<br/>+ customer_id claim]
    end

    subgraph "Application Layer"
        C[Backend Proxy<br/>Node.js/Express]
        C1[JWT Validation]
        C2[Token Exchange]
        C -->|Validates| C1
        C -->|Exchanges| C2
    end

    subgraph "Snowflake Platform"
        D[External OAuth<br/>Integration]
        E[Agent API]
        F[Row Access<br/>Policies]
        G[Customer Data<br/>Tables]
        H[Customer<br/>Mapping Table]

        D -->|Authenticates| E
        E -->|Queries| G
        F -->|Filters| G
        H -->|Maps User to| F
    end

    A1 -->|1. Login Request| B
    B -->|2. JWT Token| A1
    A -->|3. API Call + Token| C
    C1 -->|4. Validated| C2
    C2 -->|5. Snowflake Token| D
    D -->|6. Authorized Call| E
    E -->|7. Filtered Data| C
    C -->|8. Stream Response| A

    style A fill:#e1f5ff
    style B fill:#fff4e1
    style C fill:#f0e1ff
    style D fill:#e1ffe1
    style E fill:#e1ffe1
    style F fill:#ffe1e1
    style G fill:#ffe1e1
```

## 2. Authentication Flow

```mermaid
sequenceDiagram
    participant U as Customer User
    participant R as React App
    participant AZ as Azure AD
    participant BE as Backend Proxy
    participant SF as Snowflake

    U->>R: 1. Access Application
    R->>AZ: 2. Redirect to Login
    U->>AZ: 3. Enter Credentials
    AZ->>AZ: 4. Authenticate & Generate JWT
    Note over AZ: JWT includes:<br/>- user identity<br/>- customer_id claim<br/>- email, roles
    AZ->>R: 5. Return JWT Token
    R->>R: 6. Store Token (memory)

    Note over R,BE: User authenticated,<br/>ready to make API calls
```

## 3. Agent Query Flow with Row Access Policies

```mermaid
sequenceDiagram
    participant U as Customer User
    participant R as React App
    participant BE as Backend Proxy
    participant SF as Snowflake API
    participant AG as Agent Service
    participant DB as Database
    participant RAP as Row Access Policy

    U->>R: 1. Ask "What are my sales?"
    R->>BE: 2. POST /api/agent/run<br/>(JWT Token)

    BE->>BE: 3. Validate JWT
    BE->>BE: 4. Extract customer_id

    BE->>SF: 5. POST agent:run<br/>(OAuth Token)
    Note over BE,SF: X-Snowflake-Context:<br/>currentRole

    SF->>SF: 6. Validate OAuth Token<br/>via External Integration

    SF->>AG: 7. Execute Agent
    AG->>AG: 8. Generate SQL Query
    Note over AG: SELECT * FROM sales<br/>WHERE ...

    AG->>DB: 9. Execute Query
    DB->>RAP: 10. Apply Policy

    RAP->>RAP: 11. Get CURRENT_USER()
    RAP->>RAP: 12. Lookup customer_id<br/>from mapping table
    RAP->>RAP: 13. Filter rows WHERE<br/>customer_id = user's customer_id

    RAP->>DB: 14. Return filtered results
    DB->>AG: 15. Query results<br/>(only customer's data)
    AG->>SF: 16. Format response
    SF->>BE: 17. Stream response (SSE)
    BE->>R: 18. Stream to frontend
    R->>U: 19. Display results

    Note over U,RAP: Data isolation enforced<br/>at database level
```

## 4. Row Access Policy Mechanism

```mermaid
graph LR
    subgraph "Query Execution"
        A[User Query:<br/>SELECT * FROM sales]
    end

    subgraph "Row Access Policy"
        B[Get CURRENT_USER]
        C[Lookup customer_mapping]
        D{Match<br/>customer_id?}
    end

    subgraph "Sales Table"
        E[Row: customer_id=CUST001]
        F[Row: customer_id=CUST002]
        G[Row: customer_id=CUST003]
    end

    subgraph "Results"
        H[Only CUST001 rows]
        I[Denied]
        J[Denied]
    end

    A -->|1. Execute| B
    B -->|2. Returns 'CUSTOMER1_USER'| C
    C -->|3. Returns 'CUST001'| D

    E -->|customer_id=CUST001| D
    F -->|customer_id=CUST002| D
    G -->|customer_id=CUST003| D

    D -->|Match!| H
    D -->|No Match| I
    D -->|No Match| J

    style D fill:#ffe1e1
    style H fill:#e1ffe1
    style I fill:#ffcccc
    style J fill:#ffcccc
```

## 5. Security Layers

```mermaid
graph TD
    subgraph "Layer 1: Identity"
        A[Azure AD OAuth]
        A1[MFA Optional]
        A2[Conditional Access]
        A --> A1
        A --> A2
    end

    subgraph "Layer 2: Transport"
        B[HTTPS/TLS]
        B1[JWT Token]
        B2[Token Expiration]
        B --> B1
        B --> B2
    end

    subgraph "Layer 3: Application"
        C[Backend Validation]
        C1[Token Signature]
        C2[Claims Validation]
        C3[Rate Limiting]
        C --> C1
        C --> C2
        C --> C3
    end

    subgraph "Layer 4: Snowflake Auth"
        D[External OAuth]
        D1[User Mapping]
        D2[Role Assignment]
        D --> D1
        D --> D2
    end

    subgraph "Layer 5: Data Access"
        E[Row Access Policy]
        E1[Customer Mapping]
        E2[Real-time Filtering]
        E --> E1
        E --> E2
    end

    A --> B
    B --> C
    C --> D
    D --> E

    style A fill:#fff4e1
    style B fill:#e1f5ff
    style C fill:#f0e1ff
    style D fill:#e1ffe1
    style E fill:#ffe1e1
```

## 6. Data Model

```mermaid
erDiagram
    CUSTOMER_MAPPING ||--o{ SNOWFLAKE_USERS : maps
    CUSTOMER_MAPPING ||--o{ SALES : filters
    CUSTOMER_MAPPING ||--o{ ORDERS : filters

    CUSTOMER_MAPPING {
        varchar snowflake_user PK
        varchar customer_id
        varchar customer_name
        timestamp created_at
    }

    SNOWFLAKE_USERS {
        varchar login_name
        varchar display_name
        varchar default_role
    }

    SALES {
        varchar sale_id PK
        varchar customer_id FK
        varchar product_name
        decimal amount
        date sale_date
    }

    ORDERS {
        varchar order_id PK
        varchar customer_id FK
        varchar status
        timestamp order_date
    }

    ROW_ACCESS_POLICY {
        function get_customer_id
        boolean policy_logic
    }

    SALES ||--|| ROW_ACCESS_POLICY : protected_by
    ORDERS ||--|| ROW_ACCESS_POLICY : protected_by
```

## 7. Component Interaction Flow

```mermaid
flowchart TD
    Start([User Opens App]) --> Login{Authenticated?}
    Login -->|No| AzureLogin[Azure AD Login]
    AzureLogin --> GetToken[Receive JWT Token]
    GetToken --> StoreToken[Store in Memory]

    Login -->|Yes| LoadApp[Load App UI]
    StoreToken --> LoadApp

    LoadApp --> GetCustomerInfo[GET /api/customer/info]
    GetCustomerInfo --> DisplayCustomer[Display Customer Badge]

    DisplayCustomer --> WaitInput[Wait for User Input]
    WaitInput --> UserQuery[User Asks Question]

    UserQuery --> CreateThread{Thread Exists?}
    CreateThread -->|No| NewThread[POST /api/agent/thread]
    NewThread --> SaveThread[Save thread_id]

    CreateThread -->|Yes| SendMessage[POST /api/agent/run]
    SaveThread --> SendMessage

    SendMessage --> ValidateJWT[Backend: Validate JWT]
    ValidateJWT --> ValidCheck{Valid?}

    ValidCheck -->|No| Error401[Return 401 Unauthorized]
    ValidCheck -->|Yes| ExtractClaims[Extract customer_id]

    ExtractClaims --> SnowflakeAuth[Snowflake OAuth]
    SnowflakeAuth --> CallAgent[Call Agent API]

    CallAgent --> AgentProcess[Agent Processes Query]
    AgentProcess --> ExecuteSQL[Execute SQL]
    ExecuteSQL --> ApplyRAP[Apply Row Access Policy]

    ApplyRAP --> FilterData[Filter by customer_id]
    FilterData --> StreamBack[Stream Results]
    StreamBack --> UpdateUI[Update React UI]

    UpdateUI --> WaitInput
    Error401 --> RedirectLogin[Redirect to Login]
    RedirectLogin --> AzureLogin

    style Login fill:#fff4e1
    style ValidateJWT fill:#f0e1ff
    style ApplyRAP fill:#ffe1e1
    style StreamBack fill:#e1ffe1
```

## 8. Token Flow Diagram

```mermaid
sequenceDiagram
    participant User
    participant React
    participant MSAL
    participant Azure
    participant Backend
    participant Snowflake

    Note over User,Snowflake: Token Acquisition Flow

    User->>React: Click Login
    React->>MSAL: loginPopup()
    MSAL->>Azure: Authorization Request
    Azure->>User: Login Page
    User->>Azure: Credentials
    Azure->>Azure: Validate & Create JWT

    Note over Azure: JWT Contains:<br/>iss: Azure AD<br/>aud: client_id<br/>sub: user_id<br/>customer_id: CUST001<br/>exp: timestamp

    Azure->>MSAL: JWT Token
    MSAL->>React: Access Token
    React->>React: Store in State

    Note over User,Snowflake: Token Usage Flow

    User->>React: Ask Question
    React->>Backend: API Call<br/>Authorization: Bearer JWT
    Backend->>Backend: Verify JWT Signature<br/>using JWKS
    Backend->>Backend: Validate Claims<br/>(iss, aud, exp)
    Backend->>Backend: Extract customer_id

    Backend->>Snowflake: API Call<br/>Authorization: Bearer JWT
    Snowflake->>Snowflake: Validate via<br/>External OAuth Integration
    Snowflake->>Snowflake: Map to Snowflake User
    Snowflake->>Snowflake: Apply Row Access Policy
    Snowflake->>Backend: Filtered Results
    Backend->>React: Stream Response
    React->>User: Display Data
```

## 9. Deployment Architecture

```mermaid
graph TB
    subgraph "Production Environment"
        subgraph "CDN / Edge"
            A[CloudFront / CDN]
            A1[Static React Assets]
            A --> A1
        end

        subgraph "Application Tier"
            B[Load Balancer]
            C1[Backend Instance 1]
            C2[Backend Instance 2]
            C3[Backend Instance N]
            B --> C1
            B --> C2
            B --> C3
        end

        subgraph "Identity"
            D[Azure AD]
            D1[App Registration]
            D2[User Directory]
            D --> D1
            D --> D2
        end

        subgraph "Snowflake"
            E[External OAuth]
            F[Agent Services]
            G[Row Access Policies]
            H[Data Warehouse]

            E --> F
            F --> H
            G --> H
        end

        subgraph "Monitoring"
            I[Application Logs]
            J[Snowflake Query History]
            K[Security Alerts]
        end
    end

    Users[Customers] --> A
    A --> B

    C1 -.->|Token Validation| D
    C2 -.->|Token Validation| D
    C3 -.->|Token Validation| D

    C1 --> E
    C2 --> E
    C3 --> E

    C1 --> I
    F --> J
    E --> K

    style Users fill:#e1f5ff
    style A fill:#fff4e1
    style B fill:#f0e1ff
    style D fill:#fff4e1
    style E fill:#e1ffe1
    style G fill:#ffe1e1
```

## 10. Error Handling Flow

```mermaid
flowchart TD
    Start[API Request] --> ValidateToken{Token Valid?}

    ValidateToken -->|No| TokenError{Error Type?}
    TokenError -->|Expired| RefreshToken[Attempt Token Refresh]
    TokenError -->|Invalid| Return401[401 Unauthorized]
    TokenError -->|Missing| Return401

    RefreshToken --> RefreshSuccess{Success?}
    RefreshSuccess -->|Yes| ValidateToken
    RefreshSuccess -->|No| RedirectLogin[Redirect to Login]

    ValidateToken -->|Yes| CheckCustomer{Customer<br/>Mapping Exists?}

    CheckCustomer -->|No| Return403[403 Forbidden<br/>Customer Not Configured]
    CheckCustomer -->|Yes| CallSnowflake[Call Snowflake API]

    CallSnowflake --> SnowflakeResponse{Response OK?}

    SnowflakeResponse -->|Network Error| Retry{Retry<br/>Count < 3?}
    Retry -->|Yes| Wait[Wait with<br/>Exponential Backoff]
    Wait --> CallSnowflake
    Retry -->|No| Return503[503 Service Unavailable]

    SnowflakeResponse -->|Auth Error| Return401
    SnowflakeResponse -->|Rate Limited| Return429[429 Too Many Requests]
    SnowflakeResponse -->|Success| StreamData[Stream Data to Client]

    StreamData --> ClientDisconnect{Client<br/>Connected?}
    ClientDisconnect -->|No| CleanupResources[Cleanup Resources]
    ClientDisconnect -->|Yes| ContinueStream[Continue Streaming]

    ContinueStream --> Complete[200 OK]

    Return401 --> LogError[Log Error]
    Return403 --> LogError
    Return429 --> LogError
    Return503 --> LogError
    CleanupResources --> LogError

    LogError --> End[End]
    Complete --> End
    RedirectLogin --> End

    style Return401 fill:#ffcccc
    style Return403 fill:#ffcccc
    style Return429 fill:#ffcccc
    style Return503 fill:#ffcccc
    style Complete fill:#ccffcc
```

## 11. Customer Onboarding Flow

```mermaid
sequenceDiagram
    participant Admin
    participant AzureAD
    participant Snowflake
    participant Backend
    participant Customer

    Note over Admin,Customer: New Customer Onboarding

    Admin->>AzureAD: 1. Create User Account
    AzureAD->>AzureAD: 2. Set customer_id claim

    Admin->>Snowflake: 3. CREATE USER<br/>login_name = email
    Admin->>Snowflake: 4. GRANT ROLE customer_app_role

    Admin->>Snowflake: 5. INSERT INTO customer_mapping<br/>(user, customer_id, name)

    Admin->>Snowflake: 6. Verify Row Access Policy<br/>SELECT * FROM sales
    Snowflake->>Admin: Returns only new customer's data

    Admin->>Customer: 7. Send Welcome Email<br/>with login instructions

    Customer->>Backend: 8. First Login
    Backend->>AzureAD: 9. OAuth Flow
    AzureAD->>Backend: 10. JWT Token
    Backend->>Snowflake: 11. Test Access
    Snowflake->>Backend: 12. Success + Filtered Data
    Backend->>Customer: 13. Welcome to Portal

    Note over Admin,Customer: Customer can now access<br/>only their own data
```

## 12. Multi-Customer Isolation

```mermaid
graph TB
    subgraph "Customer A - CUST001"
        A1[User: alice@custA.com]
        A2[Snowflake User: CUSTA_USER]
        A3[Customer Mapping: CUST001]
        A4[Sales Rows: customer_id=CUST001]

        A1 --> A2
        A2 --> A3
        A3 -.->|RAP Filter| A4
    end

    subgraph "Customer B - CUST002"
        B1[User: bob@custB.com]
        B2[Snowflake User: CUSTB_USER]
        B3[Customer Mapping: CUST002]
        B4[Sales Rows: customer_id=CUST002]

        B1 --> B2
        B2 --> B3
        B3 -.->|RAP Filter| B4
    end

    subgraph "Customer C - CUST003"
        C1[User: carol@custC.com]
        C2[Snowflake User: CUSTC_USER]
        C3[Customer Mapping: CUST003]
        C4[Sales Rows: customer_id=CUST003]

        C1 --> C2
        C2 --> C3
        C3 -.->|RAP Filter| C4
    end

    subgraph "Shared Infrastructure"
        RAP[Row Access Policy]
        AGENT[Agent Service]
        TABLES[Sales Table<br/>All Customer Data]
    end

    A4 --> TABLES
    B4 --> TABLES
    C4 --> TABLES

    RAP -.->|Enforces Isolation| TABLES
    AGENT -->|Queries| TABLES

    A2 -->|Queries via| AGENT
    B2 -->|Queries via| AGENT
    C2 -->|Queries via| AGENT

    style A1 fill:#e1f5ff
    style B1 fill:#f0e1ff
    style C1 fill:#fff4e1
    style RAP fill:#ffe1e1
    style TABLES fill:#e1ffe1
```

---

## Diagram Usage Guide

### When to Use Each Diagram:

1. **High-Level System Architecture**: Executive overview, system design discussions
2. **Authentication Flow**: Understanding OAuth integration, security reviews
3. **Agent Query Flow**: Debugging query issues, performance optimization
4. **Row Access Policy Mechanism**: Explaining data isolation to stakeholders
5. **Security Layers**: Security audits, compliance documentation
6. **Data Model**: Database design, schema documentation
7. **Component Interaction**: Developer onboarding, troubleshooting
8. **Token Flow**: Security implementation details
9. **Deployment Architecture**: Infrastructure planning, scaling discussions
10. **Error Handling**: Resilience planning, monitoring setup
11. **Customer Onboarding**: Operations documentation
12. **Multi-Customer Isolation**: Explaining multi-tenancy to customers

### Rendering These Diagrams:

Most modern markdown viewers support Mermaid diagrams:
- **GitHub**: Native support
- **GitLab**: Native support
- **VS Code**: Install "Markdown Preview Mermaid Support" extension
- **Browser**: Use [Mermaid Live Editor](https://mermaid.live)
- **Documentation**: Supports Mermaid (MkDocs, Docusaurus, etc.)

### Exporting as Images:

```bash
# Using Mermaid CLI
npm install -g @mermaid-js/mermaid-cli
mmdc -i diagrams.md -o diagrams.pdf
```
