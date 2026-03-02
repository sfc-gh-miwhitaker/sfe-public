# Data Flow - Contact Form (Streamlit)

Author: SE Community
Last Updated: 2025-12-10
Expires: 2026-01-09

## Overview

Shows how form data flows from user input through the Streamlit app to storage in Snowflake.

## Diagram

```mermaid
graph LR
    subgraph "User"
        Browser[Web Browser]
    end

    subgraph "Streamlit in Snowflake"
        App[SFE_CONTACT_FORM]
        Form[Form Component]
        Display[Data Display]
    end

    subgraph "Storage"
        Table[(SFE_SUBMISSIONS)]
    end

    Browser -->|1. Open app| App
    App --> Form
    App --> Display

    Form -->|2. Submit| App
    App -->|3. INSERT| Table
    Table -->|4. SELECT| Display
    Display -->|5. Show| Browser
```

## Flow Steps

| Step | Action | Component | SQL |
|------|--------|-----------|-----|
| 1 | User opens app | Browser → Streamlit | - |
| 2 | User submits form | Form → Handler | - |
| 3 | Insert submission | Handler → Table | `INSERT INTO SFE_SUBMISSIONS` |
| 4 | Fetch recent | Display ← Table | `SELECT ... ORDER BY submitted_at DESC` |
| 5 | Render results | Browser ← Display | - |
