
/*
For background on how bluesky_db.pfc.NER_SENTANA_OUTPUT_SAMPLE is created, see 
snowflake_sandbox/03_models/02-analysis/nlp.ipynb
*/
create or replace view bluesky_db.pfc.nersentana_output_vw as (
with src as (
select a.content_id
      ,a.usa_timestamp
      ,a.detected_languages
      ,a.post_text
      ,b.readable_label_name as sentana_model_label_name
      ,cast(sentiment_analysis:score as number(5,4)) as sentana_confidence_score
      ,row_number() over (
       partition by content_id
       order     by usa_timestamp, trim(a2.value:word, '"')
       ) as post_entity_number
      ,trim(a2.value:entity_group, '"') as ner_detected_group
      ,trim(a2.value:word, '"') as ner_detected_entity
      ,cast(a2.value:score as number(5,4)) as ner_confidence_score
from bluesky_db.pfc.NER_SENTANA_OUTPUT_SAMPLE a
left join table(flatten(input => parse_json(a.ner_analysis))) a2
left join label_map_roberta_base_sentiment b
       on trim(a.sentiment_analysis:label, '"') = b.model_label_name
where ner_analysis <> '[]'
  and ner_confidence_score >= 0.7
  and sentana_confidence_score >= 0.7
)

select sha2(nvl(to_char(content_id), 'NULL') 
         || '||' 
         || nvl(to_char(post_entity_number), 'NULL')
       ) as analysis_id
      ,*
from src 
order by content_id, usa_timestamp, ner_detected_entity
)
;

