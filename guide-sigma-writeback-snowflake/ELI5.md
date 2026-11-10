# Sigma Writeback, Explained Simply

> Simplified from: [README.md](README.md), "Make Sense of What Sigma Writes Back to Snowflake"

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-10 | **Expires:** 2027-01-09

## One-Sentence Version

When people type into a Sigma table, Sigma saves it to Snowflake in its own private format, so you read it through a clean "window" Sigma makes and your own labeled copy of that window.

## The Story

Think of a shared recipe binder in a restaurant kitchen. Cooks write changes on sticky notes in a private shorthand, and every change gets a new note. Nobody throws old notes away. That keeps a full history, but a customer could never read it.

Sigma input tables work like that binder. Each time someone edits a cell, Sigma adds a new row in Snowflake. Column names are random codes like `SAKZ1N4J3M`. Three typed rows became twelve stored rows in our test.

To read it, Sigma can print a clean menu called a **warehouse view**. Sigma reprints the menu within seconds of each edit. But if someone hides a dish on their screen and publishes, that dish also disappears from the menu.

So you put your own labeled sign in front of the menu. That is the **contract view**. It fixes the types, drops blank rows, and is the only thing everyone else reads.

## The Cast

- **Input table:** a spreadsheet-like table in Sigma where people type data.
- **Write schema:** the Snowflake folder where Sigma keeps its storage. Only Sigma should write there.
- **`SIGDS_` table:** the sticky-note pile. One row per edit, columns in code. Do not build on it.
- **Edit log (WAL):** Sigma's diary of every save, used for recovery.
- **Audit log view:** a readable history of who changed what, made automatically.
- **Warehouse view:** Sigma's clean, current menu of one input table.
- **Contract view:** your own view over the menu, with real types and names, in a folder you control.

## What Changed

- Before: people opened the write schema and saw unreadable tables.
- After: they read one contract view with normal names and number types.
- Before: analysts were given access to Sigma's storage.
- After: analysts only get access to the contract folder.

## What to Watch Out For

- **Filters leak.** A filter on the Sigma table removes rows from Snowflake too. Filter a copy instead.
- **Entered data hides in the view's code.** Sigma writes recent edits straight into the view definition. Anyone who can read definitions can see them.
- **Deleting in Sigma does not delete in Snowflake.** Old storage piles up until someone cleans it.
- **A dedicated setting matters.** If the Sigma user has `QUOTED_IDENTIFIERS_IGNORE_CASE` turned on, Snowflake cannot find Sigma's tables and saves fail.
- **Name things first.** An unnamed table gave a view called `NEW_INPUT_TABLE`.
- **The format is Sigma's, not yours.** Sigma can change it any time. Sigma Tables, a newer approach, is in public beta and not covered here.

## The One Thing to Remember

Never build on the `SIGDS_` tables: read the Sigma warehouse view, put your own contract view in front, and share only that.

> For the full technical details, see the source document.
