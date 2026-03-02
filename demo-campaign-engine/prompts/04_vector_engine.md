# Prompt: Vector Similarity Engine

## The Prompt

"Create a stored procedure FIND_SIMILAR_PLAYERS that takes an array of up to 10 player IDs, computes their average behavior vector, and returns the 10 most similar players not in the input set using VECTOR_COSINE_SIMILARITY."

## What Was Generated

- Python stored procedure using Snowpark
- Averages seed player vectors via SQL aggregation
- Ranks all other players by cosine similarity
- Returns top 10 with similarity scores and player details

## Key Decisions Made by AI

- Used Python (not SQL scripting) because VECTOR type isn't supported in Snowflake Scripting
- Computes average vector in SQL using VECTOR_AVG (not Python-side math)
- Excludes seed players from results via NOT IN filter
- Returns VARIANT table for flexible consumption by Streamlit
