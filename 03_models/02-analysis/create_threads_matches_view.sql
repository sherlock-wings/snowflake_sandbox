
--creates a view which searches for keywords in a table named in the lateral join after FROM.
--currently set to "keywords_testing" but can be altered to any table with these column names: [keyword], [category], [topic]
--also integrates a filter to only those matches where NLP confidence is >0.6 for cleaner results. Could even be set higher.

--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*
--this view is a prerequisite for the threads_nlp, timeseries_nlp, and authors_nlp views.
--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*

create or replace view BLUESKY_DB.STEETS.THREAD_MATCHES(
	POST_URI,
	POST_AUTHOR_DID,
	TIMESTAMP_POST_CREATED,
	REPLY_ROOT_URI,
	YEAR_POST_CREATED_AT,
	MONTH_POST_CREATED_AT,
	DAY_POST_CREATED_AT,
	HOUR_POST_CREATED_AT,
	KEYWORD,
	CATEGORY,
	TOPIC,
	THREAD_ROOT_URI,
	SENTIMENT_DETECTED_LABEL,
	SENTIMENT_CONFIDENCE_SCORE
) as (
SELECT
  f.POST_URI,
  f.POST_AUTHOR_DID,
  f.TIMESTAMP_POST_CREATED,
  f.REPLY_ROOT_URI,
  f.YEAR_POST_CREATED_AT,
  f.MONTH_POST_CREATED_AT,
  f.DAY_POST_CREATED_AT,
  f.HOUR_POST_CREATED_AT,
  k.keyword,
  k.category,
  k.topic,
  CASE
    WHEN f.REPLY_ROOT_URI IS NULL THEN f.POST_URI
    ELSE f.REPLY_ROOT_URI
  END AS THREAD_ROOT_URI,
  f.SENTIMENT_DETECTED_LABEL,
  f.SENTIMENT_CONFIDENCE_SCORE
FROM
  steets.firehose_nlp_posts_vw f
JOIN LATERAL (
  SELECT keyword, topic, category
  FROM steets.keywords_testing k --testing version only includes 4 keywords to save compute. Final table can have whatever we want.
  WHERE f.POST_TEXT ILIKE '%' || k.keyword || '%'
) k
where sentiment_confidence_score > 0.6 );