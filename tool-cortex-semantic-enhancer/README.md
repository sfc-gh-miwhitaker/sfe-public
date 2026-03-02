# Semantic View Enhancer

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Author:** SE Community
**Purpose:** Enhance Snowflake semantic views with AI-improved descriptions using Cortex
**Expires:** 2026-01-15 (30 days)
**Status:** ✅ Active

---

## What This Tool Does

Creates **enhanced copies** of your Snowflake semantic views with AI-generated, business-aware descriptions for all dimensions and facts using Cortex AI.

```sql
-- You have a semantic view with basic descriptions
ORDERS_VIEW
  - O_ORDERSTATUS: "Order status code"
  - O_ORDERPRIORITY: "Order priority level"

-- Run the enhancement
CALL SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME => 'ORDERS_VIEW',
    P_BUSINESS_CONTEXT_PROMPT => 'Order fulfillment system. Status: F=Fulfilled (shipped), O=Open (awaiting payment), P=Processing (warehouse). Priority: 1-URGENT (VIP, 24hr SLA), 2-HIGH (48hr), 3-MEDIUM (5 day).'
);

-- Get an enhanced copy with business-aware descriptions
ORDERS_VIEW_ENHANCED
  - O_ORDERSTATUS: "Order fulfillment stage: F=Fulfilled (shipped), O=Open (awaiting payment), P=Processing (warehouse)."
  - O_ORDERPRIORITY: "Priority level determining SLA: 1-URGENT (VIP, 24hr), 2-HIGH (48hr), 3-MEDIUM (5 day)."
```

**Your original view remains unchanged.** A new enhanced copy is created with the `_ENHANCED` suffix.

---

## How It Works

1. **Extracts** the source semantic view's DDL using `GET_DDL('SEMANTIC_VIEW', ...)`
2. **Analyzes** all dimensions and facts using `DESCRIBE SEMANTIC VIEW`
3. **Enhances** each description by calling Cortex AI (llama3.3-70b) with your business context
4. **Creates** a new semantic view with enhanced descriptions

```
┌─────────────────┐
│  Source View    │  ORDERS_VIEW
│  Generic desc.  │  "Order status code"
└────────┬────────┘
         │
         │ GET_DDL + DESCRIBE
         ↓
┌─────────────────┐
│  Cortex AI      │  + Your Business Context
│  Enhancement    │  → "F=Fulfilled, O=Open, P=Processing"
└────────┬────────┘
         │
         │ CREATE with enhanced DDL
         ↓
┌─────────────────┐
│  Enhanced Copy  │  ORDERS_VIEW_ENHANCED
│  Business desc. │  "Order fulfillment stage: F=Fulfilled..."
└─────────────────┘
```

---

## Quick Start

### 1. Deploy the Tool

Copy/paste `deploy.sql` into Snowsight and click "Run All" (~2 minutes)

### 2. Enhance Your Semantic Views

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS;
USE WAREHOUSE SFE_ENHANCEMENT_WH;

CALL SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME => 'YOUR_SEMANTIC_VIEW',
    P_BUSINESS_CONTEXT_PROMPT => 'Your comprehensive business context here...'
    -- Optional: P_OUTPUT_VIEW_NAME => 'CUSTOM_NAME'
    -- Optional: P_MODEL => 'snowflake-llama-3.3-70b' (default)
);
```

### 3. Compare and Use

```sql
-- Compare original vs enhanced
DESCRIBE SEMANTIC VIEW YOUR_SEMANTIC_VIEW;
DESCRIBE SEMANTIC VIEW YOUR_SEMANTIC_VIEW_ENHANCED;
```

---

## Procedure Parameters

```sql
SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME STRING,          -- Required: Source semantic view name
    P_BUSINESS_CONTEXT_PROMPT STRING,   -- Required: Business context for enhancement
    P_OUTPUT_VIEW_NAME STRING,          -- Optional: Output name (default: SOURCE_NAME_ENHANCED)
    P_SCHEMA_NAME STRING,               -- Optional: Schema (default: current schema)
    P_DATABASE_NAME STRING,             -- Optional: Database (default: current database)
    P_DRY_RUN BOOLEAN,                  -- Optional: Preview mode (default: FALSE)
    P_MODEL STRING,                     -- Optional: AI model (default: 'snowflake-llama-3.3-70b')
    P_MAX_COMMENT_LENGTH INTEGER,       -- Optional: Max length (default: 200, range: 50-1000)
    P_MAX_RETRIES INTEGER               -- Optional: Retry attempts (default: 3)
)
```

---

## Writing Effective Business Context

Your business context is applied to **ALL** dimensions and facts. Cortex AI intelligently extracts relevant information for each field.

### ✅ Good Prompt Structure

```sql
P_BUSINESS_CONTEXT_PROMPT => '
E-commerce order fulfillment system for retail operations.

ORDER STATUS CODES:
- F=Fulfilled: Shipped to customer, counts toward revenue
- O=Open: Awaiting payment, can be cancelled
- P=Processing: In warehouse, being packed

PRIORITY LEVELS:
- 1-URGENT: VIP customers, 24-hour SLA, VP approval if >$50K
- 2-HIGH: Premium customers, 48-hour SLA
- 3-MEDIUM: Standard customers, 5-day SLA

