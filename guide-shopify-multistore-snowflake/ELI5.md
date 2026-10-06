# ELI5: Dozens of Shopify Stores into Snowflake

> Simplified from: `guide-shopify-multistore-snowflake/README.md`

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

You can bring nightly sales and shipping data from many Shopify shops into Snowflake two
different ways — rent Snowflake's prebuilt delivery crew, or run your own small, scripted
courier — and this guide builds both so they hand you the exact same report.

## The Story

Imagine you own a chain of dozens of small shops. Every night you want each shop's sales
receipts and shipping slips delivered to one central office so the accountants can see the
whole business. Until now you paid a courier company to do this. That contract has become
a problem and you want a cheaper option that lives inside your own building.

There are two sensible ways to do it yourself.

**Option one: Snowflake's prebuilt crew (Openflow).** The crew lives inside Snowflake's
building, so there is no separate vendor. You give them a van, a list of every shop
address they are allowed to visit, and a key card for each shop. Every night they visit
each shop, pick up what changed, and file it in a separate drawer per shop.

The catch: you can set up the van and the address list with typed commands, so that part is
scriptable. But the pickup route for each shop is still configured by clicking through a
visual form, one shop at a time. Dozens of shops means dozens of forms. Also, the van's
parking space is rented by the month whether or not the van goes anywhere — there is a
small bill that never goes to zero. And this particular crew is still in a trial period
("Preview"), which means the company may change how it works.

**Option two: your own scripted courier (the native path).** Instead of a crew, you write
down the exact pickup instructions once, and Snowflake follows them on a timer. The
instructions are short, readable, and stored with your other code. Adding a shop means
adding a line to a list, not filling in a form. Nothing is rented when the courier is
asleep, so the idle bill really is zero, and you can see exactly what each shop costs. The
trade is that the pickup instructions are now yours to maintain — so this guide pairs them
with CoCo, an assistant that reads the current rulebook, checks the instructions, runs a
test pickup, and refuses to start nightly service until every test passes.

**The important part: both options end at the same report.** One row per shop, per day, per
currency, with orders, units, sales, refunds, and shipments. The report has one agreed
definition written down in one place, and a checker query that fails loudly if either
option ever drifts away from it. That means you can start on one option and move to the
other later without a single dashboard changing.

## The Cast

- **Shopify** — where the shops actually run. It hands over data in nightly batches
  ("bulk operations") rather than one order at a time.
- **Openflow** — Snowflake's built-in pipeline service. Under the hood it runs Apache NiFi,
  a visual flow-building tool. Its Shopify crew is in a trial period.
- **The Bulk API** — Shopify's "give me everything that changed" door. You knock, wait, and
  collect a file.
- **CoCo** — the engineer and dispatcher for option two. It designs the route, checks every
  lock, runs a trial pickup, and only starts nightly service after every test passes. It
  never drives the truck itself.
- **Dynamic Tables** — Snowflake's self-updating summaries. You describe the report once
  and Snowflake keeps it current.
- **The registry** — one small list of every shop: its name, its owner, whether it is live,
  and whether its numbers have been checked. Both options read the same list.

## The Parts Everyone Forgets

- **Shopify only hands over the last 60 days by default.** Older history needs a special
  permission that Shopify has to approve. Until then, your numbers will not match the old
  courier's, and that is expected rather than broken.
- **Dates are counted in UTC.** If the old courier counted in each shop's local time, some
  days will differ by a few orders. Explainable, not wrong.
- **A day can have shipments but no new orders.** Orders placed Monday might ship
  Wednesday. If Wednesday had no new orders, Wednesday still had real shipments — and an
  earlier version of this report quietly threw those days away. Both versions now keep
  them. This is the single most valuable fix in the merge.
- **Do not turn off the old courier on day one.** Run both for at least three nights per
  shop, compare the numbers, and only cancel a shop's old service after the new one has
  survived a credential change and a rulebook update without anyone hand-repairing data.

## The Honest Summary

Neither option is "add shop, done." Both still need a Shopify app, permission approvals,
and a per-shop setup step. Option one trades clicking for someone else maintaining the
logic. Option two trades owning the logic for scripting, zero idle cost, and knowing what
each shop costs. The guide tells you which trade fits, and then builds whichever you pick.
