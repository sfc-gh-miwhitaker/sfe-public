# AI_TRANSLATE Usage Example

**Feature:** Snowflake Cortex AI_TRANSLATE
**Status:** GA (September 25, 2025)
**Supersedes:** TRANSLATE (SNOWFLAKE.CORTEX)

---

## Overview

AI_TRANSLATE is the enhanced successor to TRANSLATE (SNOWFLAKE.CORTEX), offering:

- **20% cost savings**: fewer input tokens for typical sentences
- **Enhanced quality**: industry-leading accuracy in all language directions
- **23 supported languages**: including 9 new languages (Hebrew, Greek, Turkish, Finnish, Arabic, Croatian, Czech, Romanian, Norwegian)
- **Better auto-detection**: recognizes when text is already in target language
- **Mixed language support**: handles "Spanglish" and other mixed-language text

**Documentation:** [Snowflake AI_TRANSLATE Reference](https://docs.snowflake.com/en/sql-reference/functions/ai_translate)

---

## Basic Usage

### Simple Translation

```sql
-- Translate English to Spanish
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE('Hello, how are you?', 'en', 'es') AS translated_text;
-- Result: 'Hola, ¿cómo estás?'

-- Translate French to English
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE('Bonjour le monde', 'fr', 'en') AS translated_text;
-- Result: 'Hello world'
```

### Auto-Detect Source Language

If you don't know the source language, use an empty string:

```sql
-- Let AI_TRANSLATE detect the source language
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE('Guten Tag', '', 'en') AS translated_text;
-- Result: 'Good day' (automatically detected German)
```

### Mixed Language Translation (Spanglish Example)

```sql
-- Translate mixed English/Spanish to pure English
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    'Estoy muy excited about this proyecto!',
    '',  -- Auto-detect mixed languages
    'en'
) AS translated_text;
-- Result: 'I am very excited about this project!'
```

---

## Supported Languages

| Language | Code | Example Input | Example Output (to English) |
|----------|------|---------------|----------------------------|
| Arabic | `ar` | مرحبا | Hello |
| Chinese | `zh` | 你好 | Hello |
| Croatian | `hr` | Bok | Hello |
| Czech | `cs` | Ahoj | Hello |
| Dutch | `nl` | Hallo | Hello |
| English | `en` | Hello | (source language) |
| Finnish | `fi` | Hei | Hello |
| French | `fr` | Bonjour | Hello |
| German | `de` | Hallo | Hello |
| Greek | `el` | Γεια | Hello |
| Hebrew | `he` | שלום | Hello |
| Hindi | `hi` | नमस्ते | Hello |
| Italian | `it` | Ciao | Hello |
| Japanese | `ja` | こんにちは | Hello |
| Korean | `ko` | 안녕하세요 | Hello |
| Norwegian | `no` | Hei | Hello |
| Polish | `pl` | Cześć | Hello |
| Portuguese | `pt` | Olá | Hello |
| Romanian | `ro` | Bună | Hello |
| Russian | `ru` | Привет | Hello |
| Spanish | `es` | Hola | Hello |
| Swedish | `sv` | Hej | Hello |
| Turkish | `tr` | Merhaba | Hello |

---

## Practical Use Cases for Cortex Cost Calculator

### Use Case 1: Translate Service Type Names for International Teams

If you're sharing Cortex usage reports with international teams, translate service names:

```sql
-- Create multilingual service type reference
CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_SERVICE_TYPES_MULTILINGUAL
    COMMENT = 'DEMO: cortex-trail - Multilingual service type names via AI_TRANSLATE | EXPIRES: See deploy_all.sql'
AS
SELECT
    service_type AS service_type_en,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'es') AS service_type_es,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'fr') AS service_type_fr,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'de') AS service_type_de,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'ja') AS service_type_ja
FROM (
    SELECT DISTINCT service_type
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
);

-- Query results
SELECT
    service_type_en,
    service_type_es,
    service_type_fr,
    service_type_de,
    service_type_ja
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_SERVICE_TYPES_MULTILINGUAL;
```

**Example Output:**

| service_type_en | service_type_es | service_type_fr | service_type_de | service_type_ja |
|-----------------|-----------------|-----------------|-----------------|-----------------|
| Cortex Analyst | Analista Cortex | Analyste Cortex | Cortex Analyst | Cortex アナリスト |
| Cortex Search | Búsqueda Cortex | Recherche Cortex | Cortex Suche | Cortex 検索 |
| Cortex Functions | Funciones Cortex | Fonctions Cortex | Cortex Funktionen | Cortex 機能 |
| Document AI | IA de Documentos | IA de documents | Dokument-KI | ドキュメント AI |

### Use Case 2: Translate Cost Summary Reports

Generate cost summaries in multiple languages:

```sql
-- Generate cost summary with translated descriptions
WITH cost_summary AS (
    SELECT
        service_type,
        SUM(total_credits) AS total_credits,
        ROUND(SUM(total_credits) * 3.00, 2) AS total_cost_usd
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
    WHERE date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY service_type
)
SELECT
    service_type,
    total_credits,
    total_cost_usd,
    -- Spanish summary
    SNOWFLAKE.CORTEX.AI_TRANSLATE(
        CONCAT('Service: ', service_type, ' consumed ', total_credits, ' credits costing $', total_cost_usd),
        'en',
        'es'
    ) AS summary_es,
    -- French summary
    SNOWFLAKE.CORTEX.AI_TRANSLATE(
        CONCAT('Service: ', service_type, ' consumed ', total_credits, ' credits costing $', total_cost_usd),
        'en',
        'fr'
    ) AS summary_fr
FROM cost_summary
ORDER BY total_cost_usd DESC;
```

### Use Case 3: Translate Query Comments for Global Teams

If you're sharing SQL queries with international colleagues:

```sql
-- Translate SQL comments for documentation
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    'This query calculates the average daily cost per user for Cortex services over the last 30 days.',
    'en',
    'zh'  -- Chinese
) AS query_description_chinese;

-- Result: '此查询计算过去30天Cortex服务的每用户平均每日成本。'
```

---

## Cost Comparison: TRANSLATE vs AI_TRANSLATE

### Legacy TRANSLATE Function

```sql
-- Legacy function (still works, but less efficient)
SELECT SNOWFLAKE.CORTEX.TRANSLATE(
    'The Cortex Cost Calculator helps you forecast spending.',
    'en',
    'es'
) AS translated;
```

**Token consumption:** ~15-20 tokens for this sentence

### New AI_TRANSLATE Function

```sql
-- New function (20% fewer tokens)
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    'The Cortex Cost Calculator helps you forecast spending.',
    'en',
    'es'
) AS translated;
```

**Token consumption:** ~12-16 tokens for same sentence

**Cost Savings:**
- 20% reduction in tokens = 20% cost reduction
- For 1 million translations/month: $600 -> $480 (saves $120/month)
- Compounds with improved quality (fewer retries needed)

---

## Migration Guide: TRANSLATE -> AI_TRANSLATE

### Find All Usage

```sql
-- Search for TRANSLATE function usage in stored procedures
SELECT
    procedure_name,
    procedure_definition
FROM SNOWFLAKE.INFORMATION_SCHEMA.PROCEDURES
WHERE procedure_definition ILIKE '%TRANSLATE(%';

-- Search in views
SELECT
    table_name,
    view_definition
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE view_definition ILIKE '%TRANSLATE(%';
```

### Migration Pattern

**Before:**
```sql
CREATE OR REPLACE VIEW customer_feedback_translated AS
SELECT
    feedback_id,
    SNOWFLAKE.CORTEX.TRANSLATE(feedback_text, 'en', 'es') AS feedback_es
FROM customer_feedback;
```

**After:**
```sql
CREATE OR REPLACE VIEW customer_feedback_translated AS
SELECT
    feedback_id,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'es') AS feedback_es
FROM customer_feedback;
```

**Migration Steps:**
1. Test AI_TRANSLATE in development environment
2. Compare quality with legacy TRANSLATE (should be equal or better)
3. Update views/procedures one at a time
4. Monitor token consumption (should decrease by ~20%)
5. Keep legacy TRANSLATE as fallback if needed

---

## Best Practices

### 1. Use Auto-Detection When Source is Unknown

```sql
-- GOOD: Let AI_TRANSLATE detect language
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(user_comment, '', 'en') AS comment_english;

-- AVOID: Guessing wrong source language wastes tokens
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(user_comment, 'es', 'en') AS comment_english;
-- (If user_comment is actually French, result will be poor)
```

### 2. Batch Translations for Efficiency

```sql
-- GOOD: Batch multiple translations in single query
SELECT
    feedback_id,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'es') AS feedback_es,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'fr') AS feedback_fr,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'de') AS feedback_de
FROM customer_feedback;

-- AVOID: Separate queries (more overhead)
-- Query 1: Spanish only
-- Query 2: French only
-- Query 3: German only
```

### 3. Cache Translations for Static Content

```sql
-- GOOD: Translate once, store in table
CREATE TABLE service_type_translations AS
SELECT
    service_type,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'es') AS service_type_es,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(service_type, 'en', 'fr') AS service_type_fr
FROM (
    SELECT DISTINCT service_type
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
);

-- AVOID: Re-translating same text repeatedly
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE('Cortex Analyst', 'en', 'es')
FROM large_table;  -- Translates same text millions of times!
```

### 4. Leverage Mixed Language Support

```sql
-- GOOD: Handle mixed-language customer feedback
SELECT
    customer_id,
    original_text,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(original_text, '', 'en') AS normalized_english
FROM customer_feedback
WHERE original_text RLIKE '[^\x00-\x7F]';  -- Contains non-ASCII (likely mixed)
```

---

## Performance Considerations

### Token Limits

- **Maximum input length:** 4,096 tokens (~16,000 characters)
- For longer text, split into chunks:

```sql
-- Example: Translate long documents in chunks
WITH chunked_text AS (
    SELECT
        document_id,
        ROW_NUMBER() OVER (PARTITION BY document_id ORDER BY chunk_id) AS chunk_num,
        SUBSTR(document_text, (chunk_id * 4000) + 1, 4000) AS text_chunk
    FROM documents
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY NULL) - 1 AS chunk_id FROM TABLE(GENERATOR(ROWCOUNT => 10)))
    WHERE SUBSTR(document_text, (chunk_id * 4000) + 1, 4000) != ''
)
SELECT
    document_id,
    chunk_num,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(text_chunk, 'en', 'es') AS translated_chunk
FROM chunked_text;
```

### Cost Estimation

Calculate translation costs using CORTEX_AISQL_USAGE_HISTORY:

```sql
-- Estimate monthly translation costs
SELECT
    DATE_TRUNC('month', start_time) AS month,
    model_name,
    SUM(tokens) AS total_tokens,
    SUM(token_credits) AS total_credits,
    ROUND(SUM(token_credits) * 3.00, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE function_name = 'AI_TRANSLATE'
    AND start_time >= DATEADD('month', -3, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC;
```

---

## Troubleshooting

### Issue: Translation Quality is Poor

**Solution:** Use auto-detection instead of specifying source language

```sql
-- AVOID: Poor quality (wrong source language specified)
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(text, 'es', 'en');  -- Text is actually Portuguese

-- BETTER: Auto-detect source language
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(text, '', 'en');
```

### Issue: Text Too Long (>4096 tokens)

**Solution:** Split into chunks or summarize first

```sql
-- Option 1: Summarize then translate
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    SNOWFLAKE.CORTEX.SUMMARIZE(long_document),
    'en',
    'es'
) AS translated_summary;

-- Option 2: Extract key sections then translate
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    SUBSTR(long_document, 1, 15000),  -- First ~4000 tokens
    'en',
    'es'
) AS translated_excerpt;
```

### Issue: Unexpected Costs

**Solution:** Monitor usage and implement caching

```sql
-- Check daily translation costs
SELECT
    DATE(start_time) AS usage_date,
    COUNT(*) AS translation_count,
    SUM(token_credits) AS daily_credits,
    ROUND(SUM(token_credits) * 3.00, 2) AS daily_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE function_name = 'AI_TRANSLATE'
    AND start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1 DESC;
```

---

## Integration with Cortex Cost Calculator

Add translation costs to your monitoring:

```sql
-- Enhanced cost view with translation breakdown
CREATE OR REPLACE VIEW V_CORTEX_COST_WITH_TRANSLATION AS
SELECT
    date,
    service_type,
    total_credits,
    -- Separate translation costs
    CASE WHEN service_type = 'Cortex Functions'
         THEN total_credits * 0.15  -- Estimate: 15% is translation
         ELSE 0
    END AS estimated_translation_credits,
    ROUND(total_credits * 3.00, 2) AS total_cost_usd
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT;
```

---

## Summary

**Key Takeaways:**
- AI_TRANSLATE offers 20% cost savings over legacy TRANSLATE
- Supports 23 languages with enhanced quality
- Auto-detection handles mixed languages (Spanglish, etc.)
- Drop-in replacement: change function name, same parameters
- Ideal for multilingual reports, customer feedback, and documentation

**Next Steps:**
1. Identify current TRANSLATE usage in your code
2. Test AI_TRANSLATE in development
3. Migrate views and procedures incrementally
4. Monitor token reduction in ACCOUNT_USAGE

**Resources:**
- [AI_TRANSLATE Documentation](https://docs.snowflake.com/en/sql-reference/functions/ai_translate)
- [Cortex LLM Functions Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Language Codes Reference](https://docs.snowflake.com/en/sql-reference/functions/ai_translate#usage-notes)

---

**Last Updated:** 2025-11-12
**Version:** 1.0 (aligned with Cortex Trail v2.6)
