> Simplified from: guide-cube-snowflake-semantic-layer/README.md

# Cube on Snowflake — Plain Language Version

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Cube is a translator that sits above Snowflake, turning one set of business
definitions into answers for many different tools — useful if you have many kinds of
tools, and unnecessary overhead if you don't.

---

## The Story

Picture a restaurant kitchen. Snowflake is the kitchen: it holds all the ingredients
and does all the cooking. That part never changes in this story.

The problem is the dining rooms. You have four of them, and each one speaks a
different language. If every dining room writes its own menu, "house salad" ends up
meaning four different things. Guests compare notes and get confused. Somebody
complains that the numbers don't match.

Cube is a head waiter who writes **one** menu and translates every order into kitchen
language. The kitchen still cooks everything. But now "house salad" means exactly one
thing, no matter which dining room ordered it. Cube also keeps a warming tray of the
most popular dishes, so the kitchen isn't asked to re-cook the same salad two hundred
times an hour.

Here's the twist. The kitchen recently started writing its own menu too. So now there
are two menus that need to agree with each other. Cube can copy dishes in both
directions — but the kitchen's menu format is simpler, and some of the fancier dishes
can't be written down on it at all.

---

## The Cast

**Snowflake** — The kitchen. Stores your data and does the actual computing work. Cube
never takes your data out of it.

**Cube** — The head waiter. Holds the single official list of what each business term
means, and translates requests into instructions Snowflake understands.

**Cube Store** — The warming tray. Keeps pre-calculated answers to common questions so
the kitchen doesn't get asked the same thing repeatedly. This is where cost savings
come from.

**Pre-aggregations** — The pre-made dishes sitting on the warming tray. Someone has to
decide how often to make fresh batches.

**Semantic views** — The kitchen's own menu. A newer Snowflake feature that does a
simpler version of what Cube does, but only for Snowflake's own tools.

**Service user** — A staff ID badge issued to a robot instead of a person. It lets Cube
into the kitchen without a human being involved.

**Query tag** — A label Cube staples to every order it sends the kitchen, so you can
later count how many orders came from Cube.

---

## What Changed

- **Before:** Each reporting tool defined "revenue" its own way. Numbers disagreed.
- **After:** One definition lives in Cube. Every tool gets the same answer.

- **Before:** Every dashboard refresh made Snowflake do the work again.
- **After:** Common answers come off the warming tray instead.

- **Before:** Connecting Cube meant storing a password or key somewhere forever.
- **After:** Cube can use a day-pass that expires on its own. Nothing long-lived to
  store or rotate.

- **Before:** Snowflake had no menu of its own. Cube was the only option.
- **After:** Snowflake has semantic views. For some teams, that's enough on its own.

---

## What to Watch Out For

**The badge type matters a lot.** There are three ways to let Cube in: a password, a
key, or a self-expiring day-pass. The password option is the default, and it's the
worst one. Snowflake is phasing out password-only access for robot accounts. Pick the
key if you host Cube yourself, or the day-pass if you use Cube's cloud service.

**One setting causes most of the failures.** The day-pass has to say which job title
Cube is allowed to use. If that line is missing, Cube gets through the door and then
gets stopped in the hallway. The error message is confusing and doesn't point at the
real cause. Check that line first when something breaks.

**Security rules do not copy over.** This is the important one. If you use Cube to
restrict who sees which rows, and then copy your definitions into Snowflake's menu,
**the restrictions do not come along.** The copy looks successful. The protection is
gone. You have to set up equivalent rules directly on the Snowflake tables, where they
will carry through properly.

**Cube can silently raise your bill.** The warming tray only saves money if you refill
it at a sensible pace. A misconfigured setup rebuilds the same dishes far too often,
and nobody notices because it looks like normal activity. Label Cube's orders with a
tag from day one, or you will not be able to tell its costs apart from everything else
later.

**Snowflake's own documentation is wrong on one point.** One Snowflake help page says
you can't restrict which internet addresses Cube connects from. You can — this was
tested and confirmed working. A different Snowflake page says so correctly. Trust the
one that says it works.

**Some things simply can't be copied to Snowflake's menu.** Anything involving
complicated joins, multi-part record keys, running-total style calculations, or
anything beyond basic sums and counts. These keep working fine inside Cube. They just
can't move. Cube warns you during the copy, so you won't be surprised — but plan for it.

---

## Should You Even Do This?

Be honest with yourself here, because Cube is real software that someone has to run,
secure, and pay for.

**Cube earns its place if:**
- Your people use Excel, Power BI, or custom apps — not just Snowflake's own tools
- You have more than one data warehouse to unify
- You're building something with lots of simultaneous users, like a customer-facing
  dashboard
- Your metrics are genuinely complicated

**Skip it if:**
- Snowflake is your only warehouse, and
- Your users are business intelligence tools plus Snowflake's built-in AI

For that second group, Snowflake's own menu already does the job. Adding Cube means
more moving parts for no new capability.

---

## The One Thing to Remember

Cube's value is serving one set of definitions to many different kinds of tools — so if
all your tools already speak Snowflake, you probably don't need it.

---

> For the full technical details, see the source document.
