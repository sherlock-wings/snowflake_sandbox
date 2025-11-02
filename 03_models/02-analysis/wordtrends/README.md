# Word Trends Analysis

This module implements **Approach 2: N-gram Phrase Detection** for identifying newly trending words and phrases with associated sentiment from social media posts.

## Overview

The analysis extracts n-grams (1-grams, 2-grams, 3-grams) from post text, tracks their usage month-over-month, and identifies newly emerging or rapidly growing trends along with sentiment analysis.

## Architecture

The solution is built as a series of SQL views that build upon each other:

1. **`01_extract_ngrams.sql`** - `VW_POST_NGRAMS`
   - Extracts and normalizes text from posts
   - Generates 1-grams (words), 2-grams (phrases), and 3-grams (three-word phrases)
   - Cleans text (removes URLs, normalizes case, handles punctuation)
   - **Stop word filtering**: Filters common stop words from 1-grams only (keeps them in phrases for context)

2. **`02_monthly_ngram_counts.sql`** - `VW_MONTHLY_NGRAM_SENTIMENT`
   - Joins n-grams with sentiment data
   - Calculates monthly occurrence counts
   - Provides sentiment distribution (Positive/Negative/Neutral percentages)

3. **`03_calculate_trends.sql`** - `VW_NGRAM_TRENDS`
   - Compares consecutive months
   - Calculates growth rates, absolute changes
   - Identifies newly emerging n-grams
   - Classifies trends (NEW, RAPID_GROWTH, STRONG_GROWTH, etc.)

4. **`04_trending_words_with_sentiment.sql`** - `VW_TRENDING_WORDS_WITH_SENTIMENT`
   - **Main output view** - combines trend metrics with sentiment breakdown
   - Provides actionable insights on trending terms
   - Includes confidence scores and dominant sentiment

## Data Requirements

- **Source Tables:**
  - `BLUESKY_DB.MAIN.FIREHOSE_PROCESSED` - Post text and metadata
  - `BLUESKY_DB.MAIN.FIREHOSE_NLP_LABELED` - Sentiment labels and confidence scores

- **Join Key:** `CONTENT_ID`

- **Temporal Requirement:** Trends can only be calculated starting from the second month of data (first month-over-month comparison requires at least two months).

## Installation

Run the SQL files in order:

```sql
-- 1. Extract n-grams
@01_extract_ngrams.sql;

-- 2. Calculate monthly counts with sentiment
@02_monthly_ngram_counts.sql;

-- 3. Calculate month-over-month trends
@03_calculate_trends.sql;

-- 4. Create final trending words view
@04_trending_words_with_sentiment.sql;
```

All views are created in the `BLUESKY_DB.PFC` schema.

## Usage Examples

### Find newly trending words in the latest month

```sql
SELECT 
  CURRENT_MONTH,
  NGRAM,
  NGRAM_SIZE,
  CURRENT_COUNT,
  GROWTH_RATE_PERCENT,
  PCT_POSITIVE,
  PCT_NEGATIVE,
  PCT_NEUTRAL,
  DOMINANT_SENTIMENT
FROM BLUESKY_DB.PFC.VW_TRENDING_WORDS_WITH_SENTIMENT
WHERE CURRENT_MONTH = (
  SELECT MAX(CURRENT_MONTH) 
  FROM BLUESKY_DB.PFC.VW_TRENDING_WORDS_WITH_SENTIMENT
)
  AND TREND_CATEGORY IN ('NEW', 'RAPID_GROWTH')
ORDER BY CURRENT_COUNT DESC
LIMIT 100;
```

### Find trending phrases (2-grams and 3-grams) with negative sentiment

```sql
SELECT 
  CURRENT_MONTH,
  NGRAM,
  NGRAM_SIZE,
  CURRENT_COUNT,
  PCT_NEGATIVE,
  DOMINANT_SENTIMENT
FROM BLUESKY_DB.PFC.VW_TRENDING_WORDS_WITH_SENTIMENT
WHERE NGRAM_SIZE >= 2
  AND PCT_NEGATIVE > 50
  AND TREND_CATEGORY IN ('NEW', 'RAPID_GROWTH', 'STRONG_GROWTH')
ORDER BY CURRENT_MONTH DESC, PCT_NEGATIVE DESC;
```

### Track a specific term over time

