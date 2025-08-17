-- --aggregates threads data at the keyword-level for statistical tests on the population of all threads.
--threads are used to avoid pseudoreplication of multiple keyword mentions by the same person in rapid succession, such as posting a self-reply thread.
create or replace view BLUESKY_DB.STEETS.THREADS_keywords_Summarystats
(keyword
,topic
,category
,total_authors
,total_threads
,total_posts
,total_positive_posts
,total_neutral_posts
,total_negative_posts
,positive_threads
,neutral_threads
,negative_threads
,percent_positive
,percent_neutral
,percent_negative
,avg_sentiment_confidence)
as
WITH thread_sentiment AS (
  SELECT
  thread_root_uri
,   CASE WHEN POSITIVE_MENTIONS > 0 THEN 1 ELSE 0 END AS has_positive_posts
,   CASE WHEN NEUTRAL_MENTIONS > 0 THEN 1 ELSE 0 END AS has_neutral_posts
,   CASE WHEN NEGATIVE_MENTIONS > 0 THEN 1 ELSE 0 END AS has_negative_posts
  FROM threads_nlp
)

select 
n.keyword
,n.topic
,n.category
,sum(n.authors_in_thread) as total_authors
,count(n.*) as total_threads
,sum(n.total_posts_in_thread) as total_posts
,sum(n.positive_mentions) as total_positive_posts
,sum(n.neutral_mentions) as total_neutral_posts
,sum(n.negative_mentions) as total_negative_posts
,  COUNT_IF(s.has_positive_posts > 0) as positive_threads
,  COUNT_IF(s.has_neutral_posts > 0) as neutral_threads
,  COUNT_IF(s.has_negative_posts > 0) as negative_threads
,avg(n.pct_positive) as percent_positive
,avg(n.pct_neutral) as percent_neutral
,avg(n.pct_negative) as percent_negative
,avg(n.avg_sentiment_confidence_thread) as avg_sentiment_confidence
from threads_nlp n
join thread_sentiment s on n.thread_root_uri = s.thread_root_uri
GROUP BY n.keyword, n.topic, n.category
