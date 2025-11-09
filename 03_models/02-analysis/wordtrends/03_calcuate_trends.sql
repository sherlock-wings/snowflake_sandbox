insert into bluesky_db.pfc.word_trends
with rolling_sum as (
select MONTH_CREATED_AT
      ,N_GRAM
      ,N_GRAM_SIZE
      ,MINIMUM_CONFIDENCE_SCORe
      ,MAXIMUM_CONFIDENCE_SCORe
      ,AVERAGE_SENTIMENT_SCORE
      ,TOTAL_DISTINCT_POSTS
      ,TOTAL_OCCURRENCES
      ,dense_rank() over (
       partition by n_gram, n_gram_size
       order     by month_created_at
      )-1 as age_in_months
from bluesky_db.pfc.ngram_counts
where MONTH_CREATED_AT < date_trunc(month, current_date())
  and month_created_at > nvl((select max(month_created_at) from bluesky_db.pfc.word_trends), to_timestamp_tz('1900-01-01 00:00:00 +0000'))
)
,lagged as (
select a.MONTH_CREATED_AT
      ,a.N_GRAM
      ,a.N_GRAM_SIZE
      ,a.MINIMUM_CONFIDENCE_SCORE
      ,a.MAXIMUM_CONFIDENCE_SCORE
      ,a.AVERAGE_SENTIMENT_SCORE
      ,a.age_in_months
      ,a.TOTAL_DISTINCT_POSTS as TOTAL_DISTINCT_POSTS_THIS_MONTH
      ,a.TOTAL_OCCURRENCES as TOTAL_OCCURRENCES_THIS_MONTH
      ,nvl(b.TOTAL_DISTINCT_POSTS, 0) as TOTAL_DISTINCT_POSTS_LAST_MONTH
      ,nvl(b.TOTAL_OCCURRENCES, 0) as TOTAL_OCCURRENCES_LAST_MONTH
from rolling_sum a 
left join bluesky_db.pfc.ngram_counts b
       on a.n_gram = b.n_gram
      and a.n_gram_size = b.n_gram_size
      and b.month_created_at = dateadd(month, -1, a.month_created_at)
)

select * exclude(TOTAL_DISTINCT_POSTS_THIS_MONTH, TOTAL_OCCURRENCES_THIS_MONTH
                ,TOTAL_DISTINCT_POSTS_LAST_MONTH, TOTAL_OCCURRENCES_LAST_MONTH
                )
       ,total_distinct_posts_this_month
       ,case 
          when TOTAL_DISTINCT_POSTS_LAST_MONTH <> 0 then 
          round((TOTAL_DISTINCT_POSTS_THIS_MONTH - TOTAL_DISTINCT_POSTS_LAST_MONTH)/TOTAL_DISTINCT_POSTS_LAST_MONTH, 1)
          when TOTAL_DISTINCT_POSTS_LAST_MONTH = 0 then 999999
        end as percent_growth
       ,md5(MONTH_CREATED_AT || '||' || N_GRAM || '||' || N_GRAM_SIZE) as record_key
from lagged
;