----this view aggregate sentiment ratings for each keyword by:
--THREAD. Use this instead of post-level data from PROCESSED table to avoid pseudo-replication of multiple posts.
--a thread is defined as all posts that stem from a parent, until arriving at a root.
--this is needed to reduce autocorrelation due to 'tweetstorms' or multiple posts chained together that would otherwise likely express the same sentiment. An 8-post thread about an article critical of Israel, for example, should only count as 1 with negative sentiment, not 8.

--This table results in rows for summarizing data on keywords by author in a thread. 
--3 authors, 1 post each, same sentiment = 3 flags. 
--1 author, 6 posts, same sentiment = 1 flag.
--2 authors, 2 different sentiments

create or replace view BLUESKY_DB.STEETS.THREADS_NLP
(THREAD_ROOT_URI,
keyword,
topic,
category,
authors_in_thread,
total_posts_in_thread,
positive_mentions,
negative_mentions,
neutral_mentions,
pct_positive,
pct_negative,
pct_neutral,
net_sentiment,
avg_sentiment_confidence_thread
) as
WITH 
--each row represents one author mentioning one keyword in one thread. 
thread_author_keyword_sentiment AS (
  SELECT
    THREAD_ROOT_URI,
    post_author_did,
    keyword,
    topic,
    category,
    COUNT(POST_URI) AS posts_by_author_in_thread,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END) AS positive_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END) AS negative_flag,
    MAX(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END) AS neutral_flag,
    AVG(SENTIMENT_CONFIDENCE_SCORE) AS avg_sentiment_confidence
  FROM STEETS.THREAD_MATCHES --minimum sentiment confidence score is 0.6
  GROUP BY THREAD_ROOT_URI, post_author_did, keyword, topic, category
)
,
threads_nlp as
(  SELECT
    s.THREAD_ROOT_URI,
    s.keyword,
    s.topic,
    s.category,
    COUNT(DISTINCT s.post_author_did) AS authors_in_thread,
    SUM(s.posts_by_author_in_thread) AS total_posts_in_thread,
    SUM(s.positive_flag) AS positive_mentions,
    SUM(s.negative_flag) AS negative_mentions,
    SUM(s.neutral_flag) AS neutral_mentions,
    100.0 * SUM(s.positive_flag) / NULLIF(COUNT(*), 0) AS pct_positive,
    100.0 * SUM(s.negative_flag) / NULLIF(COUNT(*), 0) AS pct_negative,
    100.0 * SUM(s.neutral_flag) / NULLIF(COUNT(*), 0) AS pct_neutral,
    (100.0 * SUM(s.positive_flag) - SUM(s.negative_flag)) / NULLIF(COUNT(*), 0) AS net_sentiment,
    AVG(s.avg_sentiment_confidence) AS avg_sentiment_confidence_thread
  FROM thread_author_keyword_sentiment s 
  GROUP BY s.THREAD_ROOT_URI, s.keyword, s.topic, s.category
  )

  select * from threads_nlp