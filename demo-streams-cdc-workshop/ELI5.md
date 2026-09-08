# Snowflake Streams CDC Workshop, Explained Simply

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

A Snowflake Stream is a bookmark that tells a careful helper which order rows changed since the helper last finished its work.

## The Story

Imagine a shop keeps its current orders on a whiteboard. Another whiteboard must always match it, and a notebook must record what changed.

The Stream is not another whiteboard full of copied orders. It is a bookmark that lets Snowflake calculate the difference between the last completed checkpoint and now.

## The Cast

- `RAW_ORDERS` is the shop's operational whiteboard.
- `RAW_ORDERS_STREAM` is the bookmark.
- `SP_CONSUME_ORDER_CHANGES` is the careful helper.
- `CURRENT_ORDERS` is the matching whiteboard.
- `ORDER_CHANGE_AUDIT` is the notebook.
- `TASK_CONSUME_ORDER_CHANGES` is an optional bell that calls the helper when something changes.

## What Changed

The workshop adds one order, updates one order, and deletes one order. The update looks like two Stream rows: remove the old version and insert the new version. A flag tells the helper that those two rows belong to an update.

Looking at the changes does not move the bookmark. The helper must successfully write the notebook and update the matching whiteboard. Only then does Snowflake move the bookmark forward.

## Why One Transaction Matters

The helper performs both writes as one promise. If the notebook write works but the whiteboard update fails, Snowflake cancels both. The bookmark stays where it was, so the helper can safely try again.

## Watch-Outs

- The Stream shows the net difference, not every tiny thing that happened between checks.
- The bookmark expires if nobody processes it before the source history is removed.
- Replacing the source table is like throwing away the book; the old bookmark no longer works.
- Two independent helpers need two bookmarks.
- The optional bell starts turned off so it cannot surprise you with compute usage.

## One Takeaway

A Stream makes incremental processing reliable when you treat its offset, transaction boundary, and retention deadline as one design problem.