BUSINESS RULES:
- Only fulfilled orders count toward revenue
- Orders >$100K trigger fraud screening
- Shipping costs vary by priority level
'
```

### What to Include

1. **Code Definitions**: Explain abbreviations (F=Fulfilled, O=Open)
2. **Business Rules**: Important constraints and logic
3. **Domain Context**: Industry-specific terminology
4. **Relationships**: How fields relate to business processes
5. **Thresholds**: Important numeric boundaries ($50K, $100K)

---

## Use Cases

1. **Improve Cortex Analyst Accuracy** - Better descriptions = better AI query understanding
2. **Onboard New Team Members** - Enhanced descriptions document business logic
3. **Standardize Terminology** - Apply consistent definitions across views
4. **Document Domain Knowledge** - Capture tribal knowledge about codes and business rules
5. **Regulatory Compliance** - Document compliance requirements and data governance

---

## Objects Created

| Object Type | Name | Purpose |
|------------|------|---------|
| Warehouse | `SFE_ENHANCEMENT_WH` | X-SMALL, 60s auto-suspend |
| Schema | `SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS` | Container for enhancement objects |
| Procedure | `SFE_ENHANCE_SEMANTIC_VIEW` | Main enhancement procedure (Python 3.12) |
| Function | `SFE_ESTIMATE_ENHANCEMENT_COST` | Cost estimation for views |
| Procedure | `SFE_DIAGNOSE_ENVIRONMENT` | Environment diagnostics |

---

## Cost & Performance

### Cortex AI Model: snowflake-llama-3.3-70b

- **Snowflake-optimized** Llama 3.3 model with SwiftKV optimizations
- **75% cost reduction** vs standard llama3.3-70b
- **~20x cheaper** than mistral-large2
- **Higher throughput** with minimal accuracy loss
- **High-quality** business descriptions

### Estimated Costs

| Component | Details | Estimated Cost |
|-----------|---------|----------------|
| Setup | X-SMALL, ~2 min | < $0.01 |
| Per enhancement (10 dimensions) | snowflake-llama-3.3-70b | ~$0.005 |
| Per enhancement (50 dimensions) | snowflake-llama-3.3-70b | ~$0.025 |
| Per enhancement (100 dimensions) | snowflake-llama-3.3-70b | ~$0.05 |
| Monthly ongoing | Storage + idle warehouse | $0 |

**Edition Requirement:** Standard ($2/credit) or higher

---

## Advanced Features

### Dry Run Mode (Preview Enhancements)

```sql
CALL SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME => 'ORDERS_VIEW',
    P_BUSINESS_CONTEXT_PROMPT => 'Context...',
    P_DRY_RUN => TRUE
);
```

### Custom AI Model

```sql
-- Use alternative model (snowflake-llama-3.3-70b is default and recommended)
CALL SFE_ENHANCE_SEMANTIC_VIEW(
    P_SOURCE_VIEW_NAME => 'ORDERS_VIEW',
    P_BUSINESS_CONTEXT_PROMPT => 'Context...',
    P_MODEL => 'llama3.1-8b',  -- Smaller, even cheaper option
    P_MAX_COMMENT_LENGTH => 300
);
```

### Cost Estimation

```sql
SELECT SFE_ESTIMATE_ENHANCEMENT_COST(
    P_VIEW_NAME => 'YOUR_VIEW',
    P_MODEL => 'snowflake-llama-3.3-70b'  -- Default model
);
```

### Environment Diagnostics

```sql
CALL SFE_DIAGNOSE_ENVIRONMENT();
```

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Semantic view not found" | Verify with `SHOW SEMANTIC VIEWS` and check spelling |
| "Could not get DDL" | Ensure you have SELECT privilege on the view |
| "Cortex function not available" | Contact Snowflake support to enable Cortex features |
| Enhancement doesn't make sense | Refine business context with more specific definitions |

---

## Cleanup

To remove all objects created by this tool:

```sql
-- Copy/paste teardown.sql into Snowsight and click "Run All"
@teardown.sql
```

This drops:
- Schema `SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS` (CASCADE)
- Warehouse `SFE_ENHANCEMENT_WH`
- All procedures, functions, and views in the schema

**Preserved:**
- `SNOWFLAKE_EXAMPLE` database (may contain other tools)

---

## Architecture Diagrams

See `diagrams/` folder for detailed architecture diagrams:
- `data-model.md` - Semantic view metadata structure
- `data-flow.md` - How data flows through enhancement
- `network-flow.md` - Network architecture
- `auth-flow.md` - Authentication & authorization

---

## Key Takeaways

1. ✅ **Creates enhanced copies** - Original views stay safe
2. ✅ **One procedure, one call** - Simple API
3. ✅ **Cortex-powered** - AI understands your business context
4. ✅ **Production-ready** - Handles errors, escaping, edge cases
5. ✅ **Cost-effective** - Pennies per semantic view
6. ✅ **Flexible** - Iterative refinement supported

---

## Resources

- [Snowflake Semantic Views Documentation](https://docs.snowflake.com/en/user-guide/views-semantic)
- [Cortex COMPLETE Function](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [GET_DDL Function](https://docs.snowflake.com/en/sql-reference/functions/get_ddl)
- [DESCRIBE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/desc-semantic-view)

---

*SE Community • Tools Collection • Last Updated: 2025-12-15*
