![Guide](https://img.shields.io/badge/Type-Guide-blue) ![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey) ![Expires](https://img.shields.io/badge/Expires-2027--03--04-orange) ![Status](https://img.shields.io/badge/Status-ACTIVE-brightgreen)

# Model-Agnostic Accuracy: Configuring Semantic Views and Cortex Agents

A best practices guide for building Snowflake Cortex Agents that reduce avoidable model sensitivity and make accuracy regressions measurable.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-07-29 | **Expires:** 2027-03-04 | **Status:** ACTIVE

**Audience:** Data engineers, analytics engineers, and Agent owners building reliable structured-data experiences.

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

1. Build a focused semantic view with explicit relationships, business descriptions, reusable metrics and filters, and representative VQRs.
2. Prefer governed, certified sources for official metrics and document the grain and access-policy scope.
3. Attach the view to a narrowly scoped Agent with distinct tool descriptions and orchestration instructions.
4. Run Cortex Analyst evaluations to isolate SQL correctness before running end-to-end Cortex Agent evaluations.
5. Pin committed Agent and exact evaluation metric versions when comparing CI/CD runs.
6. Start with `models.orchestration: auto`, then measure quality, latency, and consumption before choosing a different model.

## The Mental Model

> Reliable Cortex Agents minimize how much correctness depends on model-specific reasoning.

The LLM's job is to route and synthesize, not to invent your business definitions. Your job is to make the intended routing and SQL-generation behavior explicit. Every practice in this guide serves one of two goals:

1. **Reduce ambiguity** — so supported models need less inference to make the intended decision
2. **Encode business knowledge** — so the system doesn't have to infer what only your organization knows

When these conditions are met, model changes are less likely to change behavior. Configuration cannot guarantee accuracy, but it can remove avoidable ambiguity and make failures easier to diagnose.

### Trust starts before the model

Accurate SQL against the wrong or unofficial source is still the wrong answer. For official business metrics, prefer a governed semantic view or another trusted data product that your organization has reviewed for ownership, provenance, metric definitions, and access controls. Snowflake's `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` tag provides a standard way to mark an object as `CERTIFIED`; certification is a trust signal, not a substitute for evaluation. The legacy `SNOWFLAKE.CORE.CERTIFICATION_STATUS` tag remains supported but is planned for deprecation. See [Snowflake-provided tags](https://docs.snowflake.com/en/user-guide/object-tagging/snowflake-provided-tags).

Before modeling or attaching a source:

- State its grain, refresh expectations, owner, and intended business domain.
- Prefer certified objects over uncertified alternatives when both answer the same question.
- Treat the semantic view's metrics, filters, and relationships as the canonical definitions for that product.
- Label ad hoc reconstructions and uncertified fallbacks instead of presenting them as official metrics.
- Preserve row access and masking behavior in evaluation roles; a zero-row result can mean policy scope, not missing data.
- Test inaccessible, policy-filtered, empty, and zero-row paths so the Agent responds accurately rather than inventing an explanation.

Do not blend a canonical semantic-view metric with a custom reconstruction without explaining why they differ. Decide the intended grain before joining entities, especially across one-to-many relationships where an unexamined join can inflate totals.

---

## 1. The Semantic View — Reducing SQL-Generation Ambiguity

The semantic view is the largest controllable lever for structured-data accuracy. A well-built semantic view reduces how much the system must infer from names, schemas, and user phrasing.

The mechanism is straightforward: Cortex Analyst generates SQL by following rules defined in the semantic view — descriptions, verified queries, metrics, filters, and custom instructions. When those rules are precise, the search space for valid SQL collapses. When they're vague, the model has to reason its way to an answer, and different models reason differently.

### Descriptions are model behavior, not documentation

> "Comments are not decoration. They are model behavior. Cortex Analyst interprets your comments as instructions."
> — [Augusto Rosa, "What I Learned Building 24 ACCOUNT_USAGE Models in Production"](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae)

The model cannot reliably infer that `amt_ttl_pre_dsc` means "gross revenue before discounts." When you skip descriptions, you're asking the LLM to guess from column names, and different models can guess differently. An authoritative description removes that specific source of ambiguity.

Write descriptions for every logical table and business-relevant column. A useful description includes:
- What the data represents in business terms
- Calculation logic if the column is derived
- Valid values or edge cases (e.g., "Present only on failures. Use with is_success = 'NO'")
- Legacy terminology that users might still use

### Verified queries collapse the SQL search space

> "Verified queries are vital for meeting the accuracy and speed objectives. Don't skip them."
> — [Daria Rostovtseva, "Getting the Most Out of Your Structured Data with Cortex Agents"](https://medium.com/snowflake/getting-the-most-out-of-your-structured-data-with-snowflake-cortex-agents-19309b2dfcef)

Verified queries (VQRs) are not just examples. They're the system's way of saying "for questions shaped like X, here's the proven SQL." They reduce an infinite SQL search space to a curated set of patterns that Cortex Analyst can adapt to similar new questions.

Start with about 10 representative queries covering common questions and known edge cases. Use logical column names from the semantic view, not physical table columns. Add more based on actual usage; Snowflake surfaces VQR suggestions from query history and aggregated Cortex Analyst, Cortex Agent, and CoWork usage. More than 20 verified queries can make semantic-view optimization take longer.

One critical rule: don't add verified queries you haven't validated. One wrong example teaches the system bad patterns.

Add VQRs after the tables, relationships, descriptions, metrics, and filters are sound. VQRs should improve coverage and latency, not compensate for an incomplete model.

### Custom instructions make implicit knowledge explicit

Business rules live in your team's heads — fiscal year starts in April, exclude internal accounts by default, "performance" means conversion rate not page load time. Without custom instructions, the system has no way to know these things, and no model — however capable — can infer them from column names.

Use `module_custom_instructions` with two components:
- **`sql_generation`**: Data formatting, default filters, domain-specific calculation rules
- **`question_categorization`**: Guardrails — block out-of-scope topics, ask for clarification when input is ambiguous

Be specific. "If no date filter is provided, default to last 12 months" is actionable. "Filter by date" is not.

### Metrics and filters pre-compute the right answer

Pre-defined metrics (`SUM(gross_revenue * (1 - discount))`) and filters (`active_customers`, `current_fiscal_year`) give Cortex Analyst reusable business logic. Prefer entity-level Boolean filters marked with `labels: [filter]` when semantic SQL compatibility matters; standalone filters remain supported for Analyst SQL generation.

### Cortex Search for high-cardinality text

For dimensions like product names, customer names, or SKUs, where user input rarely matches the data exactly, attach a Cortex Search service to the logical dimension. Use representative sample values for low-cardinality dimensions of roughly 1–10 values. Use a search service for dimensions with more than about 10 values or values that change frequently. Do not use this literal-resolution pattern for numeric, date, or paragraph-style fields.

Sample values are semantic-view metadata and are not protected by masking policies. Use representative non-sensitive values when the underlying data is sensitive.

### Keep the context focused

Start a proof of concept with 5–10 related tables and only columns users will ask about. That is a starting scope, not a permanent hard limit. As the view grows, keep its semantic context under roughly 100,000 tokens to reduce pruning risk, latency, and accuracy loss. Split distinct business domains into separate views. Each semantic view is queried independently, so keep tables that require one SQL join in the same view.

Avoid auto-generated synonym lists. Current guidance is to add synonyms only for proprietary terms, industry language, abbreviations, and legacy names that a frontier model is unlikely to know.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| Descriptions on every table and relevant column | Reduces guessing; grounds interpretation in business meaning |
| 5–10 tables for the initial use case | Keeps early debugging manageable; expand deliberately |
| Roughly 100,000-token context guideline | Reduces pruning risk as the view, instructions, and conversation grow |
| About 10 verified queries covering common patterns | Provides proven SQL templates without using VQRs to patch weak modeling |
| `module_custom_instructions.sql_generation` | Makes implicit business rules explicit and repeatable |
| `module_custom_instructions.question_categorization` | Guards scope boundaries — blocks topics the view shouldn't answer |
| Cortex Search on high-cardinality text | Removes need for exact string matching; handles fuzzy input consistently |
| Non-sensitive sample values + `is_enum` | Shows valid values; `is_enum` means the supplied list is exhaustive |
| Synonyms only for domain-specific language | Avoids token-heavy synonym lists that add little value |
| Certified governed sources for official metrics | Signals that an asset has been verified and is ready for production use |
| Explicit grain before joins | Prevents fanout and inflated aggregates |
| Policy and zero-row tests | Distinguishes access scope from absent data |
| Validate incrementally | One table at a time, dims then metrics — know exactly what broke |

**Further reading**:
- [Best Practices for Semantic Views (modeling)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling)
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Custom Instructions in Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/custom-instructions)
- [Cortex Analyst Verified Query Repository](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository)
- [Dan Galavan, "7 Strategic AI & Semantic Layer Tips"](https://medium.com/snowflake/snowflake-in-a-nutshell-7-strategic-ai-semantic-layer-tips-78422f7e0bdc)

---

## 2. Agent Configuration — Making Routing Obvious

The orchestrator plans, selects tools, reflects on results, and decides when to respond or continue. Clear configuration reduces the model judgment required at each step, especially during tool selection.

### Narrow scope is a trust strategy

A narrow agent that's right 98% of the time on sales questions earns more user adoption than a broad agent that's right 80% on "anything." Scope isn't a limitation — it's how you build reliability that earns trust.

Define why the agent exists, who it serves, and what specific questions it should answer before adding tools or writing instructions. After an agent proves reliable in one area, replicate the pattern for others.

### Tool descriptions are a primary routing signal

> Tianxia Jia's framework separates **Description** (WHAT the tool does) from **Orchestration Instructions** (WHEN to use it). This separation makes routing explicit rather than inferred.
> — [Tianxia Jia, "Optimize Snowflake Intelligence Cortex Agent Setup"](https://medium.com/snowflake/optimize-snowflake-intelligence-cortex-agent-setup-a-complete-ai-powered-guide-f01383ac6969)

Tool descriptions, `instructions.orchestration`, tool types and schemas, and conversation context all influence planning. A vague description ("Analyzes data") forces more model inference. A precise description ("Queries structured sales data including revenue, orders, and customer metrics for the North America region. Use for quantitative questions about sales performance. Do NOT use for policy or documentation questions.") gives the planner a clearer boundary.

A useful tool description includes:
- What the tool does (capabilities)
- What data it accesses (domain/scope)
- When to use it (trigger conditions)
- When NOT to use it (boundary conditions)

### Orchestration instructions are guardrails

"For revenue questions, use Analyst; for policy questions, use Search" removes a common source of routing ambiguity. The more explicit your orchestration instructions, the less inference routing requires.

These are natural-language instructions, not deterministic program rules. Write them as explicit decision logic and verify the behavior with evaluations.

### Budget as a consumption bound

Budget configuration limits the seconds and tokens available to one Agent run. Use it to bound latency and consumption, then evaluate whether the limit leaves enough room for representative multi-step questions. A timeout or budget exhaustion can reflect an undersized budget, an overly broad request, slow tools, or unclear configuration; it is not a semantic-quality test by itself.

### Separate document search from literal resolution

A Cortex Search tool retrieves unstructured content for the Agent. Configure its current resource fields, including `search_service` and, when appropriate, `title_column`, `id_column`, and filters. This is distinct from attaching a Cortex Search service to a semantic-view dimension so Cortex Analyst can resolve literal values.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| One agent per high-value use case | Constrains decision space and makes tool selection easier to evaluate |
| Tool descriptions: WHAT + data + when + when NOT | Gives the planner explicit capability and boundary signals |
| Orchestration instructions with explicit routing rules | Reduces avoidable model judgment during planning |
| Budget (seconds + tokens) | Bounds per-run latency and token consumption |
| Current Cortex Search resource fields | Makes document retrieval and result identity explicit |

**Further reading**:
- [Build Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents)
- [Create and Manage Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Tianxia Jia, "Mastering Semantic Views and Cortex Agents with Cortex Code"](https://medium.com/snowflake/mastering-semantic-views-and-cortex-agents-with-cortex-code-ba97afcc5aa9)

---

## 3. Evaluation — Diagnosing Where Accuracy Breaks

Without measurement, you're tuning blind. A wrong answer could mean SQL generation failed, routing failed, a tool received the wrong input, or response synthesis failed. Use the narrowest evaluation layer that can isolate the problem.

### Evaluate the semantic view first

Cortex Analyst evaluations measure SQL correctness against selected verified queries. During a run, Snowflake temporarily removes each selected VQR from the view used to generate SQL, preventing that same query from guiding its own evaluation. The results show correctness, regressions, latency, expected SQL, and generated SQL.

Use this loop for structured-data failures:

1. Establish a baseline with representative VQRs that use absolute dates.
2. Inspect expected versus generated SQL and result equivalence.
3. Improve descriptions, relationships, metrics, filters, instructions, or VQR coverage.
4. Re-run with the same SQL-correctness metric version.

Semantic-view optimization can analyze verified queries and propose generalizable metrics, filters, custom instructions, descriptions, and synonyms. Human review remains required before applying suggestions.

### Evaluate the end-to-end Agent second

### The GPA Framework

Snowflake's evaluation metrics follow the Goal-Plan-Action (GPA) framework. Instead of judging only the final answer, they evaluate the agent at each stage of its reasoning:

| Metric | What it measures | What a failure tells you |
|--------|-----------------|--------------------------|
| **Tool Selection Accuracy** (Public Preview) | Did the agent pick the expected tools? | Routing failed — inspect tool descriptions and orchestration instructions |
| **Tool Execution Accuracy** (Public Preview) | Did supported tools get appropriate input and output? | Inspect tool input, semantic view, search configuration, or tool result |
| **Answer Correctness** | Does the final response match expected ground truth? | Response synthesis failed — fix response instructions or ground truth |
| **Logical Consistency** | Is the reasoning internally consistent? (reference-free) | Agent contradicted itself — usually indicates instruction conflicts |

This decomposition is what makes the framework diagnostic rather than just pass/fail.

### Ground truth design is where most teams under-invest

Vague ground truth produces vague scores. "Should return revenue data" tells you nothing when it fails. Precise rubrics give actionable signals:

- **State the expected value** with tolerance: "Revenue must be between 1.1M and 1.3M for Q1 2026"
- **Use absolute dates**: "Between January and March 2026" not "last quarter" (relative dates drift)
- **Include what the response should NOT contain**: catches hallucination and scope creep
- **For out-of-scope queries**: specify that the agent should refuse, not fabricate

### Run evaluations after every config change

Semantic views are tightly coupled systems. Changing one description can shift how VQRs match, which changes SQL generation downstream. Automated evaluations on each change give you confidence to iterate without regression.

### Pin versions for reproducible comparisons

Evaluate a committed Agent version such as `VERSION$3`, not mutable `LIVE`, when results must be comparable across CI/CD runs. Pin the same exact metric version, such as `v3_0`, to freeze the judge family, prompt, rubric, and thresholds. A major-only version such as `v3` adopts the latest `v3` minor release. As of this review, `v3` uses current large-context judges, while `v1` depends on legacy `claude-4-sonnet` and may be unavailable to accounts that did not use it before August 12, 2026. See [Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations).

Upgrade exact metric versions deliberately when judge changes or model deprecations are announced, then establish a new baseline.

### Know what native evaluations do not cover

Current Agent evaluations do not exercise MCP tools. Tool selection and execution metrics also skip code execution and skill invocations. Sandbox files are not persisted during code-execution evaluations, and session attributes are not passed for row-access-policy scenarios. Test those paths separately before production rollout.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| Enable every applicable system metric | Each diagnoses a different failure mode and requires suitable ground truth |
| Absolute dates in ground truth | Eliminates temporal drift that produces false failures |
| Include negatives ("should NOT contain") | Catches hallucination that positive-only rubrics miss |
| Run after every config change | Semantic views are coupled; one change can cascade |
| Compare runs side-by-side (up to 3) | Shows whether a change improved or regressed specific queries |
| Scope input queries to fixed time windows | Prevents ground truth staleness over time |
| Target a committed Agent version | Prevents mutable configuration from invalidating comparisons |
| Pin one exact current metric version | Freezes judge behavior and score thresholds for comparable runs |
| Test unsupported tool paths separately | Covers MCP, skill, code-file, and session-attribute gaps |

**Further reading**:
- [Cortex Agent Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
- [Michael Segner, "Monitoring Cortex Agent Performance Using Trace Data"](https://medium.com/snowflake/monitoring-cortex-agent-performance-using-trace-data-8f40dd3e012c)

---

## 4. Model Selection as a Performance and Quality Decision

Once the semantic layer is strong, model selection can focus more on latency and consumption, but quality still has to be measured. Different models can plan and synthesize differently even with the same configuration.

### The cognitive floor

A well-configured semantic view lowers the cognitive floor for the orchestrator. When VQRs, descriptions, and routing instructions are precise, supported models need less inference to reach the intended path. This reduces, but does not eliminate, sensitivity to model capability.

The spectrum:

| Semantic layer quality | Model requirement | Result |
|------------------------|-------------------|--------|
| Weak (vague descriptions, no VQRs, no routing rules) | Higher model sensitivity | More reasoning is required; quality, latency, and cost become less predictable |
| Strong (precise descriptions, VQRs, explicit routing) | Broader model choice | Lower ambiguity; validate quality, latency, and consumption per model |

### If accuracy drops when you switch models, that's diagnostic

It is a useful diagnostic signal that the semantic layer or Agent instructions may contain ambiguity. Inspect those layers first, then decide whether the remaining quality difference justifies a different model.

Common gaps exposed by weaker models:
- Missing VQRs for frequently asked question patterns
- Vague descriptions that require inference
- Ambiguous tool descriptions that require reasoning about scope
- Missing custom instructions for business logic that "everyone knows"

### Start with `auto`, then measure

> **Current architecture:** Cortex Agents read the semantic-view definition and generate SQL against the physical tables directly. Since April 2026, they no longer delegate SQL generation to Cortex Analyst as a separate Agent step. Standalone Cortex Analyst remains a separate service with its own model-selection behavior.

> "Prioritize database structure optimization first, enable advanced model access, and maintain lean semantic models to achieve production-ready conversational analytics."
> — [Tianxia Jia, "Optimizing Snowflake Cortex Analyst Performance"](https://medium.com/snowflake/optimizing-snowflake-cortex-analyst-performance-48ae4735c8e1)

1. **Set `models.orchestration: auto`** — lets Snowflake select the recommended model available to the account
2. **Choose an approved cross-region scope** — expose the required Agent and evaluation models without exceeding data-residency policy
3. **Measure accuracy** — run evaluations to establish baseline scores
4. **Test across model tiers** — if accuracy holds, you can optimize for latency
5. **If accuracy drops, inspect configuration first** — then retain the model whose measured tradeoff meets the use case

A faster response is preferable only when measured quality and governance requirements still hold.

### Budget constraints as design discipline

Set seconds and token budgets from representative workloads. Tightening a budget can reveal slow tools or broad planning paths, but budget exhaustion does not prove that the semantic view is under-specified.

**Further reading**:
- [Build Agents — Model Selection](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents)
- [Tianxia Jia, "Optimizing Snowflake Cortex Analyst Performance"](https://medium.com/snowflake/optimizing-snowflake-cortex-analyst-performance-48ae4735c8e1)

---

## 5. Iteration — Building a Feedback Loop

The difference between a production system and a demo is iteration. A semantic view isn't a one-time artifact — it's a living system that improves with use. The teams that build feedback loops outperform the teams that "set and forget."

### Treat it like production code

> "The best implementations I've seen treat the YAML file with the same care as production application code: version controlled, reviewed, tested."
> — [Preethi Kaluva, "The Hidden Gotchas of Snowflake's Cortex Analyst"](https://medium.com/snowflake/the-hidden-gotchas-of-snowflakes-cortex-analyst-203a64e68ca9)

Store your semantic view definition (YAML or DDL) in Git. Trigger evaluations on pull requests. Deploy only when tests pass. Roll back by redeploying the previous known-good version. This is the same discipline as application code because the failure modes are the same — a bad change goes to production and users get wrong answers.

### Leverage suggestions from real usage

Snowflake surfaces two categories of suggestions based on actual usage patterns:

- **VQR suggestions**: Frequently asked questions that don't match existing verified queries — low-effort accuracy gains
- **Filter/metric suggestions**: SQL patterns from query history not yet represented in the model — closes coverage gaps

These aren't theoretical improvements. They come from production user behavior, which means they target the gaps users actually hit.

### Validate incrementally

> "Test each table addition separately. When it breaks, you know exactly what caused it."
> — [Augusto Rosa](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae)

When adding to a semantic view: one table at a time, dimensions first, then metrics, validate at each step. When something breaks, you know exactly what caused it. Batch changes make debugging exponentially harder.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| Semantic view definition in Git | Version control, peer review, rollback — same discipline as application code |
| Analyst and Agent evaluations triggered on PR | Separates SQL regressions from end-to-end Agent regressions |
| Review VQR suggestions from usage data | Real user questions without matching VQRs — targeted accuracy gains |
| Review filter/metric suggestions | Frequently used SQL patterns not yet in the model |
| Promote via schema cloning or account replication | Validated configs move across environments without manual recreation |
| Validate incrementally (one table, dims then metrics) | Know exactly what caused a break |

**Further reading**:
- [Best Practices for Semantic Views (modeling)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling)
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Suggestions for Semantic Models and Views](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-suggestions)
- [Kaivalya Pendse, "From Prototype to Production: Version Control for Cortex Agent Workflow"](https://medium.com/snowflake/from-prototype-to-production-how-we-added-version-control-to-our-snowflake-cortex-agent-workflow-595e94d43a56)

---

## Appendix: Quick-Reference Checklist

For practitioners who have read the guide and want a reminder during implementation.

### Semantic View

- [ ] Official metrics use governed sources certified with `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` where available
- [ ] Grain, owner, freshness, business domain, and access-policy scope are documented
- [ ] Ad hoc reconstructions and uncertified fallbacks are clearly labeled
- [ ] Every logical table and business-relevant column has a clear description
- [ ] Initial scope starts with 5–10 related tables and stays near the 100,000-token guideline
- [ ] About 10 verified queries cover common questions and edge cases
- [ ] Verified queries use logical column names (not physical)
- [ ] `module_custom_instructions.sql_generation` defines business rules
- [ ] `module_custom_instructions.question_categorization` sets scope boundaries
- [ ] Cortex Search is attached only to high-cardinality or frequently changing text dimensions
- [ ] Sample values are representative and non-sensitive; `is_enum` is set only for exhaustive lists
- [ ] Synonyms are limited to proprietary, industry, abbreviation, and legacy terms
- [ ] Metrics pre-define reusable calculations
- [ ] Entity-level filters pre-define common Boolean conditions where possible

### Agent Configuration

- [ ] Agent scoped to one high-value use case
- [ ] Tool descriptions include: what, data scope, when to use, when NOT
- [ ] Orchestration instructions provide explicit routing rules
- [ ] Budget is tested against representative multi-step questions
- [ ] Cortex Search resources use current documented fields
- [ ] Cross-region inference scope meets model availability and data-residency requirements
- [ ] `SHOW CORTEX BASE MODELS` is reviewed before naming a model
- [ ] `models.orchestration` starts with `auto`

### Evaluation

- [ ] Evaluation dataset created with absolute dates
- [ ] Ground truth includes expected values with tolerance
- [ ] Ground truth includes what response should NOT contain
- [ ] Semantic view has a Cortex Analyst SQL-correctness baseline
- [ ] Applicable Agent metrics are enabled; TSA and TEA are treated as Public Preview
- [ ] Comparable runs target a committed Agent version and pin the same exact metric version (for example, `v3_0`)
- [ ] Baseline evaluation run completed
- [ ] Evaluations automated in CI/CD pipeline
- [ ] MCP, skill, code-file, and session-attribute paths are tested outside native evaluations
- [ ] Inaccessible, policy-filtered, empty, and zero-row behaviors are tested

### Iteration

- [ ] Semantic view definition stored in Git
- [ ] Evaluations trigger on PR/config change
- [ ] VQR suggestions reviewed regularly
- [ ] Filter/metric suggestions reviewed regularly
- [ ] Changes validated incrementally

---

## Related Guides

- [Best practices for semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)

## External References

### Official Documentation

| Topic | Link |
|-------|------|
| Semantic view best practices (modeling) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling) |
| Semantic view best practices (dev pipeline) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev) |
| Build agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents) |
| Cortex Agent evaluations | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations) |
| Verified Query Repository | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository) |
| Custom instructions | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/custom-instructions) |
| Suggestions for semantic models | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-suggestions) |
| Overview of semantic views | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/overview) |
| Create and manage agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage) |
| Snowflake-provided certification tags | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/object-tagging/snowflake-provided-tags) |

### Practitioner Posts (Snowflake Builders Blog)

| Author | Title | Link |
|--------|-------|------|
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
|-------|------|
| Cortex Sense for Enterprise AI Agents | [snowflake.com](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/) |
| Using AI to Improve AI with Cortex Analyst | [snowflake.com](https://www.snowflake.com/en/engineering-blog/using-ai-improving-ai/) |
| Best Practices for Creating Semantic Views (Quickstart) | [snowflake.com](https://www.snowflake.com/en/developers/guides/best-practices-semantic-views-cortex-analyst/) |
