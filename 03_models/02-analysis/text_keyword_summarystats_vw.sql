create or replace view text_keywords_summarystats_vw as
WITH keyword_matches AS (
  SELECT
    f.CONTENT_ID,
    f.POST_TEXT,
    f.SENTIMENT_DETECTED_LABEL,
    f.SENTIMENT_CONFIDENCE_SCORE,
    k.keyword,
    k.category,
    k.topic,
    CASE 
      WHEN LOWER(f.POST_TEXT) LIKE CONCAT('%', LOWER(k.keyword), '%') THEN 1 
      ELSE 0 
    END AS text_match_flag,
    -- Sentiment flags
    CASE WHEN f.SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END AS positive_count,
    CASE WHEN f.SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END AS negative_count,
    CASE WHEN f.SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END AS neutral_count
  FROM steets.firehose_nlp_posts_vw f
  JOIN steets."Keywords_Lookup" k
    ON LOWER(f.POST_TEXT) LIKE CONCAT('%', LOWER(k.keyword), '%') 
)

SELECT
  keyword,
  topic,
  category,
  COUNT(*) AS unique_posts,
  SUM(positive_count) AS positive_posts,
  100.0 * SUM(positive_count) / NULLIF(COUNT(*), 0) AS pct_positive,
  SUM(negative_count) AS negative_posts,
  100.0 * SUM(negative_count) / NULLIF(COUNT(*), 0) AS pct_negative,
  SUM(neutral_count) AS neutral_posts,
  100.0 * SUM(neutral_count) / NULLIF(COUNT(*), 0) AS pct_neutral,  
  (pct_positive - pct_negative) AS net_sentiment,
  AVG(SENTIMENT_CONFIDENCE_SCORE) AS avg_sentiment_confidence
FROM keyword_matches
WHERE text_match_flag = 1
GROUP BY keyword, topic, category
ORDER BY keyword;