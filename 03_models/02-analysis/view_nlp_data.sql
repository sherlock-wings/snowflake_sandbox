create or replace view bluesky_db.main.firehose_nlp_vw as (
select a.analysis_id
      ,a.content_id
      ,a.post_created_usa_timestamp as timestamp_post_created
      ,to_date(a.post_created_usa_timestamp) as date_post_created
      ,year(a.post_created_usa_timestamp) as year_post_created_at
      ,quarter(a.post_created_usa_timestamp) as quarter_post_created_at
      ,month(a.post_created_usa_timestamp) as month_post_created_at
      ,day(a.post_created_usa_timestamp) as day_post_created_at
      ,hour(a.post_created_usa_timestamp) as hour_post_created_at
      ,b.post_text
      ,length(b.post_text) as total_post_characters
      ,b.first_detected_language as language
      ,a.sentiment_detected_label
      ,a.sentiment_confidence_score
      ,a.ner_detected_group
      ,a.ner_detected_entity
      ,length(a.ner_detected_entity) as total_characters_ner_detected_entity
      ,a.post_entity_number
      ,a.ner_confidence_score
from bluesky_db.main.firehose_nlp_labeled a
join bluesky_db.main.firehose_processed b
  on a.content_id = b.content_id
order by a.post_created_usa_timestamp desc
        ,a.post_entity_number
);