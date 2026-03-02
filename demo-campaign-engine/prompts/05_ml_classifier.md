# Prompt: ML Campaign Classifier

## The Prompt

"Train a SNOWFLAKE.ML.CLASSIFICATION model on historical campaign responses joined to player features. Create a procedure that scores all players for a given campaign type and returns the top candidates ranked by predicted response probability."

## What Was Generated

- Training view joining campaign responses to player features
- SNOWFLAKE.ML.CLASSIFICATION model creation
- SCORE_CAMPAIGN_AUDIENCE stored procedure for on-demand scoring

## Key Decisions Made by AI

- Training data: inner join of RAW_CAMPAIGN_RESPONSES + DT_PLAYER_FEATURES + RAW_CAMPAIGNS
- Target column: responded (BOOLEAN) for binary classification
- Features: all 16 behavioral metrics plus campaign_type
- Prediction output: probability of response per player
- Procedure returns top 50 candidates sorted by predicted probability
