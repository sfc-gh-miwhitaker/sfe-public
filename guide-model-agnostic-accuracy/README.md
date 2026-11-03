![Guide](https://img.shields.io/badge/Type-Guide-blue) ![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey) ![Expires](https://img.shields.io/badge/Expires-2027--01--02-orange) ![Status](https://img.shields.io/badge/Status-ACTIVE-brightgreen)

# Model-Agnostic Accuracy: Configuring Semantic Views and Cortex Agents

A best practices guide for building Snowflake Cortex Agents that reduce avoidable model sensitivity and make accuracy regressions measurable.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-07-29 | **Last verified:** 2026-11-03 | **Expires:** 2027-01-02 | **Status:** ACTIVE

**Audience:** Data engineers, analytics engineers, and Agent owners building reliable structured-data experiences.

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

1. Choose governed, certified sources for official metrics and document their grain and access-policy scope.
2. Build a focused semantic view with explicit relationships, business descriptions, reusable metrics and filters, semantic-view custom instructions, and representative verified queries (VQRs).
3. Attach the view to a narrowly scoped Agent with distinct tool descriptions and Agent orchestration instructions; start with `models.orchestration: auto`.
4. Run Cortex Analyst evaluations to diagnose semantic-view SQL problems, then gate releases on end-to-end Cortex Agent evaluations. An Analyst pass does not prove the Agent's SQL is correct.
5. Compare committed Agent versions and exact evaluation metric versions, measuring quality, latency, and consumption across repeated runs.

**See it assembled:** The [Sales Performance Assistant worked example](WORKED-EXAMPLE.md) takes one business question through a source contract, complete semantic-view and Agent configurations, and fixture-backed acceptance cases. It uses one structured-data tool rather than demonstrating every feature.

## The Mental Model

> Reliable Cortex Agents minimize how much correctness depends on model-specific reasoning.

The LLM's job is to route and synthesize, not to invent your business definitions. Your job is to make the intended routing and SQL-generation behavior explicit. Every practice in this guide serves one of two goals:

1. **Reduce ambiguity:** so supported models need less inference to make the intended decision
2. **Encode business knowledge:** so the system doesn't have to infer what only your organization knows

Configuration cannot guarantee accuracy or identical behavior across models. It can remove avoidable ambiguity, and evaluation tells you whether that worked.

### Trust starts before the model

Accurate SQL against the wrong or unofficial source is still the wrong answer. For official business metrics, prefer a governed semantic view or another trusted data product that your organization has reviewed for ownership, provenance, metric definitions, and access controls. Snowflake's `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` tag provides a standard way to mark an object as `CERTIFIED`; certification is a trust signal, not a substitute for evaluation. See [Snowflake-provided tags](https://docs.snowflake.com/en/user-guide/object-tagging/snowflake-provided-tags).

**Status of the certification tag.** Snowflake-provided tags in the `SNOWFLAKE.TAGS` schema became [generally available on 2026-10-20](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-20-snowflake-provided-tags-ga). Snowflake recommends `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` over the legacy `SNOWFLAKE.CORE.CERTIFICATION_STATUS`, which is still supported but will be deprecated in a future release. Two practical consequences:

- **Plan the migration.** New certification workflows should use the `SNOWFLAKE.TAGS` tag. Keep checks that read the legacy tag in place until every consumer reads the successor.
- **The allowed values are fixed.** `CERTIFICATION_STATUS` accepts exactly `DRAFT`, `TO BE REVIEWED`, `IN REVIEW`, `CERTIFIED`, `REJECTED`, and `DEPRECATED`. Account administrators can't modify its definition or allowed values, and the `OOB_TAG_ADMIN` application role doesn't apply to it. Applying the tag requires the `SNOWFLAKE.OOB_TAG_APPLY` application role. Plan your review workflow around these six values.

Before modeling or attaching a source:

- State its grain, refresh expectations, owner, and intended business domain.
- Prefer certified objects over uncertified alternatives when both answer the same question, but treat the tag as one input to review, not proof. Confirm owner, refresh, grain, lineage, and policy scope for each object.
- Treat the semantic view's metrics, filters, and relationships as the canonical definitions for that product.
- Label ad hoc reconstructions and uncertified fallbacks instead of presenting them as official metrics.
- Preserve row access and masking behavior in evaluation roles; a zero-row result can mean policy scope, not missing data.
- Test inaccessible, policy-filtered, empty, and zero-row paths so the Agent responds accurately rather than inventing an explanation.

Do not blend a canonical semantic-view metric with a custom reconstruction without explaining why they differ. Decide the intended grain before joining entities, especially across one-to-many relationships where an unexamined join can inflate totals.

---

## 1. The Semantic View: Reducing SQL-Generation Ambiguity

The semantic view is where you encode business meaning for structured data. A well-built semantic view reduces how much the system must infer from names, schemas, and user phrasing.

SQL generation draws on what the semantic view defines: descriptions, relationships, metrics, filters, custom instructions, and verified queries. Precise definitions leave fewer decisions to the model; vague ones leave more, and different models can resolve them differently.

For a complete configuration, see the worked example's [semantic-view YAML](WORKED-EXAMPLE.md#3-configure-the-semantic-view), including explicit grain, a channel relationship, completed-only metrics, and three VQR patterns.

### Descriptions are model behavior, not documentation

> "Comments are not decoration. They are model behavior. Cortex Analyst interprets your comments as instructions."
> Augusto Rosa, ["What I Learned Building 24 ACCOUNT_USAGE Models in Production"](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae)

The model cannot reliably infer that `amt_ttl_pre_dsc` means "gross revenue before discounts." When you skip descriptions, the model guesses from column names. An authoritative description removes that specific source of ambiguity.

Write descriptions for every logical table and business-relevant column. A useful description includes:

- What the data represents in business terms
- Calculation logic if the column is derived
- Valid values or edge cases (e.g., "Present only on failures. Use with is_success = 'NO'")
- Legacy terminology that users might still use

### Verified queries give proven SQL patterns

Verified queries pair a question with validated SQL. Snowflake documents that they improve accuracy on similar questions, can reduce latency, and let the system generalize from them to suggest filters, metrics, and descriptions. See [modeling best practices](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling).

Start with your most common questions and known edge cases, and add more based on real usage. Use logical table and column names from the semantic view, prefixing logical tables with `__` (for example, `__orders`), not physical names. In SQL DDL, the equivalent clause is `AI_VERIFIED_QUERIES ( name AS ( QUESTION '...' SQL '...' ) )`; see [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view).

Validate every verified query before adding it. Snowflake warns that invalid or inaccurate verified queries can negatively impact accuracy.

Add VQRs after the tables, relationships, descriptions, metrics, and filters are sound. Use them to improve coverage and latency, not to compensate for an incomplete model.

### Semantic-view custom instructions make implicit knowledge explicit

Business rules live in your team's heads: fiscal year starts in April, exclude internal accounts by default, "performance" means conversion rate. No model can infer these from column names.

Put rules about the data in the semantic view's `module_custom_instructions` (DDL: `AI_SQL_GENERATION` and `AI_QUESTION_CATEGORIZATION`):

- **`sql_generation`**: Applies during SQL generation for all queries: business logic, default filters, fiscal-year definitions, data quirks
- **`question_categorization`**: Applies only to question understanding: when to reject a question or ask for clarification

These are not the same as Agent `instructions.orchestration` and `instructions.response`, which govern tool routing and answer presentation (Section 2). Keep calculation rules with the semantic view and conversation rules with the Agent. Migrate any legacy top-level `custom_instructions` into `module_custom_instructions.sql_generation`. When the view is used through a Cortex Agent, Snowflake recommends writing these instructions in plain natural language. See [Custom instructions](https://docs.snowflake.com/en/user-guide/views-semantic/custom-instructions).

Be specific. "If no date filter is provided, default to last 12 months" is actionable. "Filter by date" is not.

### Metrics and filters encode reusable logic

Pre-defined metrics (`SUM(gross_revenue * (1 - discount))`) and filters (`active_customers`, `current_fiscal_year`) give SQL generation reusable business logic. Prefer entity-level Boolean filters marked with `labels: [filter]`: the semantic SQL compiler uses entity-level filters, while standalone `filters` are supported only for Cortex Analyst SQL generation. See the [YAML specification](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-view-yaml-spec).

### Cortex Search for high-cardinality text

For dimensions like product names, customer names, or company names, where user input rarely matches the data exactly, attach a Cortex Search service to the logical dimension (`cortex_search_service`). Snowflake's general rule: use a search service for high-cardinality text columns (more than about 10 distinct values) and representative sample values for low-cardinality dimensions. Avoid search services on numeric, date, or paragraph-style text fields.

Sample values are semantic-view metadata and are not masked by masking policies. Use representative non-sensitive values when the underlying data is sensitive. See [development best practices](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev).

### Keep the context focused

Start a proof of concept with 5-10 related tables and only the columns users will ask about. Cortex Agents impose no hard size limit, but keep the semantic view under roughly 100,000 tokens to reduce the chance of pruning, which adds latency and can reduce answer quality. Split distinct business domains into separate views. Each semantic view is queried independently and Cortex Agents do not join across separate semantic views, so keep tables that must be joined in the same view.

Avoid auto-generated synonym lists. Current guidance is to add synonyms only for unique or industry-specific terms a model is unlikely to know; auto-generated synonyms often reduce semantic-view quality.

### Summary of practices

| Practice | Why it matters |
| ---------- | --------------- |
| Descriptions on every table and relevant column | Reduces guessing; grounds interpretation in business meaning |
| 5-10 tables for the initial use case | Keeps early debugging manageable; expand deliberately |
| Roughly 100,000-token guideline | Reduces pruning risk as the view, instructions, and conversation grow |
| Validated VQRs for common questions and edge cases | Provides proven SQL patterns without using VQRs to patch weak modeling |
| `module_custom_instructions.sql_generation` | Makes implicit business rules explicit and repeatable |
| `module_custom_instructions.question_categorization` | Sets scope boundaries and clarification rules for the view |
| Cortex Search on high-cardinality text | Resolves inexact literal values |
| Non-sensitive sample values + `is_enum` | Shows valid values; `is_enum` means the supplied list is exhaustive |
| Synonyms only for domain-specific language | Avoids token-heavy synonym lists that add little value |
| Certified governed sources for official metrics | Signals that an asset has been verified and is ready for production use |
| Explicit grain before joins | Prevents fanout and inflated aggregates |
| Policy and zero-row tests | Distinguishes access scope from absent data |
| Validate incrementally | One table at a time, dims then metrics; isolates what broke |

**Further reading**:

- [Best Practices for Semantic Views (modeling)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling)
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Custom instructions](https://docs.snowflake.com/en/user-guide/views-semantic/custom-instructions)
- [Verified Query Repository](https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-repository)
- [Dan Galavan, "7 Strategic AI & Semantic Layer Tips"](https://medium.com/snowflake/snowflake-in-a-nutshell-7-strategic-ai-semantic-layer-tips-78422f7e0bdc)

---

## 2. Agent Configuration: Making Routing Obvious

The orchestrator plans, selects tools, reflects on results, and decides when to respond or continue. Clear configuration reduces the model judgment required at each step, especially during tool selection.

The worked example's [Agent specification](WORKED-EXAMPLE.md#4-configure-the-agent) shows these choices together: one tool, clear scope, clarification behavior, and response instructions.

### Narrow scope is a trust strategy

Snowflake recommends narrowing each Agent to a specific, high-value use case. Define why the agent exists, who it serves, and what specific questions it should answer before adding tools or writing instructions. After an agent proves reliable in one area, replicate the pattern for others. See [Build agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents).

### Tool descriptions are a primary routing signal

> Tianxia Jia's framework separates **Description** (WHAT the tool does) from **Orchestration Instructions** (WHEN to use it). This separation makes routing explicit rather than inferred.
> Tianxia Jia, ["Optimize Snowflake Intelligence Cortex Agent Setup"](https://medium.com/snowflake/optimize-snowflake-intelligence-cortex-agent-setup-a-complete-ai-powered-guide-f01383ac6969)

Snowflake warns that unclear tool descriptions can create cascading failures. A vague description ("Analyzes data") forces more model inference. A precise description ("Queries structured sales data including revenue, orders, and customer metrics for the North America region. Use for quantitative questions about sales performance. Do NOT use for policy or documentation questions.") gives the planner a clearer boundary.

A useful tool description includes:

- What the tool does (capabilities)
- What data it accesses (domain/scope)
- When to use it (trigger conditions)
- When NOT to use it (boundary conditions)

### Orchestration instructions are guardrails

Agent `instructions.orchestration` holds routing rules such as "For revenue questions, use Analyst; for policy questions, use Search." `instructions.response` controls how answers are presented. Neither replaces the semantic view's `module_custom_instructions`, which govern SQL generation and question categorization for that view.

These are natural-language instructions, not deterministic program rules or authorization controls. Write them as explicit decision logic and verify the behavior with evaluations.

### Budget as a consumption bound

`orchestration.budget` limits the seconds and tokens available to one Agent request; if both are set, whichever is hit first ends the request. Use it to bound latency and consumption, then evaluate whether the limit leaves enough room for representative multi-step questions. Budget exhaustion can reflect an undersized budget, an overly broad request, slow tools, or unclear configuration; it is not a semantic-quality test by itself.

### Separate document search from literal resolution

A Cortex Search tool retrieves unstructured content for the Agent. Configure its resource fields: `search_service` and, when appropriate, `title_column`, `id_column`, and `filter`. This is distinct from attaching a Cortex Search service to a semantic-view dimension so SQL generation can resolve literal values. See the [Agent REST schema](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api).

### Summary of practices

| Practice | Why it matters |
| ---------- | --------------- |
| One agent per high-value use case | Constrains decision space and makes tool selection easier to evaluate |
| Tool descriptions: WHAT + data + when + when NOT | Gives the planner explicit capability and boundary signals |
| Orchestration instructions with explicit routing rules | Reduces avoidable model judgment during planning |
| Budget (seconds + tokens) | Bounds per-request latency and token consumption |
| Documented Cortex Search resource fields | Makes document retrieval and result identity explicit |

**Further reading**:

- [Build Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents)
- [Create and Manage Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Tianxia Jia, "Mastering Semantic Views and Cortex Agents with Cortex Code"](https://medium.com/snowflake/mastering-semantic-views-and-cortex-agents-with-cortex-code-ba97afcc5aa9)

---

## 3. Evaluation: Diagnosing Where Accuracy Breaks

Without measurement, you're tuning blind. A wrong answer could mean SQL generation failed, routing failed, a tool received the wrong input, or response synthesis failed. Use the narrowest evaluation layer that can isolate the problem.

### Evaluate the semantic view first

[Cortex Analyst evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst-evaluations) execute generated SQL and compare results against selected verified queries, reporting accuracy, regressions, latency, expected SQL, and generated SQL.

**How the selected set affects the run.** Snowflake creates a temporary semantic-view copy with all selected VQRs removed together; unselected VQRs remain and continue to guide SQL generation. Two consequences:

- Selecting every VQR (the default when none are listed) runs the evaluation with no VQR guidance at all. That measures generalization from descriptions, metrics, filters, and instructions alone, which is a different context from production, where all VQRs are present.
- Changing the selected set changes both what is scored and what guides generation. Keep the selection fixed when comparing runs, and record it with the run.

**Treat this as a semantic-view diagnostic, not a release gate for the Agent.** Since [April 13, 2026](https://docs.snowflake.com/en/release-notes/2026/other/2026-04-13-cortex-agents-agentic-analyst), Cortex Agents generate SQL directly rather than delegating to the Cortex Analyst service, so the SQL an Agent runs can differ from the SQL an Analyst evaluation scored. A clean Analyst baseline does not tell you the Agent will query the view correctly. Gate promotion on Agent evaluations that check the SQL and results the Agent actually produced: for example, `tool_execution_accuracy` with expected SQL or result rows in `tool_output`, plus `answer_correctness` against literal values.

Use this loop for structured-data failures:

1. Establish a baseline with representative VQRs that use absolute dates.
2. Inspect expected versus generated SQL and result equivalence.
3. Improve descriptions, relationships, metrics, filters, semantic-view custom instructions, or VQR coverage.
4. Re-run with the same selected VQRs and the same exact SQL-correctness metric version.

**Semantic-view optimization (Preview).** [Optimization](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/analyst-optimization) is an Open Preview feature that analyzes verified queries and suggests additions such as filters, metrics, and descriptions; you start it with **Improve** on an evaluation run or **Get more suggestions**. Suggestions require human review before you accept them. **Cost:** optimization runs your verified queries on the warehouse you select, up to four times per verified query, and can take from minutes to hours for dozens of slow queries; more than 20 verified queries can make it take longer. Size the warehouse and the VQR set accordingly.

### Evaluate the end-to-end Agent second

### The GPA Framework

Snowflake's Agent evaluation metrics follow the Goal-Plan-Action (GPA) framework. Instead of judging only the final answer, they evaluate the agent at each stage of its reasoning:

| Metric | What it measures | Where to look when it fails |
| -------- | ----------------- | -------------------------- |
| **Tool Selection Accuracy** (Public Preview) | Did the agent invoke the expected tools? | Compare expected and actual calls; inspect routing instructions and whether ground truth allows valid alternatives |
| **Tool Execution Accuracy** (Public Preview) | Did scored tools get appropriate input and return appropriate output? | Inspect tool input, semantic view, search configuration, or tool result |
| **Answer Correctness** | Does the final response match expected ground truth? | Inspect ground truth, retrieval, SQL, tool results, and synthesis to locate the mismatch |
| **Logical Consistency** | Is reasoning consistent across instructions, planning, and tool calls? (reference-free) | Inspect contradictions in the trace |

A low score points to where to investigate, not to a unique root cause. Tool Selection Accuracy is deterministic and uses no LLM judge; the other system metrics use judges. See [Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations).

The worked example includes [acceptance questions and ground-truth JSON](WORKED-EXAMPLE.md#5-define-what-a-correct-answer-looks-like) with literal expected amounts, held-out questions, and clarification and refusal cases.

### Ground truth design

Vague ground truth produces vague scores. "Should return revenue data" tells you nothing when it fails. Snowflake recommends plain-language rubrics built from literal, verifiable values:

- **State the expected value** with tolerance: "Revenue must be between 1.1M and 1.3M for Q1 2026"
- **Use absolute dates**: "Between January and March 2026" not "last quarter" (relative dates drift)
- **Include what the response should NOT contain**: catches fabrication and scope creep
- **For out-of-scope queries**: specify that the agent should refuse, not fabricate

### Run evaluations after every config change

Changing one description, metric, or instruction can change SQL generation for questions you did not touch. Automated evaluations on each change catch those regressions before release.

### Pin versions for reproducible comparisons

Evaluate a committed Agent version such as `VERSION$3`, not mutable `LIVE`, when results must be comparable across CI/CD runs. Pin the same exact metric version, such as `v3_0`, to freeze the judge, prompt, rubric, and thresholds. A major-only version such as `v3` adopts the latest `v3` minor release.

Pinning fixes the configuration, not the result. Each run re-invokes the Agent and scores a newly generated trace, and orchestration is non-deterministic, so the same pinned Agent version and metric version can take different tool paths and score differently. Snowflake notes that `answer_correctness` is usually the most stable; `tool_selection_accuracy`, `tool_execution_accuracy`, and `logical_consistency` read the trace and expose path variability. Before gating CI/CD on a threshold, run the same dataset several times with fixed inputs, the same role, and a stable data snapshot to learn its normal range, then gate on that range. For the committed version you gate on, Snowflake recommends naming the orchestration model rather than `auto`, so a model change behind `auto` is not mistaken for agent variance; `auto` remains the right starting point while you are still choosing a model (Section 4). See [Interpret score variance across runs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations).

**Judge lifecycle: the `v1` judge has reached end-of-life.** `claude-4-sonnet`, the only `v1` judge and the default judge for custom metrics, entered the legacy state on 2026-08-12 and reached end-of-life on 2026-10-14 (`SHOW CORTEX BASE MODELS` reports `lifecycle_status = EOL`). After end-of-life no account can run a metric version or custom metric that depends on it, and pinned versions fail rather than roll forward. Snowflake's [announced behavior change BCR-2442](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2442) moves unversioned system metrics, Analyst `sql_correctness`, and `version: auto` from `v1` to `v3`, and moves custom metrics with an omitted model or `model: auto` to `claude-sonnet-4-6`, falling back to `openai-gpt-5.4` when that model isn't allowed or available. Explicit settings don't change. Do not depend on the default: set an exact supported version, such as `v3_0`, on every system metric and an explicit `model` on every custom metric.

Scores from different metric versions aren't directly comparable. Re-baseline and recalibrate thresholds when you move off `v1`, and track judge consumption in `CORTEX_REST_API_USAGE_HISTORY`, because judge models have different credit rates. Tool Selection Accuracy uses no judge, so its scores don't change. Keep earlier `v1` results for reference only.

Confirm that the evaluation role can use the judge models through an approved cross-region scope: `v3` uses `claude-sonnet-4-6` or `openai-gpt-5.4`, and no judge model runs on Google Cloud, so accounts there need `ANY_REGION`. `SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;` reports lifecycle status, `legacy_date`, and `eol_date`; catalog visibility alone does not prove permission to run a model. Keep the schema qualifier so the command searches the model catalog rather than the session's current schema. Snowflake recommends `v3` for long traces because its judges have context windows of about one million tokens.

Upgrade exact metric versions deliberately when judge changes or model deprecations are announced, then establish a new baseline.

### Know what native evaluations do not cover

Agent evaluations don't call MCP server tools, so results won't reflect MCP behavior. Tool Selection Accuracy and Tool Execution Accuracy score only Cortex Analyst, Cortex Search, web search, and custom tools; other tool types are left out of those scores. Code execution has no side effects during an evaluation, so file outputs can't be evaluated. Evaluation runs don't pass session attributes, so agents whose queries depend on them, including through row access policies, can't be evaluated accurately. Test those paths separately before production rollout.

### Summary of practices

| Practice | Why it matters |
| ---------- | --------------- |
| Enable every applicable system metric | Each diagnoses a different failure mode and requires suitable ground truth |
| Absolute dates in ground truth | Eliminates temporal drift that produces false failures |
| Include negatives ("should NOT contain") | Catches fabrication that positive-only rubrics miss |
| Fixed, recorded VQR selection for Analyst runs | The selection controls both what is scored and what guides generation |
| Run after every config change | One change can affect unrelated questions |
| Compare runs side-by-side (up to 3) | Shows whether a change improved or regressed specific queries |
| Target a committed Agent version | Prevents mutable configuration from invalidating comparisons |
| Pin one exact supported metric version and custom-metric model | Freezes judge behavior; avoids the end-of-life `v1` judge |
| Test unscored tool paths separately | Covers MCP, unscored tool types, code-file output, and session-attribute gaps |

**Further reading**:

- [Cortex Agent Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
- [Michael Segner, "Monitoring Cortex Agent Performance Using Trace Data"](https://medium.com/snowflake/monitoring-cortex-agent-performance-using-trace-data-8f40dd3e012c)

---

## 4. Model Selection as a Performance and Quality Decision

Once the semantic layer is strong, model selection can weigh latency and consumption alongside quality, but quality still has to be measured. Different models can plan and synthesize differently even with the same configuration.

### Configuration narrows, but does not remove, model sensitivity

When VQRs, descriptions, semantic-view custom instructions, and Agent routing instructions are precise, models have fewer gaps to fill. Treat that as a hypothesis to test per model, not a guarantee.

| Semantic layer quality | What to expect | What to do |
| ------------------------ | ------------------- | -------- |
| Weak (vague descriptions, no VQRs, no routing rules) | More decisions are left to the model | Fix the configuration before comparing models |
| Strong (precise descriptions, VQRs, explicit routing) | Fewer decisions are left to the model | Validate quality, latency, and consumption per model |

### If accuracy drops when you switch models, inspect configuration first

A model-specific drop is a reason to look for ambiguity before concluding that you need a different model. Check for:

- Missing VQRs for frequently asked question patterns
- Vague descriptions that require inference
- Ambiguous tool descriptions that require reasoning about scope
- Missing semantic-view custom instructions for business logic that "everyone knows"

Then decide whether any remaining, measured quality difference justifies a different model.

### Start with `auto`, then measure

> **Current architecture:** Since April 13, 2026, Cortex Agents that use semantic views generate SQL directly rather than delegating SQL generation to the Cortex Analyst service as a separate step. Agent trace and response blocks show `system_execute_sql`. Standalone Cortex Analyst remains a separate service; Snowflake recommends transitioning to Cortex Agents.

1. **Set `models.orchestration: auto`:** Snowflake recommends `auto`, which selects the highest-quality model available to the account
2. **Choose an approved cross-region scope:** cross-region inference is disabled by default; enable the scope that exposes the required Agent and evaluation models without exceeding data-residency policy
3. **Measure accuracy:** run evaluations to establish baseline scores
4. **Test candidate models:** review `SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS` for lifecycle status before naming one, and compare quality, latency, and consumption
5. **If accuracy drops, inspect configuration first:** then pin, by name, the model whose measured tradeoff meets the use case

A faster response is preferable only when measured quality and governance requirements still hold.

### Budget constraints as design discipline

Set seconds and token budgets from representative workloads. Tightening a budget can reveal slow tools or broad planning paths, but budget exhaustion does not prove that the semantic view is under-specified.

**Further reading**:

- [Build Agents: Model Selection](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents)
- [Tianxia Jia, "Optimizing Snowflake Cortex Analyst Performance"](https://medium.com/snowflake/optimizing-snowflake-cortex-analyst-performance-48ae4735c8e1)

---

## 5. Iteration: Building a Feedback Loop

A semantic view isn't a one-time artifact. Snowflake recommends treating modeling as an iterative loop: measure, close gaps found in real usage, and re-measure.

### Treat it like production code

> "The best implementations I've seen treat the YAML file with the same care as production application code: version controlled, reviewed, tested."
> Preethi Kaluva, ["The Hidden Gotchas of Snowflake's Cortex Analyst"](https://medium.com/snowflake/the-hidden-gotchas-of-snowflakes-cortex-analyst-203a64e68ca9)

Snowflake recommends storing the semantic view YAML or SQL DDL in Git, triggering CI/CD on changes to run tests and accuracy checks, deploying only when they pass, and rolling back by redeploying the previous known-good version. Store the Agent specification the same way.

### Review suggestions from real usage

Snowflake surfaces [suggestions](https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-suggestions) that require human review before they are added:

- **VQR suggestions**: frequent, non-trivial questions with no similar existing verified query, up to 10 at a time
- **Filter and metric suggestions**: frequently used SQL expressions from query history that the view doesn't yet represent, up to 10 of each at a time

Query-history suggestions appear only after the view has accumulated enough query activity.

### Validate incrementally

> "Test each table addition separately. When it breaks, you know exactly what caused it."
> [Augusto Rosa](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae)

When adding to a semantic view, add one table at a time, dimensions first, then metrics, and validate at each step. Small changes make a break attributable to a single cause.

### Summary of practices

| Practice | Why it matters |
| ---------- | --------------- |
| Semantic view definition in Git | Version control, peer review, rollback |
| Analyst and Agent evaluations triggered on PR | Separates semantic-view SQL regressions from end-to-end Agent regressions |
| Review VQR suggestions from usage data | Frequent user questions without matching VQRs |
| Review filter/metric suggestions | Frequently used SQL patterns not yet in the model |
| Promote via schema cloning or account replication | Semantic views are cloned with their schema and can be replicated across accounts |
| Validate incrementally (one table, dims then metrics) | Attributes a break to a single change |

**Further reading**:

- [Best Practices for Semantic Views (modeling)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling)
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Suggestions for Semantic Models and Views](https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-suggestions)
- [Kaivalya Pendse, "From Prototype to Production: Version Control for Cortex Agent Workflow"](https://medium.com/snowflake/from-prototype-to-production-how-we-added-version-control-to-our-snowflake-cortex-agent-workflow-595e94d43a56)

---

## Appendix: Quick-Reference Checklist

For practitioners who have read the guide and want a reminder during implementation.

### Semantic View

- [ ] Official metrics use governed sources reviewed per object for `SNOWFLAKE.TAGS.CERTIFICATION_STATUS`, owner, refresh, grain, lineage, and policy scope
- [ ] Checks that read the legacy `SNOWFLAKE.CORE.CERTIFICATION_STATUS` tag have a migration plan
- [ ] Grain, owner, freshness, business domain, and access-policy scope are documented
- [ ] Ad hoc reconstructions and uncertified fallbacks are clearly labeled
- [ ] Every logical table and business-relevant column has a clear description
- [ ] Initial scope starts with 5-10 related tables and stays near the 100,000-token guideline
- [ ] Validated verified queries cover common questions and edge cases
- [ ] Verified queries use logical names (`__table`, logical columns), not physical names
- [ ] `module_custom_instructions.sql_generation` defines business rules
- [ ] `module_custom_instructions.question_categorization` sets scope boundaries
- [ ] Cortex Search is attached only to high-cardinality text dimensions
- [ ] Sample values are representative and non-sensitive; `is_enum` is set only for exhaustive lists
- [ ] Synonyms are limited to unique or industry-specific terms
- [ ] Metrics pre-define reusable calculations
- [ ] Entity-level filters (`labels: [filter]`) pre-define common Boolean conditions

### Agent Configuration

- [ ] Agent scoped to one high-value use case
- [ ] Tool descriptions include: what, data scope, when to use, when NOT
- [ ] `instructions.orchestration` provides explicit routing rules, kept separate from semantic-view custom instructions
- [ ] Budget is tested against representative multi-step questions
- [ ] Cortex Search resources use documented fields
- [ ] Cross-region inference scope meets model availability and data-residency requirements
- [ ] `SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS` is reviewed before naming a model
- [ ] `models.orchestration` starts with `auto`; the gated committed version names its model

### Evaluation

- [ ] Evaluation dataset created with absolute dates
- [ ] Ground truth includes expected values with tolerance
- [ ] Ground truth includes what response should NOT contain
- [ ] Semantic view has a Cortex Analyst SQL-correctness baseline (diagnostic only)
- [ ] Analyst comparison runs use the same recorded VQR selection; selecting all VQRs removes all VQR guidance
- [ ] Release gate uses Agent evaluations that check the Agent's own SQL and results
- [ ] Applicable Agent metrics are enabled; TSA and TEA are treated as Public Preview
- [ ] Comparable runs target a committed Agent version and pin the same exact metric version (for example, `v3_0`)
- [ ] No system metric or custom metric depends on the end-of-life `v1` judge or on the default
- [ ] CI/CD thresholds are set from the score range of repeated runs, not a single run
- [ ] Judge upgrades get a new baseline
- [ ] Evaluations automated in CI/CD pipeline
- [ ] MCP, unscored tool types, code-file output, and session-attribute paths are tested outside native evaluations
- [ ] Inaccessible, policy-filtered, empty, and zero-row behaviors are tested

### Iteration

- [ ] Semantic view definition stored in Git
- [ ] Evaluations trigger on PR/config change
- [ ] VQR suggestions reviewed regularly
- [ ] Filter/metric suggestions reviewed regularly
- [ ] Optimization (Preview) runs are sized for warehouse cost and reviewed before suggestions are accepted
- [ ] Changes validated incrementally

---

## Development Tools

Cortex Code and other coding assistants can use [AGENTS.md](AGENTS.md) for this guide's editing conventions and the project skill in [.claude/skills/](.claude/skills/guide-model-agnostic-accuracy/SKILL.md) for its maintenance workflow. The guide deploys no Snowflake objects and requires no cleanup. See [CONTRIBUTING.md](../CONTRIBUTING.md) for repository checks and [site/README.md](../site/README.md) for reader-site validation.

## Related Guides

- [Best practices for semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)

## External References

### Official Documentation

| Topic | Link |
| ------- | ------ |
| Semantic view best practices (modeling) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling) |
| Semantic view best practices (dev pipeline) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev) |
| Semantic view YAML specification | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-view-yaml-spec) |
| CREATE SEMANTIC VIEW | [docs.snowflake.com](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view) |
| Build agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents) |
| Agent REST configuration schema | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api) |
| Cortex Agent evaluations | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations) |
| Evaluation default and judge change (BCR-2442) | [docs.snowflake.com](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2442) |
| Improved SQL generation in Cortex Agents | [docs.snowflake.com](https://docs.snowflake.com/en/release-notes/2026/other/2026-04-13-cortex-agents-agentic-analyst) |
| Cortex Analyst evaluations | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst-evaluations) |
| Semantic view optimization (Preview) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/analyst-optimization) |
| Verified Query Repository | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-repository) |
| Custom instructions | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/custom-instructions) |
| Suggestions for semantic models and views | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-suggestions) |
| Overview of semantic views | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/overview) |
| Create and manage agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage) |
| Snowflake-provided tags | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/object-tagging/snowflake-provided-tags) |
| Snowflake-provided tags GA | [docs.snowflake.com](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-20-snowflake-provided-tags-ga) |

