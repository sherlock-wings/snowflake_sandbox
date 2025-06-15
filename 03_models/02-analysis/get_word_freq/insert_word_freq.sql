insert into word_freq 
with src as (
select usa_timestamp as post_created_at
      ,post_text
      ,'join' as join_col
from bluesky_db.main.firehose_processed
where first_detected_language = 'English'
   or first_detected_language is null
)

,stopword_tbl as (
select list_vals, 'join' as join_col from stopwords_list
)

,join_tbl as (
select a.post_text
      ,a.post_created_at
      ,b.list_vals as stopwords 
from src a
join stopword_tbl b
  on a.join_col = b.join_col
)


,cleaned_tokens as (
select post_created_at
      ,remove_stopwords(stopwords, post_text) as post_cleaned
from join_tbl
order by 2
)

,blowout as (
select trim(b.value, '""') as word, a.post_cleaned, a.post_created_at 
from cleaned_tokens a,
lateral flatten(input => a.post_cleaned) b
)

-- select *
-- from  blowout where post_text ilike '%it\'s%';

,gby as (
select word
      ,min(post_created_at) as firehose_window_start_at
      ,max(post_created_at) as firehose_window_end_at
      ,count(*) as frequency
from blowout
group by 1
)

select word
      ,frequency
      ,firehose_window_start_at
      ,firehose_window_end_at
      ,current_timestamp() as inserted_at_timestamp
      ,current_user() as inserted_by_user
      ,current_role() as inserted_with_role
from gby
;