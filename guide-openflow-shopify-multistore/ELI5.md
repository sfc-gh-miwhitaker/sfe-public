# ELI5: Dozens of Shopify Stores into Snowflake with Openflow

> Simplified from: `guide-openflow-shopify-multistore/README.md`

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

You can use Snowflake's built-in pipeline tool, Openflow, to copy sales and shipment data
from many Shopify stores into Snowflake every day — but each store must be wired up by
hand, and the tool has a running cost even when idle.

## The Story

Imagine you own a chain of dozens of small shops. Every night you want each shop's sales
receipts and shipping slips delivered to one central office so the accountants can see
the whole business. Until now you paid a courier company to do this. The contract has
become a problem and you want a cheaper option.

Openflow is like hiring your own in-house delivery crew instead. The crew lives inside
Snowflake's building, so there is no separate vendor. You give the crew a van (a
"runtime"), a list of every shop address it is allowed to visit (a "network rule"), and
a key card for each shop (a "Shopify dev app" with a Client ID and Secret). Each night
the crew visits every shop, picks up what changed, and files it in a separate drawer per
shop.

Here is the catch. Snowflake has started letting you set up the van and the address list
with SQL commands, which means you can script it. But the Shopify pickup route itself is
still configured by clicking through a visual editor, one shop at a time. So for dozens of
shops, you fill in dozens of forms. The guide gives you a checklist so the clicking is
consistent, but it cannot make it disappear.

Once the drawers fill up, a second part of the guide stacks them into one combined view:
all orders, all shipments, and a daily summary per shop. That part is fully automated —
add a shop to the register, run one command, and the combined view includes it.

## The Cast

- **Openflow** — Snowflake's built-in data pipeline service. Under the hood it runs
  Apache NiFi, a visual flow-building tool.
- **Deployment** — the "garage" that holds one or more vans. Creating it starts a small
  always-on charge that only stops when you delete the garage.
- **Runtime** — the "van." It does the actual work. You pick its size once and cannot
  change it later. You can park it (suspend) to stop its own cost.
- **Shopify connector** — the pre-built pickup route for Shopify. It is a Preview feature,
  and it is configured by clicking on a canvas rather than by SQL.
- **Execute-as role** — the badge the van wears inside Snowflake; it decides which
  drawers the van may write to.
- **Network rule / EAI** — the list of shop addresses the van may drive to. Every store's
  web address must be on it, plus one Google Cloud address where Shopify drops off bulk
  files.
- **Store registry** — a table listing every shop. Adding a shop here creates its drawer
  and tells the combined view to include it.
- **Dynamic Tables** — Snowflake tables that rebuild themselves on a schedule. They stack
  the per-shop drawers into one cross-shop view.

## What Changed

- Before: a third-party ELT vendor moved Shopify data; you paid them per connector and
  they handled every store.
- After: Snowflake moves the data; you pay Snowflake credits, and you handle every store.
- Before: adding a store was a few clicks in the vendor's UI.
- After: adding a store is a Shopify app, a SQL call, a network-rule update, and a
  connector install on a visual canvas — roughly 20 minutes once practiced.
- Before: someone else fixed it when it broke.
- After: your team reads the runtime's error log and fixes it on the canvas; Snowflake
  runs the infrastructure underneath.

## What to Watch Out For

- **There is a base cost.** The deployment bills continuously even with nothing running,
  the same way most managed integration services charge a platform fee. Compare it to what
  you pay today.
- **Cost is reported per compute pool, not per store.** If you need per-store numbers, plan
  an allocation up front.
- **The connector is Preview.** It may change. It also cannot handle Shopify adding or
  removing a field: you must reset that object and drop its table, per store.
- **Shopify only gives you 60 days of orders by default.** Older history needs a separate
  Shopify approval (`read_all_orders`). Customer names and emails need another approval.
- **Nobody has documented how many Shopify stores fit on one runtime.** The guide's
  starting size is a guess based on a different connector type. Measure after every five
  stores.
- **You are running NiFi.** If your team chose Snowflake to avoid operating integration
  infrastructure, this is that infrastructure, just hosted inside Snowflake.
- **Do not turn off the old vendor on day one.** Run both, compare counts per store per
  day, and cut over store by store.

Two questions the guide leaves open on purpose: the name of the raw data column the
connector creates is not documented (check after the first load), and whether Shopify will
get a SQL-scriptable setup — which would remove most of the per-store clicking — has no
announced date.

## The One Thing to Remember

Openflow can replace your Shopify ELT vendor, moving ingestion inside Snowflake's billing
and security boundary — in exchange for an always-on base charge, a per-store manual setup,
and an on-call duty your team now owns. Start with one store and prove the math before you
migrate the rest.

> For the full technical details, see the source document.
