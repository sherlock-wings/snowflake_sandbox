----this view aggregate sentiment ratings for each keyword by:
--THREAD. Use this instead of post-level data from PROCESSED table to avoid pseudo-replication of multiple posts.
--a thread is defined as all posts that stem from a parent, until arriving at a root.
--this is needed to reduce autocorrelation due to 'tweetstorms' or multiple posts chained together that would otherwise likely express the same sentiment. An 8-post thread about an article critical of Israel, for example, should only count as 1 with negative sentiment, not 8.

--This table results in rows for summarizing data on keywords by author in a thread. 
--3 authors, 1 post each, same sentiment = 3 flags. 
--1 author, 6 posts, same sentiment = 1 flag.
--2 authors, 2 different sentiments = 2 flags.

--create or replace view BLUESKY_DB.STEETS.THREADS_NLP
(
keyword,
topic,
category,
authors_in_thread,
posts_in_thread,
positive_mentions,
negative_mentions,
neutral_mentions,
pct_positive,
pct_negative,
pct_neutral,
net_sentiment,
avg_sentiment_confidence,
THREAD_ROOT_URI
) as
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
      WHEN LOWER(f.POST_TEXT) LIKE CONCAT('%', LOWER(k.keyword), '%') THEN 1 
      ELSE 0 
    END AS text_match_flag
  FROM steets.firehose_nlp_posts_vw f
  JOIN steets."Keywords_Lookup" k
    ON LOWER(f.POST_TEXT) LIKE CONCAT('%', LOWER(k.keyword), '%') 
  JOIN BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p
    ON p.CONTENT_ID = f.CONTENT_ID
  WHERE LOWER(f.POST_TEXT) LIKE CONCAT('%', LOWER(k.keyword), '%')
  and p.value is not null
)
, 
--each row represents one author mentioning one keyword in one thread. 
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
select 
,

  thread_summary AS 
(
  SELECT
    s.keyword,
    s.topic,
    s.category,
    COUNT(DISTINCT s.post_author_did) AS authors_in_thread,
    COUNT(s.*) AS posts_in_thread,
    SUM(s.positive_flag) AS positive_mentions,
    SUM(s.negative_flag) AS negative_mentions,
    SUM(s.neutral_flag) AS neutral_mentions,
    100.0 * SUM(s.positive_flag) / NULLIF(COUNT(*), 0) AS pct_positive,
    100.0 * SUM(s.negative_flag) / NULLIF(COUNT(*), 0) AS pct_negative,
    100.0 * SUM(s.neutral_flag) / NULLIF(COUNT(*), 0) AS pct_neutral,
    (100.0 * SUM(s.positive_flag) - SUM(s.negative_flag)) / NULLIF(COUNT(*), 0) AS net_sentiment,
    AVG(f.SENTIMENT_CONFIDENCE_SCORE) AS avg_sentiment_confidence,
    s.THREAD_ROOT_URI
  FROM thread_author_keyword_sentiment s
  join thread_matches f on f.THREAD_ROOT_URI = s.THREAD_ROOT_URI
  GROUP BY s.THREAD_ROOT_URI, s.keyword, s.topic, s.category
)
select *
from thread_summary