### Practitioner Posts (Snowflake Builders Blog)

| Author | Title | Link |
| -------- | ------- | ------ |
| Augusto Rosa | What I Learned Building 24 ACCOUNT_USAGE Models in Production | [medium.com](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae) |
| Tianxia Jia | Mastering Semantic Views and Cortex Agents with Cortex Code | [medium.com](https://medium.com/snowflake/mastering-semantic-views-and-cortex-agents-with-cortex-code-ba97afcc5aa9) |
| Tianxia Jia | Optimize Snowflake Intelligence Cortex Agent Setup | [medium.com](https://medium.com/snowflake/optimize-snowflake-intelligence-cortex-agent-setup-a-complete-ai-powered-guide-f01383ac6969) |
| Tianxia Jia | Optimizing Snowflake Cortex Analyst Performance | [medium.com](https://medium.com/snowflake/optimizing-snowflake-cortex-analyst-performance-48ae4735c8e1) |
| Daria Rostovtseva | Getting the Most Out of Your Structured Data with Cortex Agents | [medium.com](https://medium.com/snowflake/getting-the-most-out-of-your-structured-data-with-snowflake-cortex-agents-19309b2dfcef) |
| Dan Galavan | 7 Strategic AI & Semantic Layer Tips | [medium.com](https://medium.com/snowflake/snowflake-in-a-nutshell-7-strategic-ai-semantic-layer-tips-78422f7e0bdc) |
| Michael Segner | Monitoring Cortex Agent Performance Using Trace Data | [medium.com](https://medium.com/snowflake/monitoring-cortex-agent-performance-using-trace-data-8f40dd3e012c) |
| Preethi Kaluva | The Hidden Gotchas of Snowflake's Cortex Analyst | [medium.com](https://medium.com/snowflake/the-hidden-gotchas-of-snowflakes-cortex-analyst-203a64e68ca9) |
| Kaivalya Pendse | From Prototype to Production: Version Control for Cortex Agent Workflow | [medium.com](https://medium.com/snowflake/from-prototype-to-production-how-we-added-version-control-to-our-snowflake-cortex-agent-workflow-595e94d43a56) |

### Snowflake Engineering Blog

| Title | Link |
| ------- | ------ |
| Cortex Sense for Enterprise AI Agents | [snowflake.com](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/) |
| Using AI to Improve AI with Cortex Analyst | [snowflake.com](https://www.snowflake.com/en/engineering-blog/using-ai-improving-ai/) |
| Best Practices for Creating Semantic Views (Quickstart) | [snowflake.com](https://www.snowflake.com/en/developers/guides/best-practices-semantic-views-cortex-analyst/) |
