-- set context
use role admin_fr;
use schema bluesky_db.main;

-- instantiate raw data table
create table if not exists firehose_raw (
 s3_path varchar  
,value variant
);

-- ingest staged JSON
copy into firehose_raw 
from (select metadata$filename, $1 from @stg_thehippus_feed)
file_format = (type = json);

-- instantiate processed data table
create table if not exists firehose_processed (
 post_created_at_timestamp timestamp_tz(9)
,content_id varchar
,detected_languages varchar
,post_text varchar
,reply_parent_content_id varchar
,reply_parent_uri varchar
,reply_root_content_id varchar
,reply_root_uri varchar
,external_link_title varchar
,external_link_uri varchar
,scoop_started_at_timestamp timestamp_tz(9)
,scoop_stopped_at_timestamp timestamp_tz(9)
,scoop_mode varchar
);


-- consume raw data
insert into firehose_processed (
with init as (
select value
      ,cast(trim(value:commit:record:createdAt, '"') as timestamp_tz) as post_created_at_timestamp
      ,to_timestamp_tz(cast(trim(value:time_us, '"') as number (38,0)) / 1000000) as usa_timestamp
      ,trim(value:commit:cid, '"') as content_id
      ,trim(value:commit:record:langs) as detected_languages
      ,trim(value:commit:record:text, '"') as post_text
      ,trim(value:commit:record:reply:parent:cid, '"') as reply_parent_content_id
      ,trim(value:commit:record:reply:parent:uri, '"') as reply_parent_uri
      ,trim(value:commit:record:reply:root:cid, '"') as reply_root_content_id
      ,trim(value:commit:record:reply:root:uri, '"') as reply_root_uri
      ,trim(value:commit:record:embed:external:title, '"') as external_link_title
      ,trim(value:commit:record:embed:external:uri, '"') as external_link_uri
      ,to_timestamp_tz(
       regexp_substr(s3_path, '^.+[A-Z]_(\\d+)_(\\d+)UTC_to_(\\d+)_(\\d+)UTC.jsonl$', 1, 1, 'c', 1)
    || regexp_substr(s3_path, '^.+[A-Z]_(\\d+)_(\\d+)UTC_to_(\\d+)_(\\d+)UTC.jsonl$', 1, 1, 'c', 2)
      ,'YYYYMMDDHH24MISS'
       ) as scoop_started_at_timestamp
      ,to_timestamp_tz(
       regexp_substr(s3_path, '^.+[A-Z]_(\\d+)_(\\d+)UTC_to_(\\d+)_(\\d+)UTC.jsonl$', 1, 1, 'c', 3)
    || regexp_substr(s3_path, '^.+[A-Z]_(\\d+)_(\\d+)UTC_to_(\\d+)_(\\d+)UTC.jsonl$', 1, 1, 'c', 4)
      ,'YYYYMMDDHH24MISS'
       ) as scoop_stopped_at_timestamp
      ,regexp_substr(s3_path, '^.+/([A-Z]+).+$', 1, 1, 'c', 1) as scoop_mode
from firehose_raw
where value:commit:operation = 'create'
)

select *
from init 
where cast(trim(value:commit:record:createdAt, '"') as timestamp_tz) > 
      nvl(
          (select max(post_created_at_timestamp) from firehose_processed)
          ,to_timestamp_tz('1900-01-01 00:00:00 +0000')
         ) -- watermark logic
);

select * 
from firehose_processed 
where scoop_stopped_at_timestamp is not null
order by scoop_stopped_at_timestamp desc
limit 500;