/*
  Calculate monthly counts for each n-gram, aggregated by sentiment
  
  This view joins n-grams with sentiment data and provides monthly statistics
  including:
  - Total occurrences of each n-gram per month
  - Count by sentiment (Positive, Negative, Neutral)
  - Percentage distribution of sentiment
  - Average confidence scores
  
  Note: This view can be materialized for performance if needed.
*/

CREATE OR REPLACE VIEW BLUESKY_DB.PFC.VW_MONTHLY_NGRAM_SENTIMENT AS
WITH ngram_sentiment_base AS (
  SELECT 
    n.CONTENT_ID,
    n.POST_MONTH,
    n.NGRAM,
    n.NGRAM_SIZE,
    COALESCE(s.SENTIMENT_DETECTED_LABEL, 'Unknown') AS SENTIMENT_LABEL,
    COALESCE(s.SENTIMENT_CONFIDENCE_SCORE, 0) AS SENTIMENT_CONFIDENCE
  FROM BLUESKY_DB.PFC.VW_POST_NGRAMS n
  LEFT JOIN BLUESKY_DB.MAIN.FIREHOSE_NLP_LABELED s
    ON n.CONTENT_ID = s.CONTENT_ID
),
monthly_aggregates AS (
  SELECT 
    POST_MONTH,
    NGRAM,
    NGRAM_SIZE,
    SENTIMENT_LABEL,
    COUNT(*) AS OCCURRENCE_COUNT,
    COUNT(DISTINCT CONTENT_ID) AS POST_COUNT,
    AVG(SENTIMENT_CONFIDENCE) AS AVG_CONFIDENCE,
    MIN(SENTIMENT_CONFIDENCE) AS MIN_CONFIDENCE,
    MAX(SENTIMENT_CONFIDENCE) AS MAX_CONFIDENCE
  FROM ngram_sentiment_base
  GROUP BY 
    POST_MONTH,
    NGRAM,
    NGRAM_SIZE,
    SENTIMENT_LABEL
),
sentiment_totals AS (
  SELECT 
    POST_MONTH,
    NGRAM,
    NGRAM_SIZE,
    SUM(OCCURRENCE_COUNT) AS TOTAL_OCCURRENCES,
    SUM(POST_COUNT) AS TOTAL_POSTS
  FROM monthly_aggregates
  GROUP BY 
    POST_MONTH,
    NGRAM,
    NGRAM_SIZE
)
SELECT 
  m.POST_MONTH,
  m.NGRAM,
  m.NGRAM_SIZE,
  m.SENTIMENT_LABEL,
  m.OCCURRENCE_COUNT,
  m.POST_COUNT,
  m.AVG_CONFIDENCE,
  m.MIN_CONFIDENCE,
  m.MAX_CONFIDENCE,
  t.TOTAL_OCCURRENCES,
  t.TOTAL_POSTS,
  -- Calculate sentiment percentage
  ROUND(
    (m.OCCURRENCE_COUNT * 100.0 / NULLIF(t.TOTAL_OCCURRENCES, 0)),
    2
  ) AS SENTIMENT_PERCENTAGE
FROM monthly_aggregates m
INNER JOIN sentiment_totals t
  ON m.POST_MONTH = t.POST_MONTH
  AND m.NGRAM = t.NGRAM
  AND m.NGRAM_SIZE = t.NGRAM_SIZE
ORDER BY 
  m.POST_MONTH,
  t.TOTAL_OCCURRENCES DESC,
  m.SENTIMENT_LABEL;

