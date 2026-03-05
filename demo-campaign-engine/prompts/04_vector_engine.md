# Step 4: Vector Similarity Engine

## AI-Pair Technique: Decompose Into Steps

Complex operations are best described as a pipeline: input -> transform -> compare -> output. The prompt below breaks the problem into four explicit steps (seed players -> average vector -> cosine similarity -> ranked results). This gives the AI a clear algorithm to implement rather than leaving it to invent one.

## Before You Start

- [ ] Step 3 complete: `DT_PLAYER_VECTORS` has ~500 rows with a VECTOR(FLOAT,16) column
- [ ] Dynamic Tables are in ACTIVE scheduling state (`SHOW DYNAMIC TABLES LIKE 'DT_%'`)

## The Prompt

Paste this into your AI tool:

> "Create a stored procedure FIND_SIMILAR_PLAYERS that takes an array of up to 10 player IDs, computes their average behavior vector, and returns the 10 most similar players not in the input set using VECTOR_COSINE_SIMILARITY."

## Validate Your Work

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Test with 3 seed players
CALL FIND_SIMILAR_PLAYERS(PARSE_JSON('[1, 5, 12]'));

-- Verify results: should return 10 rows, all with similarity > 0
-- None of the returned player_ids should be 1, 5, or 12
```

Expected: 10 rows with player details and similarity_score between 0 and 1. Seed players excluded from results.

## Common Mistake

**The language mistake:** "Create a SQL stored procedure for vector similarity."

What goes wrong: The AI writes a SQL stored procedure (LANGUAGE SQL) because you said "SQL." It compiles successfully. But when you CALL it, you get a runtime type error because **VECTOR type is not supported in Snowflake SQL scripting**. The error message is opaque -- something about incompatible types -- and you'll spend 20 minutes debugging before you realize the language choice is the problem.

This is the most confusing failure in the entire build because:
1. The procedure compiles (syntax is valid)
2. The error only appears at runtime (when VECTOR operations execute)
3. The error message doesn't say "VECTOR not supported in SQL scripting"

The fix: The prompt in this guide doesn't specify a language, which lets the AI choose. But if your AI defaults to SQL, follow up with: "Use Python (LANGUAGE PYTHON with snowflake-snowpark-python) because VECTOR type is not supported in Snowflake SQL scripting."

The reference implementation uses Python with Snowpark, constructs the SQL query as a string, and returns results via `session.sql()`.

## What Just Happened

The AI chose Python for a reason:

- **VECTOR type limitation** -- Snowflake SQL scripting can't manipulate VECTOR columns. Python stored procedures use Snowpark to execute SQL that references VECTOR columns without trying to bind them into script variables.
- **Average vector via SQL** -- The AI computes the average vector in SQL (element-wise AVG of the 16 array positions), not in Python. This is faster because Snowflake pushes the computation down.
- **CROSS JOIN seed_avg** -- The averaged seed vector is computed once and joined to all candidate players. The cosine similarity then scores every non-seed player in one pass.
- **Seed exclusion** -- `WHERE player_id NOT IN (...)` ensures you don't recommend a player to themselves.

Key pattern to notice: The Python stored procedure is a thin wrapper around SQL. The Python code does almost nothing except construct and execute the query. This is the right pattern for Snowpark procedures that need to work with types SQL scripting doesn't support.

## If Something Went Wrong

**"Unsupported type: VECTOR" or similar type error?** The procedure was created with LANGUAGE SQL. Drop it and recreate with LANGUAGE PYTHON. See the Common Mistake section above.

**All similarity scores are 1.0?** Your seed set and results overlap too much, or vectors aren't properly normalized. Check that `DT_PLAYER_VECTORS` has varied values: `SELECT * FROM DT_PLAYER_VECTORS LIMIT 5;` -- if all vectors look identical, go back to Step 3 and verify the normalization math.

**Procedure returns 0 rows?** The seed player IDs may not exist. Verify with: `SELECT player_id FROM DT_PLAYER_VECTORS WHERE player_id IN (1, 5, 12);`

## What Was Generated

- Python stored procedure using Snowpark
- Averages seed player vectors via SQL aggregation
- Ranks all other players by cosine similarity
- Returns top 10 with similarity scores and player details

## Reference Implementation

Compare your AI's output to [sql/04_engine/01_lookalike_procedure.sql](../sql/04_engine/01_lookalike_procedure.sql).
