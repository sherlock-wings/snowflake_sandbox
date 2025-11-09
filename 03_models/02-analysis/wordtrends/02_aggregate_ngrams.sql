insert into bluesky_db.pfc.ngram_counts
select MONTH_CREATED_AT
      ,N_GRAM
      ,N_GRAM_SIZE
      ,min(sentiment_confidence_score) as minimum_confidence_score
      ,max(sentiment_confidence_score) as maximum_confidence_score
      ,avg(SENTIMENT_CONFIDENCE_SCORE) as average_sentiment_score
      ,count(distinct content_id) as total_distinct_posts
      ,count(*) as total_occurrences 
from post_ngrams
where MONTH_CREATED_AT < date_trunc(month, current_date())
  and month_created_at > nvl((select max(month_created_at) from bluesky_db.pfc.ngram_counts), to_timestamp_tz('1900-01-01 00:00:00 +0000'))
group by all 
;