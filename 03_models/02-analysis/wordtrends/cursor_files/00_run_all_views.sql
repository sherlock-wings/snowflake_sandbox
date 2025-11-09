/*
  Run all views in order to set up the word trends analysis
  Using Post-Level Aggregation approach for efficiency
  
  This approach reduces data explosion by ~70-80% by aggregating n-grams
  at the post level before monthly aggregation.
  
  Execute each SQL file in order as views depend on each other.
*/

-- Step 1: Extract n-grams with post-level aggregation (reduces data explosion)
-- Creates: VW_POST_NGRAMS_EFFICIENT
-- Run: 01_extract_ngrams.sql

-- Step 2: Calculate monthly counts with sentiment
-- Creates: VW_MONTHLY_NGRAM_SENTIMENT
-- Depends on: VW_POST_NGRAMS_EFFICIENT
-- Run: 02_monthly_ngram_counts.sql

-- Step 3: Calculate month-over-month trends
-- Creates: VW_NGRAM_TRENDS
-- Depends on: VW_MONTHLY_NGRAM_SENTIMENT
-- Run: 03_calculate_trends.sql

-- Step 4: Create final trending words view with sentiment
-- Creates: VW_TRENDING_WORDS_WITH_SENTIMENT
-- Depends on: VW_NGRAM_TRENDS, VW_MONTHLY_NGRAM_SENTIMENT
-- Run: 04_trending_words_with_sentiment.sql

