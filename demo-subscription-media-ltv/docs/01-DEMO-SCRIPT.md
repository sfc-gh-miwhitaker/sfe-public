# Demo Script: Governed Member Value in CoWork

Pair-programmed by SE Community + Cortex Code

A 15-minute live demo. The story: the same warehouse data, asked the same
question, gives a confident but off-definition answer without business context,
and a finance-grade answer with it. Every number below comes from the
deterministic synthetic data, so a fresh deploy reproduces them exactly.

## Before the call

1. Run `deploy_all.sql` (about 5 minutes).
2. Open Snowflake CoWork with the **SYSADMIN** role.
3. Open two tabs: **Member Value Analyst** and **Raw Data Assistant (no business context)**.

## Act 1: Same question, two answers (4 minutes)

Ask both agents:

> What is our 24-month net LTV and LTV to CAC by acquisition source?

| What to point at | Raw Data Assistant | Member Value Analyst |
| --- | --- | --- |
| Definition of "net" | Amount charged; says platform fees are not deducted | Charged minus platform fees |
| LTV to CAC basis | Revenue divided by CAC | Contribution (net minus delivery) divided by CAC |
| Podcast host reads LTV to CAC | About 4.2x | 3.66x |
| Organic and Referral | No CAC, so no ratio | 16.22x and 6.82x |
| States the cohort rule | Chooses its own | Mature cohort, 10,055 members |

The raw answer is careful and plausible. It is still not the number finance
uses, and two people asking it on different days can get different definitions.
The governed answer is the same every time because the definition lives in the
semantic view, not in the prompt.

## Act 2: The questions only governed data can answer (8 minutes)

Stay in **Member Value Analyst**.

| # | Ask | Expected headline |
| --- | --- | --- |
| 1 | Which payment platform pays back CAC fastest? | Web (card) in 7.7 months; Apple slowest at 9.2. The gap is platform fees. |
| 2 | Compare reported ROAS to true ROAS for our paid channels | The ranking flips. Paid social reports 3.4x, returns 1.23x. Podcast host reads report 1.4x, return 3.66x. Ask for a chart. |
| 3 | How many members are at high churn risk and how much net revenue is at risk? | 2,003 high-risk members, $147,241 of $153,983 at risk over 90 days. |
| 4 | What drives churn? | Recent viewing minutes and viewing trend, about 68% of model importance. Commercial factors barely register. |
| 5 | Do deeper first-year discounts pay off? | 20% off wins at $2,561 per 1,000 visitors versus $2,352 at full price. 30% and deeper lose. |
| 6 | Which audience segments have the biggest targeted ad upside? | Personal finance and investing, about $525K a year; $2.0M across seven segments. |

Then ask the raw agent question 3. It declines because nothing in the raw
tables defines churn risk or net revenue. That refusal is the right behavior,
and it shows why the business context has to be built, not prompted.

## Act 3: An artifact to keep (3 minutes)

> Build me a one-page summary of member value for our CFO

The agent combines value per member on every basis, LTV to CAC by source,
payback by platform, churn revenue at risk, and the best discount tier into one
page. Save it as a CoWork artifact and share it.

## Where the governance lives

| Layer | Object | What it holds |
| --- | --- | --- |
| Definitions | `MEMBER_VALUE` view | Gross, net, contribution, total value, mature cohort flags |
| Business context | `SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE` | Metric definitions, synonyms, SQL guidance, 8 verified queries |
| Prediction | `CHURN_MODEL` | Snowflake ML classification, scored into `CHURN_SCORES` |
| Conversation | `MEMBER_VALUE_AGENT` | Response rules: lead with the answer, always name the basis |

## Reset between rehearsals

Nothing in the demo changes data. Start a new CoWork conversation and every
answer reproduces.
