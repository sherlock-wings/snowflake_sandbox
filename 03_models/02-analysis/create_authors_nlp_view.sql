

create or replace view BLUESKY_DB.STEETS.AUTHORS_NLP 
(
author_did,
keyword,
topic,
category,
author_keyword_mention_count,
threads_started,
positive_mentions,
negative_mentions,
neutral_mentions,
author_pct_positive,
author_pct_negative,
author_pct_neutral,
author_net_sentiment,
avg_sentiment_confidence
)
as
WITH thread_matches AS (
  SELECT
    f.CONTENT_ID,
    f.SENTIMENT_DETECTED_LABEL,
    f.SENTIMENT_CONFIDENCE_SCORE,
    CASE WHEN p.REPLY_ROOT_URI IS NULL THEN POST_URI
        ELSE p.reply_root_uri END as THREAD_ROOT_URI,
    p.post_author_did,
    k.keyword,
    k.category,
    k.topic,
    CASE 
      WHEN f.POST_TEXT ILIKE '%' || k.keyword || '%' THEN 1  
      ELSE 0 
    END AS text_match_flag
FROM steets.firehose_nlp_posts_vw f
JOIN BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p ON p.CONTENT_ID = f.CONTENT_ID
JOIN LATERAL (
    SELECT keyword, topic, category
    FROM steets."Keywords_Lookup" k
    WHERE f.POST_TEXT ILIKE '%' || k.keyword || '%'
) k
WHERE p.value IS NOT NULL
)
, 
thread_author_keyword_sentiment AS (
  SELECT
    THREAD_ROOT_URI,
    post_author_did,
    keyword,
    topic,
    category,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END) AS positive_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END) AS negative_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END) AS neutral_flag
  FROM thread_matches
  GROUP BY THREAD_ROOT_URI, post_author_did, keyword, topic, category
)
,
author_root_threads
as
(select   
    post_author_did,
    COUNT(DISTINCT POST_URI) AS threads_started
FROM BLUESKY_DB.MAIN.FIREHOSE_PROCESSED
  WHERE POST_URI = REPLY_ROOT_URI OR REPLY_ROOT_URI IS NULL
  GROUP BY post_author_did
)
,

  author_summary AS 
(
  SELECT
    s.post_author_did AS author_did,
    s.keyword,
    s.topic,
    s.category,
    count (s.*) as author_keyword_mention_count, --posts
    coalesce(r.threads_started,0) AS threads_started, 
    SUM(s.positive_flag) AS positive_mentions,
    SUM(s.negative_flag) AS negative_mentions,
    SUM(s.neutral_flag) AS neutral_mentions,
    100.0 * SUM(s.positive_flag) / NULLIF(COUNT(*), 0) AS author_pct_positive,
    100.0 * SUM(s.negative_flag) / NULLIF(COUNT(*), 0) AS author_pct_negative,
    100.0 * SUM(s.neutral_flag) / NULLIF(COUNT(*), 0) AS author_pct_neutral,
    (100.0 * SUM(s.positive_flag) - SUM(s.negative_flag)) / NULLIF(COUNT(*), 0) AS author_net_sentiment,
    AVG(f.SENTIMENT_CONFIDENCE_SCORE) AS avg_sentiment_confidence,
  FROM thread_author_keyword_sentiment s
  join thread_matches f on f.THREAD_ROOT_URI = s.THREAD_ROOT_URI
  join author_root_threads r on r.post_author_did = s.post_author_did
  GROUP BY s.post_author_did, threads_started, s.keyword, s.topic, s.category
)
select *
from author_summary