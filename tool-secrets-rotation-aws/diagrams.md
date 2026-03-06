# Architecture Diagrams

## Overview: Two Rotation Patterns

```mermaid
flowchart LR
    subgraph aws [AWS]
        SM[Secrets Manager]
        L1[Key-Pair\nRotation Lambda]
        L2[PAT Rotation\nLambda]
    end

    subgraph sf [Snowflake]
        SU[Service User\nTYPE=SERVICE]
    end

    subgraph apps [Applications]
        ETL[ETL Pipeline]
        API[REST API Client]
    end

    SM -->|triggers| L1
    SM -->|triggers| L2
    L1 -->|ALTER USER SET\nRSA_PUBLIC_KEY| SU
    L2 -->|ALTER USER\nROTATE PAT| SU
    L1 -->|stores key pair| SM
    L2 -->|stores new PAT| SM
    ETL -->|GetSecretValue\nprivate key| SM
    ETL -->|key-pair auth| SU
    API -->|GetSecretValue\nPAT| SM
    API -->|bearer token| SU
```

---

## Pattern 1: Key-Pair Rotation (Native Secrets Manager)

The AWS-managed rotation Lambda handles the full lifecycle. Snowflake's dual public key slots
(`RSA_PUBLIC_KEY` and `RSA_PUBLIC_KEY_2`) enable zero-downtime rotation.

```mermaid
sequenceDiagram
    autonumber
    participant Schedule as CloudWatch Schedule
    participant SM as Secrets Manager
    participant Lambda as Rotation Lambda
    participant SF as Snowflake

    Schedule->>SM: Trigger rotation

    rect rgb(240, 248, 255)
        Note over SM,Lambda: Step 1: createSecret
        SM->>Lambda: Invoke (createSecret)
        Lambda->>Lambda: Generate new RSA key pair
        Lambda->>SM: PutSecretValue (new private key, AWSPENDING)
    end

    rect rgb(240, 255, 240)
        Note over Lambda,SF: Step 2: setSecret
        SM->>Lambda: Invoke (setSecret)
        Lambda->>SM: GetSecretValue (AWSPENDING)
        Lambda->>SF: ALTER USER SET RSA_PUBLIC_KEY_2 = new public key
        SF-->>Lambda: Success
    end

    rect rgb(255, 248, 240)
        Note over Lambda,SF: Step 3: testSecret
        SM->>Lambda: Invoke (testSecret)
        Lambda->>SM: GetSecretValue (AWSPENDING private key)
        Lambda->>SF: Connect using new key pair
        SF-->>Lambda: Authentication successful
    end

    rect rgb(248, 240, 255)
        Note over SM,Lambda: Step 4: finishSecret
        SM->>Lambda: Invoke (finishSecret)
        Lambda->>SM: UpdateSecretVersionStage (AWSPENDING to AWSCURRENT)
        Note over SM: Applications now receive the new key
    end
```

### Dual Key Slot Rotation Cycle

On each rotation, the Lambda alternates which public key slot it updates:

```mermaid
stateDiagram-v2
    state "Rotation 1" as R1
    state "Rotation 2" as R2
    state "Rotation 3" as R3

    R1: RSA_PUBLIC_KEY = Key A (active)
    R1: RSA_PUBLIC_KEY_2 = Key B (new)

    R2: RSA_PUBLIC_KEY = Key C (new)
    R2: RSA_PUBLIC_KEY_2 = Key B (active)

    R3: RSA_PUBLIC_KEY = Key C (active)
    R3: RSA_PUBLIC_KEY_2 = Key D (new)

    [*] --> R1: Initial + first rotation
    R1 --> R2: Next rotation
    R2 --> R3: Next rotation
    R3 --> R2: Cycle continues
```

---

## Pattern 2: PAT Rotation (Custom Lambda)

The custom Lambda authenticates to Snowflake via key-pair (from Pattern 1) because
PAT rotation cannot be performed from a PAT-authenticated session.

```mermaid
sequenceDiagram
    autonumber
    participant Schedule as CloudWatch Schedule
    participant SM as Secrets Manager
    participant Lambda as PAT Rotation Lambda
    participant SF as Snowflake

    Schedule->>SM: Trigger rotation

    rect rgb(240, 248, 255)
        Note over SM,SF: Step 1: createSecret
        SM->>Lambda: Invoke (createSecret)
        Lambda->>SM: GetSecretValue (key-pair secret for auth)
        Lambda->>SF: Connect via key-pair authentication
        Lambda->>SF: ALTER USER ROTATE PAT token_name<br/>EXPIRE_ROTATED_TOKEN_AFTER_HOURS = 24
        SF-->>Lambda: Return new token_secret
        Lambda->>SM: PutSecretValue (new PAT, AWSPENDING)
        Lambda->>SF: Close connection
    end

    rect rgb(255, 248, 240)
        Note over Lambda,SF: Step 3: testSecret
        SM->>Lambda: Invoke (testSecret)
        Lambda->>SM: GetSecretValue (AWSPENDING PAT)
        Lambda->>SF: GET /api/v2/databases (Bearer token)
        SF-->>Lambda: HTTP 200 OK
    end

    rect rgb(248, 240, 255)
        Note over SM,Lambda: Step 4: finishSecret
        SM->>Lambda: Invoke (finishSecret)
        Lambda->>SM: UpdateSecretVersionStage (AWSPENDING to AWSCURRENT)
        Note over SM: Applications now receive the new PAT
    end

    Note over SF: Old PAT remains valid for 24 hours (grace period)
```

### PAT Rotation Token Lifecycle

```mermaid
gantt
    title PAT Token Lifecycle During Rotation
    dateFormat HH:mm
    axisFormat %H:%M

    section OldToken
        Active (AWSCURRENT)       :active, old, 00:00, 24h
        Grace period              :crit, grace, after old, 24h

    section NewToken
        Pending (AWSPENDING)      :pending, 00:00, 1h
        Active (AWSCURRENT)       :active, new, after pending, 47h
```

---

## Secret Dependencies

Pattern 2 depends on Pattern 1 for its authentication pathway:

```mermaid
flowchart TD
    KP["Key-Pair Secret\nsnowflake/svc-etl-pipeline/keypair"]
    PAT["PAT Secret\nsnowflake/svc-etl-pipeline/pat"]
    KPLambda["Key-Pair Rotation Lambda\n(AWS managed)"]
    PATLambda["PAT Rotation Lambda\n(custom)"]
    SFUser["Snowflake Service User\nSVC_ETL_PIPELINE"]

    KP -->|rotated by| KPLambda
    KPLambda -->|updates public key| SFUser
    PAT -->|rotated by| PATLambda
    PATLambda -->|reads key-pair for auth| KP
    PATLambda -->|runs ROTATE PAT| SFUser
```

> **Important:** Schedule key-pair rotation and PAT rotation at different times to avoid
> a window where the PAT Lambda attempts to use a key pair that is mid-rotation.
> A safe pattern: key-pair rotates on the 1st, PAT rotates on the 15th.
