use role dev_fr;
use schema bluesky_db.pfc;
use warehouse compute_wh;

create table if not exists bluesky_db.pfc.label_map_roberta_base_sentiment as (
select 'LABEL_0' as model_label_name, 'Negative' as readable_label_name union all
select 'LABEL_1' as model_label_name, 'Neutral' as readable_label_name union all
select 'LABEL_2' as model_label_name, 'Positive' as readable_label_name
);