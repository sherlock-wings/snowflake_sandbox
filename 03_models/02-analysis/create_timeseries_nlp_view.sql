

create or replace view BLUESKY_DB.STEETS.TIMESERIES_NLP(
	KEYWORD,
	TOPIC,
	CATEGORY,
	HOUR_POST_CREATED_AT,
	DAY_POST_CREATED_AT,
	MONTH_POST_CREATED_AT,
	YEAR_POST_CREATED_AT,
	AUTHOR_THREAD_MENTIONS,
	TOTAL_POSTS_WITH_KEYWORD,
	POSITIVE_MENTIONS,
	NEGATIVE_MENTIONS,
	NEUTRAL_MENTIONS,
	PCT_POSITIVE,
	PCT_NEGATIVE,
	PCT_NEUTRAL
) as
WITH thread_author_keyword_sentiment 
AS 
(
  SELECT
    THREAD_ROOT_URI,
    post_author_did,
    keyword,
    topic,
    category,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END) AS positive_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END) AS negative_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END) AS neutral_flag,
    COUNT(POST_URI) AS posts_in_author_thread_mention,
    YEAR_POST_CREATED_AT,
    MONTH_POST_CREATED_AT,
    DAY_POST_CREATED_AT,
    HOUR_POST_CREATED_AT
  FROM steets.thread_matches
  GROUP BY THREAD_ROOT_URI, post_author_did, keyword, topic, category, 
    YEAR_POST_CREATED_AT, MONTH_POST_CREATED_AT, DAY_POST_CREATED_AT, HOUR_POST_CREATED_AT
  )
  
select
  keyword,
  topic,
  category,
  HOUR_POST_CREATED_AT,
  DAY_POST_CREATED_AT,
  MONTH_POST_CREATED_AT,
  YEAR_POST_CREATED_AT,
  COUNT(*) AS author_thread_mentions,
  SUM(posts_in_author_thread_mention) AS total_posts_with_keyword,
  SUM(positive_flag) AS positive_mentions,
  SUM(negative_flag) AS negative_mentions,
  SUM(neutral_flag) AS neutral_mentions,
  (100.0 * SUM(positive_flag)) / NULLIF(COUNT(*), 0) AS pct_positive,
  (100.0 * SUM(negative_flag)) / NULLIF(COUNT(*), 0) AS pct_negative,
  (100.0 * SUM(neutral_flag)) / NULLIF(COUNT(*), 0) AS pct_neutral
FROM
  thread_author_keyword_sentiment
GROUP BY
  YEAR_POST_CREATED_AT,
  MONTH_POST_CREATED_AT,
  DAY_POST_CREATED_AT,
  HOUR_POST_CREATED_AT,
  keyword,
  topic,
  category
ORDER BY
  keyword,    
  HOUR_POST_CREATED_AT,
  DAY_POST_CREATED_AT,
  MONTH_POST_CREATED_AT,
  YEAR_POST_CREATED_AT;