# OpenTelemetry into Snowflake, Explained Simply

> Simplified from: [README.md](README.md) and the four pattern guides in this directory.

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Your applications constantly report on their own health, and this guide shows four ways to store
those reports in Snowflake so you can ask questions about them alongside your business data.

## The Story

Imagine every employee in a large company fills out a short note whenever they finish a task:
what they did, how long it took, whether anything went wrong. That is what "instrumented"
software does. The notes are called telemetry, and there are three kinds: **logs** (short written
messages), **metrics** (numbers, like a temperature reading), and **traces** (a record of one
customer request as it moves between teams).

Most companies send those notes to a specialist filing company — a monitoring vendor. That works
well and comes with nice dashboards. But the specialist keeps the notes in its own building. So
when you want to ask "which of our paying customers hit errors last Tuesday," you cannot, because
the notes live in one building and the customer list lives in another.

This guide moves the notes into your own building — Snowflake — where the customer list already
is. Then you can ask questions that span both.

The complication is the format. Each note arrives inside three nested envelopes: an outer envelope
for "which service sent this," a middle one for "which part of the code," and an inner one holding
the actual note. Snowflake stores the whole bundle happily, but you cannot read a note until you
open the envelopes. Opening them is most of the work, and this guide provides tested instructions
for doing it.

## The Cast

- **OpenTelemetry (OTel)** — An agreed-upon standard for what those notes look like, so any tool
  can read notes written by any other tool.
- **OTLP** — The specific envelope format the notes travel in.
- **Collector** — A mailroom that sits between your applications and wherever the notes are going.
  It bundles notes together, and it can throw away ones you do not want. Every method in this
  guide assumes you run one.
- **Span** — One note about one step of one request. Many spans sharing an ID make up a **trace**,
  which is the story of a whole request.
- **Event table** — A special Snowflake table with the right shape for these notes, which
  Snowflake fills in with notes about *itself*. You cannot put your own notes in it. You can copy
  its shape, which is what this guide recommends.
- **Shredding** — Opening the envelopes so the notes become readable rows.
- **Dynamic Table** — A Snowflake table that keeps itself up to date. Used here so the envelope
  opening happens once, not every time somebody runs a query.

## The Four Ways In

All four end up in the same place, so this is a reversible choice.

1. **Openflow ListenOTLP** — Snowflake runs a mailbox that speaks the note format directly. No
   custom code. There is a catch, described below.
2. **Kafka** — If you already run a message queue, add three channels for notes. Least new work
   if you have it; do not build one just for this.
3. **Snowpipe Streaming** — Fastest and highest volume. Requires you to write a small program
   yourself, because nobody has published one.
4. **Files** — The mailroom writes notes to files, Snowflake reads the files on a schedule. Slowest
   (minutes to hours) and by far the cheapest. **Start here** if you are new to this, because it
   proves the useful half of the work without much commitment.

## What Changed

- **Before:** Telemetry lived with a monitoring vendor and could not be combined with business
  data.
- **After:** Telemetry lives in Snowflake next to everything else, so you can join it to
  customers, contracts, and revenue.
- **Before:** Long-term storage of telemetry cost monitoring-vendor prices.
- **After:** It costs storage prices, which are much lower.
- **Before:** No standard way to open the envelopes; everyone wrote their own and got it subtly
  wrong.
- **After:** Tested instructions exist, including for the parts that fail silently.

## What to Watch Out For

**The Openflow method has an unresolved question.** It listens on a network door, and Snowflake's
documentation does not confirm that door can be reached from outside. Ask your Snowflake account
team before you build on it. If the answer is no, use the Kafka or Snowpipe Streaming method
instead — those work the other way around, with your mailroom dialing out, which avoids the problem
entirely.

**Several mistakes here fail quietly, which is worse than failing loudly.** These are the ones that
produce plausible-looking wrong answers:

- **Big numbers arrive as text on purpose.** Timestamps in these notes are 19 digits long. If you
  convert them the obvious way, nothing errors — the number just gets rounded, and your timings
  are wrong by a bit. Always convert via text first.
- **One kind of metric gets dropped silently.** Metrics that describe a spread of values rather
  than a single number are stored differently. A simple reader skips them without complaining, and
  what you lose is exactly the data you need to answer "how slow is this for the slowest 1% of
  users."
- **Counting requests wrong is easy.** One customer request produces many notes — one per internal
  step. Count all of them and your traffic numbers are inflated several times over. Count only the
  outermost note per request.
- **Empty is not the same as missing.** Notes that are not tied to a request carry an empty label
  rather than a blank one. Treat empty as a real value and a routine join explodes into millions of
  meaningless rows.

**Cost is driven by variety, not volume.** Attaching something unique to each note — a user ID, a
full web address — multiplies your storage cost. Throw those away in the mailroom, where it is
free. Removing them from Snowflake later means rebuilding.

**Two things that look right and point the wrong way.** Searching for "OpenTelemetry Snowflake"
turns up a tool that pulls data *out* of Snowflake — the opposite of what this guide does. And a
tool for putting data *in* was proposed years ago but never finished. That absence is why method 3
asks you to write a small program.

**Decide how long to keep things, deliberately.** Telemetry grows forever and most of it stops
being useful within weeks. Keep the raw envelopes for days, the opened notes for weeks, and the
summarized numbers for years — summaries are tiny, so keeping those a long time costs almost
nothing.

## The One Thing to Remember

The hard part is not getting the data into Snowflake — there are four working ways to do that. The
hard part is opening the envelopes correctly, because the ways of getting it wrong produce
believable numbers instead of error messages.

> For the full technical details, see the source document.
