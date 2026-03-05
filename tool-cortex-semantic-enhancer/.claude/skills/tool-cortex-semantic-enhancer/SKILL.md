---
name: tool-cortex-semantic-enhancer
description: "Enhance *existing* semantic views with AI-improved descriptions using custom business context. For NEW views, use Semantic View Autopilot instead. Triggers: semantic enhancer, enhance semantic view, AI descriptions, semantic view descriptions, AI_COMPLETE semantic, dry run enhancement."
---

# Semantic View Enhancer

## Purpose

Enhance *existing* Snowflake semantic views with AI-improved descriptions using custom business context and Cortex AI. Reads existing semantic view definitions, generates improved descriptions via AI_COMPLETE, and creates enhanced copies. Original views are never modified without explicit confirmation (dry-run mode available).

**Important:** For **new** semantic views, use [Semantic View Autopilot](https://docs.snowflake.com/en/user-guide/views-semantic/autopilot) with "AI-Generated Descriptions" enabled. This tool is for enhancing **existing** views or when you need custom business context injection.

## When to Use

- Improving descriptions on semantic views for better Cortex Analyst accuracy
- Running bulk description enhancement across multiple views
- Understanding the cost implications before running AI enhancement

## Architecture

```
Semantic View (existing)
       │
       ▼
SFE_ESTIMATE_ENHANCEMENT_COST (cost estimation function)
       │
       ▼
SFE_DIAGNOSE_ENVIRONMENT (diagnostic procedure)
       │
       ▼
SFE_ENHANCE_SEMANTIC_VIEW (main procedure)
  ├── Read current DDL
  ├── Parse tables, columns, metrics, dimensions
  ├── AI_COMPLETE for each description (snowflake-llama-3.3-70b)
  ├── Reconstruct DDL with improved descriptions
  └── Apply (or dry-run preview)
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sql` | Cost function, diagnostic proc, main enhancement proc |
| `teardown.sql` | Drops schema + warehouse |

## Main Procedure Signature

```sql
CALL SFE_ENHANCE_SEMANTIC_VIEW(
    'DATABASE.SCHEMA.VIEW_NAME',  -- semantic view
    FALSE                          -- dry_run (TRUE = preview only)
);
```

## Extension Playbook: Adding a New Enhancement Target

The procedure enhances descriptions for:
- Table descriptions
- Column descriptions
- Metric descriptions
- Dimension descriptions

To add a new target (e.g., filter descriptions):
1. Add parsing logic in the Python stored procedure to extract filter definitions
2. Add an AI_COMPLETE call with a prompt tailored to filter context
3. Include the enhanced filter description in the reconstructed DDL

## Extension Playbook: Changing the AI Model

The default model is `snowflake-llama-3.3-70b`. To change:
1. Update the model name in the `AI_COMPLETE` calls within `deploy.sql`
2. Adjust cost estimation in `SFE_ESTIMATE_ENHANCEMENT_COST` (different models have different credit rates)
3. Run `SFE_ESTIMATE_ENHANCEMENT_COST` before enhancement to preview cost impact

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS` |
| Warehouse | `SFE_ENHANCEMENT_WH` |
| Function | `SFE_ESTIMATE_ENHANCEMENT_COST` |
| Procedure | `SFE_DIAGNOSE_SEMANTIC_VIEW`, `SFE_ENHANCE_SEMANTIC_VIEW` |

## Gotchas

- Original semantic views are never modified in dry-run mode
- AI_COMPLETE costs scale with the number of objects in the semantic view
- Always run cost estimation before enhancement on large views
- The procedure uses Python 3.11 with DDL string manipulation -- not AST-based parsing
- Retry logic handles transient AI_COMPLETE failures
- Default model (`snowflake-llama-3.3-70b`) may not be available in all regions
