create or replace view bluesky_db.main.firehose_nlp_vw as (
select a.post_created_usa_timestamp as post_created_at
      ,b.post_text
      ,b.length(post_text) as total_post_characters
      ,b.first_detected_language as language
      ,a.sentiment_detected_label
      ,a.sentiment_confidence_score
      ,a.ner_detected_group
      ,a.ner_detected_entity
      ,a.post_entity_number
      ,a.ner_confidence_score
from bluesky_db.main.firehose_nlp_labeled a
join bluesky_db.main.firehose_processed b
  on a.content_id = b.content_id
order by a.post_created_usa_timestamp desc
        ,a.post_entity_number
);