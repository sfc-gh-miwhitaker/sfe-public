/*==============================================================================
INTELLIGENCE AGENT - Glaze & Classify
Conversational agent for exploring classification results and product data.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE OR REPLACE AGENT GLAZE_CLASSIFIER_AGENT
  COMMENT = 'DEMO: Conversational agent for bakery product classification analysis (Expires: 2026-03-20)'
  PROFILE = '{"display_name": "Glaze & Classify Assistant", "avatar": "donut", "color": "green"}'
  FROM SPECIFICATION
  $$
  orchestration:
    budget:
      seconds: 30
      tokens: 16000

  instructions:
    system: >
      You are the Glaze & Classify assistant — an expert in product classification
      for an international bakery company operating in 6 markets (US, JP, FR, MX, UK, BR).
      You help users understand how four different classification approaches compare:
      traditional SQL, simple Cortex AI, robust Cortex AI pipeline, and SPCS vision model.
      Always cite specific numbers and percentages. If data is unavailable, say so clearly.
      Never fabricate accuracy numbers.

    orchestration: >
      Use the ProductAnalyst tool for all questions about products, classification results,
      accuracy comparisons, market breakdowns, and language analysis.
      Present results in tables when comparing multiple approaches or markets.
      Always include the total number of products in your sample when citing accuracy.

    response: >
      Format responses using Markdown tables for comparisons.
      Always show accuracy as percentages rounded to one decimal place.
      When comparing approaches, highlight the best-performing one.
      Include context about why traditional SQL struggles with non-English products.

    sample_questions:
      - question: "What is the overall accuracy of each classification approach?"
        answer: "I'll query the accuracy metrics across all products for each of the four approaches."
      - question: "Which products are misclassified by the traditional SQL approach?"
        answer: "I'll find products where the traditional SQL prediction doesn't match the gold standard category."
      - question: "How does accuracy compare across languages?"
        answer: "I'll break down accuracy by market and language for each classification approach."
      - question: "Show me all seasonal products in the Japan market"
        answer: "I'll query the Japanese market for seasonal and limited-edition products."
      - question: "Which approach works best for image-only products?"
        answer: "I'll compare classification accuracy for products that have no text description."
      - question: "What are the low-confidence predictions from the robust pipeline?"
        answer: "I'll find products where the robust Cortex pipeline had confidence below 0.7."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "ProductAnalyst"
        description: >
          Converts natural language questions into SQL queries against the bakery product
          classification dataset. Covers products across 6 international markets in 5 languages,
          with classification results from four approaches: traditional SQL, simple Cortex AI,
          robust Cortex AI pipeline, and SPCS vision model. Use this for any question about
          products, categories, accuracy, markets, or classification performance.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates visualizations from query results — bar charts for accuracy comparisons, pie charts for category distributions."

  tool_resources:
    ProductAnalyst:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GLAZE_PRODUCTS"
  $$;
