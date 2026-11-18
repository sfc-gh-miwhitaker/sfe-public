# ELI5: Subscription Media LTV

> Simplified from: [README.md](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Asking an AI about your business only gives trustworthy answers when the business rules live next to the data, so this demo shows the same question answered with and without those rules.

## The Story

Picture a store where two clerks answer "how much is a customer worth?" One clerk reads only the cash register tape. The other also has the accountant's rulebook: subtract card fees, count only customers who have been around long enough, and so on.

Both clerks sound confident. Only the second gives the number the accountant would sign. The first is not lying. It is guessing at rules nobody wrote down.

This demo builds both clerks for a made-up subscription publisher. The data is identical and fake. The difference is a "semantic view," a layer in Snowflake that holds the rulebook.

With the rulebook in place, the assistant can answer harder questions too. It can show which ad channels really pay back, who is likely to cancel, and whether discounts help.

## The Cast

- **Snowflake CoWork:** the chat window where business people ask questions in plain English.
- **Agent:** the assistant behind that chat window. This demo has two: one with the rulebook, one without.
- **Semantic view:** the rulebook. It says what "net revenue" or "payback" means, once, for everyone.
- **Verified queries:** worked answers to common questions that a person checked, so the assistant reuses them.
- **Mature cohort:** members who joined at least 24 months ago. Newer members haven't had time to pay yet.
- **LTV (lifetime value):** what a member is worth. Here it means 24 months of charges minus app store fees.
- **CAC (customer acquisition cost):** what it cost in marketing to win that member.
- **ROAS (return on ad spend):** money returned per dollar of advertising. Ad platforms report their own version.
- **Churn model:** a Snowflake machine learning model that predicts who will cancel in the next 90 days.

## What Changed

- Before: the AI chooses its own definition of "net," so answers drift from what finance uses.
- After: the definition is stored once, and every answer uses it and says so.
- Before: questions about churn risk get a polite "I can't define that."
- After: the assistant reads the churn model's scores and reports revenue at risk.
- Before: each ad platform's self-reported return looks like the truth.
- After: the governed view shows the real 24-month return, and the channel ranking flips.

## What to Watch Out For

- All numbers are synthetic. They show the method, not any real company's results.
- Prices, fees, ad rates, and conversion rates are made-up assumptions.
- The churn drivers show what predicts cancelling, not what causes it.
- The assistant without the rulebook is careful, not broken. Its answers are plausible, which is the risk.

## The One Thing to Remember

An AI is only as reliable as the business definitions you give it, so write them down once, in Snowflake.

> For the full technical details, see the source document.
