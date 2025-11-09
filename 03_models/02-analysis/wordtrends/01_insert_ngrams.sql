insert into bluesky_db.pfc.post_ngrams 
with init as (
select content_id 
      ,usa_timestamp
      ,date_trunc(month, usa_timestamp) as month_created_at
      /*
      1. Convert to lower case
      2. Replace newlines with spaces
      3. Remove all characters that are not part of words or spaces
      4. split on space
      5. Remove all elements with a length of 1 or 0
      */
      ,filter(
              split(
                    regexp_replace(
                                   regexp_replace(lower(post_text)
                                                  , '\n|/|#', ' ')
                   , '[^\\w\\s]', ' ')
             , ' ')
      ,a-> length(a)>1
      ) as post_tokens
from bluesky_db.main.firehose_processed
where (first_detected_language is null 
       or first_detected_language ilike '%english%'
      )
  and usa_timestamp > nvl((select max(usa_timestamp) from bluesky_db.pfc.post_ngrams), to_timestamp_tz('1900-01-01 00:00:00 +0000'))
)

,tokenized as (
select i.content_id
      ,i.usa_timestamp
      ,i.month_created_at
      ,f.index+1 as token_positions
      ,trim(lower(f.value), '"') as token
from init i,
lateral flatten(input => i.post_tokens) f
)

,unigrams as (
select a.content_id
      ,a.usa_timestamp
      ,a.month_created_at
      ,a.token_positions::varchar as token_positions
      ,a.token as unigram
      ,b.sentiment_detected_label
      ,b.sentiment_confidence_score
from tokenized a 
join bluesky_db.main.firehose_nlp_labeled b
  on a.content_id = b.content_id
left join bluesky_db.pfc.stopwords_english c
       on a.token = c.word
where c.word is null
)



,bigrams as (
select a.content_id
      ,a.usa_timestamp
      ,a.month_created_at
      ,a.token_positions || ', ' || b.token_positions as token_positions
      ,a.unigram || ' ' || b.unigram as bigram
      ,a.sentiment_detected_label
      ,a.sentiment_confidence_score
from unigrams a 
join unigrams b 
  on a.content_id = b.content_id
 and a.token_positions+1 = b.token_positions
)


,trigrams as (
select a.content_id
      ,a.usa_timestamp
      ,a.month_created_at
      ,a.token_positions || ', ' || b.token_positions as token_positions
      ,a.bigram || ' ' || b.unigram as trigram
      ,a.sentiment_detected_label
      ,a.sentiment_confidence_score
from bigrams a 
join unigrams b 
  on a.content_id = b.content_id
 and to_number(split_part(a.token_positions, ', ', 2))+1 = b.token_positions
)

,union_tbl as (
select * exclude(unigram), trim(unigram, ' ') as n_gram, 1 as n_gram_size 
from unigrams 
union
select * exclude(bigram), trim(bigram, ' ') as n_gram, 2 as n_gram_size 
from bigrams
union
select * exclude(trigram), trim(trigram, ' ') as n_gram, 3 as n_gram_size 
from trigrams
)

select *
      ,md5(content_id || '||' || n_gram || '||' || token_positions) as record_key
from union_tbl
where length(n_gram) > 0
;