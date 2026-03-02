# Usage Guide

## Exploring the Classification Results

### Streamlit Dashboard

Navigate to **Projects > Streamlit** in Snowsight and open **Glaze & Classify**. The dashboard shows:

- **Overall Accuracy KPIs** — Category-level and full-match accuracy for each approach
- **Accuracy by Market** — Bar chart and table showing how each approach performs per market/language
- **Misclassified Products** — Products where traditional SQL got it wrong (filterable by market)
- **Full Comparison Detail** — Every product with all four predictions side by side
- **Live Classify** — Type any product name and see Cortex classify it in real-time

### Intelligence Agent

Navigate to **AI & ML > Snowflake Intelligence** in Snowsight. The **Glaze & Classify Assistant** can answer questions like:

- "What is the overall accuracy of each classification approach?"
- "Which products are misclassified by the traditional SQL approach?"
- "How does accuracy compare across languages?"
- "Show me all seasonal products in the Japan market"
- "Which approach works best for image-only products?"
- "What are the low-confidence predictions from the robust pipeline?"

### Direct SQL

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;

-- Overall accuracy comparison
SELECT
    ROUND(AVG(trad_category_correct) * 100, 1)   AS traditional_pct,
    ROUND(AVG(simple_category_correct) * 100, 1)  AS simple_ai_pct,
    ROUND(AVG(robust_category_correct) * 100, 1)  AS robust_ai_pct,
    ROUND(AVG(vision_category_correct) * 100, 1)  AS vision_pct
FROM CLASSIFICATION_COMPARISON;

-- Accuracy by market
SELECT market_code, language_code, total_products,
       trad_accuracy_pct, simple_accuracy_pct,
       robust_accuracy_pct, vision_accuracy_pct
FROM ACCURACY_SUMMARY
ORDER BY market_code;

-- Products where traditional SQL fails but AI succeeds
SELECT product_name, market_code, gold_category,
       trad_category, robust_category, robust_confidence
FROM CLASSIFICATION_COMPARISON
WHERE trad_category_correct = 0 AND robust_category_correct = 1
ORDER BY market_code;

-- Image-only products (hardest case)
SELECT product_name, gold_category,
       trad_category, simple_category, robust_category, vision_category
FROM CLASSIFICATION_COMPARISON
WHERE is_image_only = TRUE;
```

## The Story Arc

When presenting this demo, walk through the approaches in order:

1. **Start with Traditional SQL** — Show the CASE/LIKE/regex code. It works for English but the audience will immediately see the problem with Japanese (katakana), French (accented characters), and image-only products.

2. **Simple Cortex AI** — Show the ~10 lines of SQL. Same catalog, dramatically better results. "This took 5 minutes to write."

3. **Robust Cortex Pipeline** — Show structured output, confidence scores, language detection. "This is what production looks like." The type literal response format is the star here.

4. **SPCS Vision** — Show the container service pattern. "When you need a specialized model that goes beyond what LLMs can do."

5. **Compare** — Use the Streamlit dashboard or the Intelligence agent to explore the results. Let the audience ask their own questions.
