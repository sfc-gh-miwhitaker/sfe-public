# Model-Agnostic Accuracy: Configuring Semantic Views and Cortex Agents

[![Expiration](https://img.shields.io/badge/expires-2026--08--28-yellow)]()

A best practices guide for building Snowflake Cortex Agents that produce consistent, correct results regardless of which LLM is used for orchestration.

Pair-programmed by SE Community + Cortex Code

---

## The Mental Model

> The accuracy of a Cortex Agent is determined at **configuration time**, not at query time.

The LLM's job is to route and synthesize — not to understand your business. Your job is to make the routing decision obvious and the SQL generation deterministic. Every practice in this guide serves one of two goals:

1. **Reduce ambiguity** — so any model can make the right decision
2. **Encode business knowledge** — so the system doesn't have to infer what only your organization knows

When these two conditions are met, the orchestration model becomes interchangeable. Accuracy becomes a property of the system, not a property of the model.

---

## 1. The Semantic View — Making SQL Generation Deterministic

The semantic view is the single largest lever for accuracy. A well-built semantic view makes the difference between "works great with the best model" and "works great with any model."

The mechanism is straightforward: Cortex Analyst generates SQL by following rules defined in the semantic view — descriptions, verified queries, metrics, filters, and custom instructions. When those rules are precise, the search space for valid SQL collapses. When they're vague, the model has to reason its way to an answer, and different models reason differently.

### Descriptions are model behavior, not documentation

> "Comments are not decoration. They are model behavior. Cortex Analyst interprets your comments as instructions."
> — [Augusto Rosa, "What I Learned Building 24 ACCOUNT_USAGE Models in Production"](https://medium.com/snowflake/snowflake-semantic-views-what-i-learned-building-24-account-usage-models-in-production-566035fa56ae)

The model cannot infer that `amt_ttl_pre_dsc` means "gross revenue before discounts." When you skip descriptions, you're asking the LLM to guess from column names — and different LLMs guess differently. A description eliminates that variance entirely.

What a useful description includes:
- What the data represents in business terms
- Calculation logic if the column is derived
- Valid values or edge cases (e.g., "Present only on failures. Use with is_success = 'NO'")
- Legacy terminology that users might still use

### Verified queries collapse the SQL search space

> "Verified queries are vital for meeting the accuracy and speed objectives. Don't skip them."
> — [Daria Rostovtseva, "Getting the Most Out of Your Structured Data with Cortex Agents"](https://medium.com/snowflake/getting-the-most-out-of-your-structured-data-with-snowflake-cortex-agents-19309b2dfcef)

Verified queries (VQRs) are not just examples. They're the system's way of saying "for questions shaped like X, here's the proven SQL." They reduce an infinite SQL search space to a curated set of patterns that Cortex Analyst can adapt to similar new questions.

Start with 10–20 queries covering your most common questions. Use logical column names from the semantic view (not physical table columns). Add more based on actual usage — Snowflake surfaces VQR suggestions from real user behavior.

One critical rule: don't add verified queries you haven't validated. One wrong example teaches the system bad patterns.

### Custom instructions make implicit knowledge explicit

Business rules live in your team's heads — fiscal year starts in April, exclude internal accounts by default, "performance" means conversion rate not page load time. Without custom instructions, the system has no way to know these things, and no model — however capable — can infer them from column names.

Use `module_custom_instructions` with two components:
- **`sql_generation`**: Data formatting, default filters, domain-specific calculation rules
- **`question_categorization`**: Guardrails — block out-of-scope topics, ask for clarification when input is ambiguous

Be specific. "If no date filter is provided, default to last 12 months" is actionable. "Filter by date" is not.

### Metrics and filters pre-compute the right answer

Pre-defined metrics (`SUM(gross_revenue * (1 - discount))`) and named filters (`active_customers`, `current_fiscal_year`) ensure every query uses the same calculation. Without them, each question re-derives the logic from scratch, introducing inconsistency across different phrasings of the same question.

### Cortex Search for high-cardinality text

For columns like product names, customer names, or SKUs — where user input rarely matches the data exactly — attach a Cortex Search service. This prevents the system from guessing with fuzzy `LIKE` conditions and provides consistent matching regardless of how the user phrases their input.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| Description on every column | Eliminates model guessing; grounds interpretation in business meaning |
| 5–10 tables per domain, organized by use case | Constrains join space; models don't reason about irrelevant relationships |
| 10–20 verified queries covering common patterns | Provides proven SQL templates; new questions follow established patterns |
| `module_custom_instructions.sql_generation` | Makes implicit business rules explicit and deterministic |
| `module_custom_instructions.question_categorization` | Guards scope boundaries — blocks topics the view shouldn't answer |
| Cortex Search on high-cardinality text | Removes need for exact string matching; handles fuzzy input consistently |
| Sample values + `is_enum` | Tells any model what valid values look like without inference |
| Validate incrementally | One table at a time, dims then metrics — know exactly what broke |

**Further reading**:
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Custom Instructions in Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/custom-instructions)
- [Cortex Analyst Verified Query Repository](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository)
- [Dan Galavan, "7 Strategic AI & Semantic Layer Tips"](https://medium.com/snowflake/snowflake-in-a-nutshell-7-strategic-ai-semantic-layer-tips-78422f7e0bdc)

---

## 2. Agent Configuration — Making Routing Obvious

The orchestrator's job is tool selection: given a user question, which tool should handle it? When your configuration makes that decision trivial, any model can make it correctly. When it's ambiguous, you're relying on model reasoning — which varies by model quality and introduces fragility.

### Narrow scope is a trust strategy

A narrow agent that's right 98% of the time on sales questions earns more user adoption than a broad agent that's right 80% on "anything." Scope isn't a limitation — it's how you build reliability that earns trust.

Define why the agent exists, who it serves, and what specific questions it should answer before adding tools or writing instructions. After an agent proves reliable in one area, replicate the pattern for others.

### Tool descriptions are the orchestrator's only routing signal

> Tianxia Jia's framework separates **Description** (WHAT the tool does) from **Orchestration Instructions** (WHEN to use it). This separation makes routing explicit rather than inferred.
> — [Tianxia Jia, "Optimize Snowflake Intelligence Cortex Agent Setup"](https://medium.com/snowflake/optimize-snowflake-intelligence-cortex-agent-setup-a-complete-ai-powered-guide-f01383ac6969)

Everything the agent knows about when to use Cortex Analyst vs. Cortex Search comes from what you wrote in the tool description. A vague description ("Analyzes data") forces the model to reason about tool selection. A precise description ("Queries structured sales data including revenue, orders, and customer metrics for the North America region. Use for quantitative questions about sales performance. Do NOT use for policy or documentation questions.") makes routing nearly deterministic.

A useful tool description includes:
- What the tool does (capabilities)
- What data it accesses (domain/scope)
- When to use it (trigger conditions)
- When NOT to use it (boundary conditions)

### Orchestration instructions are guardrails

"For revenue questions, use Analyst; for policy questions, use Search" eliminates an entire class of routing ambiguity. The more explicit your orchestration instructions, the less the model's quality matters for routing decisions.

These are not suggestions to the model — they're rules that constrain tool selection. Write them as decision logic, not prose.

### Budget as a forcing function

Budget configuration (seconds + tokens) prevents the orchestrator from over-thinking. A well-configured system shouldn't need extended reasoning to make a routing decision. If it does, that's a signal that tool descriptions or orchestration instructions are unclear.

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| One agent per high-value use case | Constrains decision space; makes tool selection nearly deterministic |
| Tool descriptions: WHAT + data + when + when NOT | Orchestrator's only routing signal — ambiguity here cascades into wrong answers |
| Orchestration instructions with explicit routing rules | Removes model judgment from routing; makes it rule-following |
| Budget (seconds + tokens) | Prevents runaway reasoning; forces system to act on clear signals |
| `columns_and_descriptions` for Cortex Search | Tells orchestrator which columns are filterable/searchable for correct queries |

**Further reading**:
- [Build Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents)
- [Create and Manage Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Tianxia Jia, "Mastering Semantic Views and Cortex Agents with Cortex Code"](https://medium.com/snowflake/mastering-semantic-views-and-cortex-agents-with-cortex-code-ba97afcc5aa9)

---

## 3. Evaluation — Diagnosing Where Accuracy Breaks

Without measurement, you're tuning blind. A wrong answer could mean routing failed, SQL generation failed, or the response synthesis failed. The evaluation framework tells you exactly where, so you fix the right thing instead of guessing.

### The GPA Framework

Snowflake's evaluation metrics follow the Goal-Plan-Action (GPA) framework. Instead of judging only the final answer, they evaluate the agent at each stage of its reasoning:

| Metric | What it measures | What a failure tells you |
|--------|-----------------|--------------------------|
| **Tool Selection Accuracy** | Did the agent pick the right tool? | Routing failed — fix tool descriptions or orchestration instructions |
| **Tool Execution Accuracy** | Did the tool get correct input and produce correct output? | SQL generation or search query failed — fix semantic view or search config |
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

### Summary of practices

| Practice | Why it matters |
|----------|---------------|
| Enable all 4 system metrics | Each diagnoses a different failure mode; together they pinpoint root cause |
| Absolute dates in ground truth | Eliminates temporal drift that produces false failures |
| Include negatives ("should NOT contain") | Catches hallucination that positive-only rubrics miss |
| Run after every config change | Semantic views are coupled; one change can cascade |
| Compare runs side-by-side (up to 3) | Shows whether a change improved or regressed specific queries |
| Scope input queries to fixed time windows | Prevents ground truth staleness over time |

**Further reading**:
- [Cortex Agent Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
- [Michael Segner, "Monitoring Cortex Agent Performance Using Trace Data"](https://medium.com/snowflake/monitoring-cortex-agent-performance-using-trace-data-8f40dd3e012c)

---

## 4. Model Selection as a Performance Decision

This is where you move from "it works" to "it works efficiently." Once your semantic layer is strong, model selection becomes a latency and cost optimization — not an accuracy decision.

### The cognitive floor

A well-configured semantic view lowers the cognitive floor for the orchestrator. When VQRs, descriptions, and routing instructions are precise, the orchestration decision is trivial — any supported model can make it correctly. This decouples accuracy from model capability.

The spectrum:

| Semantic layer quality | Model requirement | Result |
|------------------------|-------------------|--------|
| Weak (vague descriptions, no VQRs, no routing rules) | Frontier model required | Model compensates with reasoning — expensive, slow, fragile |
| Strong (precise descriptions, VQRs, explicit routing) | Any supported model | Routing is deterministic — fast, cheap, stable |

### If accuracy drops when you switch models, that's diagnostic

It means the semantic layer has gaps that the more capable model was papering over with reasoning. The fix is always to strengthen the layer — not to pin the model.

Common gaps exposed by weaker models:
- Missing VQRs for frequently asked question patterns
- Vague descriptions that require inference
- Ambiguous tool descriptions that require reasoning about scope
- Missing custom instructions for business logic that "everyone knows"

### Start with `auto`, then optimize

> "Prioritize database structure optimization first, enable advanced model access, and maintain lean semantic models to achieve production-ready conversational analytics."
> — [Tianxia Jia, "Optimizing Snowflake Cortex Analyst Performance"](https://medium.com/snowflake/optimizing-snowflake-cortex-analyst-performance-48ae4735c8e1)

1. **Set `orchestration: auto`** — establishes your accuracy baseline with the highest quality model available
2. **Enable cross-region inference** (`CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`) — accesses full model catalog
3. **Measure accuracy** — run evaluations to establish baseline scores
4. **Test across model tiers** — if accuracy holds, you can optimize for latency
5. **If accuracy drops, fix the semantic layer** — the weaker model exposed configuration gaps

A 2-second response from a faster model is better than a 5-second response from a frontier model — but only when the semantic layer is strong enough that both produce correct results.

### Budget constraints as design discipline

Tighter budgets (fewer seconds, fewer tokens) force tighter semantic views. If the agent needs extended reasoning time to route correctly, the configuration is under-specified. Budget constraints surface these gaps early.

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
| Evaluations triggered on PR | Catches regressions before they reach users |
| Review VQR suggestions from usage data | Real user questions without matching VQRs — targeted accuracy gains |
| Review filter/metric suggestions | Frequently used SQL patterns not yet in the model |
| Promote via schema cloning or account replication | Validated configs move across environments without manual recreation |
| Validate incrementally (one table, dims then metrics) | Know exactly what caused a break |

**Further reading**:
- [Best Practices for Semantic Views (dev pipeline)](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
- [Suggestions for Semantic Models and Views](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-suggestions)
- [Kaivalya Pendse, "From Prototype to Production: Version Control for Cortex Agent Workflow"](https://medium.com/snowflake/from-prototype-to-production-how-we-added-version-control-to-our-snowflake-cortex-agent-workflow-595e94d43a56)

---

## Appendix: Quick-Reference Checklist

For practitioners who have read the guide and want a reminder during implementation.

### Semantic View

- [ ] Every column has a business-friendly description (not just the name)
- [ ] 5–10 tables per domain, organized by use case
- [ ] 10–20 verified queries covering most common questions
- [ ] Verified queries use logical column names (not physical)
- [ ] `module_custom_instructions.sql_generation` defines business rules
- [ ] `module_custom_instructions.question_categorization` sets scope boundaries
- [ ] Cortex Search attached to high-cardinality text columns
- [ ] Sample values provided; `is_enum` set where values are exhaustive
- [ ] Metrics pre-define reusable calculations
- [ ] Named filters pre-define common conditions

### Agent Configuration

- [ ] Agent scoped to one high-value use case
- [ ] Tool descriptions include: what, data scope, when to use, when NOT
- [ ] Orchestration instructions provide explicit routing rules
- [ ] Budget set (seconds + tokens)
- [ ] `columns_and_descriptions` populated for Cortex Search tools
- [ ] Cross-region inference enabled (`CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`)
- [ ] Model set to `auto`

### Evaluation

- [ ] Evaluation dataset created with absolute dates
- [ ] Ground truth includes expected values with tolerance
- [ ] Ground truth includes what response should NOT contain
- [ ] All 4 system metrics enabled (TSA, TEA, Answer Correctness, Logical Consistency)
- [ ] Baseline evaluation run completed
- [ ] Evaluations automated in CI/CD pipeline

### Iteration

- [ ] Semantic view definition stored in Git
- [ ] Evaluations trigger on PR/config change
- [ ] VQR suggestions reviewed regularly
- [ ] Filter/metric suggestions reviewed regularly
- [ ] Changes validated incrementally

---

## Sources

### Official Documentation

| Topic | Link |
|-------|------|
| Semantic view best practices (dev pipeline) | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev) |
| Build agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/build-agents) |
| Cortex Agent evaluations | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations) |
| Verified Query Repository | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository) |
| Custom instructions | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/custom-instructions) |
| Suggestions for semantic models | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-suggestions) |
| Overview of semantic views | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/views-semantic/overview) |
| Create and manage agents | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage) |

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