```sql
SELECT 
  CURRENT_MONTH,
  CURRENT_COUNT,
  PREVIOUS_COUNT,
  GROWTH_RATE_PERCENT,
  PCT_POSITIVE,
  PCT_NEGATIVE,
  DOMINANT_SENTIMENT
FROM BLUESKY_DB.PFC.VW_TRENDING_WORDS_WITH_SENTIMENT
WHERE NGRAM ILIKE '%your_term%'
ORDER BY CURRENT_MONTH DESC;
```

## Configuration Parameters

Key thresholds can be adjusted in the views:

### In `04_trending_words_with_sentiment.sql`:
- `CURRENT_COUNT >= 5` - Minimum occurrences to be considered a trend (adjust for noise reduction)
- `TREND_CATEGORY IN (...)` - Which trend categories to include

### In `03_calculate_trends.sql`:
- Growth rate thresholds for trend classification:
  - `RAPID_GROWTH`: >= 100% growth
  - `STRONG_GROWTH`: >= 50% growth
  - `MODERATE_GROWTH`: >= 20% growth

### In `01_extract_ngrams.sql`:
- Minimum word length: `LENGTH(TRIM(w.VALUE)) >= 2`
- Text cleaning rules (URL removal, punctuation handling)
- **Stop word filtering**:
  - **1-grams**: Filters ~80 common English stop words (the, and, to, a, of, in, is, it, you, that, was, etc.)
  - **2-grams & 3-grams**: Keeps all phrases (stop words provide context, e.g., "not good", "is not")
  - Excludes pure stop-word combinations like "the the", "and and", "the the the"
  
  **Why this approach?**
  - Single stop words dominate frequency but aren't meaningful trends
  - Stop words in phrases carry semantic meaning ("not good" vs "good")
  - Social media context benefits from keeping phrases intact

## Performance Considerations

- The n-gram extraction view processes all posts and can be computationally expensive
- Consider materializing intermediate views for large datasets:
  ```sql
  CREATE OR REPLACE TABLE BLUESKY_DB.PFC.TBL_POST_NGRAMS AS
  SELECT * FROM BLUESKY_DB.PFC.VW_POST_NGRAMS;
  ```
- Indexing on `POST_MONTH` and `NGRAM` can improve query performance
- Filter early by date range in queries to reduce processing volume

## Future Enhancements

This implementation covers **Approach 2** (n-grams). Planned enhancements include:

- **Approach 5 elements**: Rolling baseline comparison (3-month average instead of single previous month)
- **Approach 3 elements**: Statistical significance testing (z-scores, p-values) to filter noise
- Language-specific processing for multi-language posts
- Customizable n-gram size parameters
- Optional stop word list from external table (currently uses inline VALUES list)

## Output Schema

### `VW_TRENDING_WORDS_WITH_SENTIMENT`

| Column | Type | Description |
|--------|------|-------------|
| CURRENT_MONTH | DATE | Month of the trend |
| NGRAM | VARCHAR | The word or phrase |
| NGRAM_SIZE | NUMBER | 1, 2, or 3 (word, phrase, three-word phrase) |
| CURRENT_COUNT | NUMBER | Occurrences in current month |
| ABSOLUTE_CHANGE | NUMBER | Change from previous month |
| GROWTH_RATE_PERCENT | NUMBER | Percentage growth (999999 for new emergence) |
| IS_NEW_EMERGENCE | BOOLEAN | True if didn't exist in previous month |
| TREND_CATEGORY | VARCHAR | NEW, RAPID_GROWTH, STRONG_GROWTH, MODERATE_GROWTH, etc. |
| PCT_POSITIVE | NUMBER | Percentage of occurrences with positive sentiment |
| PCT_NEGATIVE | NUMBER | Percentage with negative sentiment |
| PCT_NEUTRAL | NUMBER | Percentage with neutral sentiment |
| AVG_CONF_POSITIVE | NUMBER | Average confidence for positive sentiment |
| AVG_CONF_NEGATIVE | NUMBER | Average confidence for negative sentiment |
| AVG_CONF_NEUTRAL | NUMBER | Average confidence for neutral sentiment |
| AVG_CONFIDENCE_OVERALL | NUMBER | Overall average sentiment confidence |
| DOMINANT_SENTIMENT | VARCHAR | Sentiment with highest percentage |

