# ELI5: Automatically Find, Tag, and Mask PII

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-05 | **Last verified:** 2026-11-05 | **Expires:** 2027-01-04

Plain-language companion to the [main guide](README.md).

## The problem

Your company keeps lots of tables. Some of them hold people's names, emails, phone numbers, and home addresses. You are supposed to know where all of it is and make sure only the right people can see it. Nobody wants to open every table and read every column by hand.

## What Snowflake does for you

Think of a library with a careful librarian.

1. **The librarian reads a few pages of every book.** Snowflake looks at a sample of rows in each table, up to 10,000, and decides what each column holds: names, emails, phone numbers, and so on.
2. **The librarian puts a colored sticker on the spine.** Snowflake attaches labels, called tags, to each sensitive column. One label says *what* it is (EMAIL). One says *how identifying* it is (IDENTIFIER). A third is your company's own label, such as CONFIDENTIAL.
3. **The sticker decides who can read the book.** You tell Snowflake once: "anything with a CONFIDENTIAL sticker shows `***MASKED***` unless you're on the governance team." From then on, every column that gets the sticker is hidden automatically.
4. **New books get read too.** You give the librarian a rule book, called a classification profile, and point it at a shelf, which is a database or schema. Every new or changed table on that shelf is read and labeled on a schedule, without you asking.

## The pieces, in one sentence each

- **Classification profile:** the rule book, saying whether to put stickers on automatically, which of your labels to add, and what to skip.
- **Tag map:** "when you find a NAME, also add our HIGHLY_CONFIDENTIAL sticker."
- **Custom classifier:** teaches the librarian a pattern it does not know yet, like your employee ID format `EMP-123456`.
- **Masking policy on a tag:** the instruction that hides whatever wears the sticker.
- **Trust Center:** the screen in Snowsight where you see all of this without writing SQL.

## What it costs

Snowflake bills the reading under its own line item, Sensitive Data Classification. Reading views costs more than reading tables, so views are skipped unless you ask for them.

## Things people get wrong

- Finding and labeling does not hide anything by itself. Hiding happens only because you attached a masking policy to your label.
- The compliance charts are a head start, not a legal opinion.
- If someone already put your label on a column by hand, Snowflake leaves it alone and reports a conflict instead of overwriting it.

## Try it

Paste [`sql/walkthrough.sql`](sql/walkthrough.sql) into a Snowsight worksheet and select **Run All**. In about two minutes you will see the labels Snowflake put on a made-up customer table, then the same table with the sensitive columns hidden.
