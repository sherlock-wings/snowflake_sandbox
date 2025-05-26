CREATE OR REPLACE PROCEDURE BLUESKY_DB.MAIN.PROCESS_FIREHOSE_DATA()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS '
declare
    call_id varchar;
    query_id varchar;
    row_count integer;
    query_step varchar;
    initiated_at_timestamp timestamp_tz(9);
    result varchar;
    sproc_call varchar;
    calling_user varchar;
    calling_role varchar;
    error_msg varchar;
    step_id number(2,0);
    copy_path varchar;
    yesterday_string varchar;
    
    
begin
    -- set log vars
    sproc_call := ''PROCESS_FIREHOSE_DATA()'';
    calling_user := current_user();
    calling_role := current_role();
    query_step := ''Copy files into FIREHOSE_RAW from S3 Stage'';
    initiated_at_timestamp := current_timestamp();
    call_id := uuid_string();
    step_id := 1;
    error_msg := null;

    yesterday_string := to_char(dateadd(day, -1, current_date()));
    
    -- set retrieval path for s3 keys
    copy_path := ''bluesky_firehose/''
        || split_part(:yesterday_string, ''-'', 1) || ''/'' 
        || split_part(:yesterday_string, ''-'', 2) || ''/'' 
        || split_part(:yesterday_string, ''-'', 3) || ''/.*'';
    
    -- ingest staged JSON
    copy into bluesky_db.main.firehose_raw 
    from (select metadata$filename, $1 from @bluesky_db.main.stg_firehose)
    file_format = (type = json)
    pattern = :copy_path;
    
    row_count := SQLROWCOUNT;
    result := ''SUCCESS'';
    query_id := last_query_id();
    
    -- log 
    insert into bluesky_db.main.sproc_log (
    select  :call_id as call_id
           ,:step_id as step_id 
           ,:query_id as query_id 
           ,:initiated_at_timestamp as initiated_at_timestamp 
           ,:query_step as query_step
           ,:result as result
           ,:error_msg as error_msg
           ,:row_count as total_affected_rows
           ,:sproc_call as sproc_call
           ,:calling_user as calling_user
           ,:calling_role as calling_role
    );

    -- reset log vars
    query_step := ''Process records from FIREHOSE_RAW into FIREHOSE_PROCESSED'';
    initiated_at_timestamp := current_timestamp();
    step_id := 2;
    
    -- consume raw data
    insert into bluesky_db.main.firehose_processed (
    with init as (
    select value
          ,cast(trim(value:commit:record:createdAt, ''"'') as timestamp_tz) as post_created_at_timestamp
          ,to_timestamp_tz(cast(trim(value:time_us, ''"'') as number (38,0)) / 1000000) as usa_timestamp
          ,trim(value:commit:cid, ''"'') as content_id
          ,trim(value:commit:record:langs) as detected_languages
          ,trim(value:commit:record:text, ''"'') as post_text
          ,trim(value:commit:record:reply:parent:cid, ''"'') as reply_parent_content_id
          ,trim(value:commit:record:reply:parent:uri, ''"'') as reply_parent_uri
          ,trim(value:commit:record:reply:root:cid, ''"'') as reply_root_content_id
          ,trim(value:commit:record:reply:root:uri, ''"'') as reply_root_uri
          ,trim(value:commit:record:embed:external:title, ''"'') as external_link_title
          ,trim(value:commit:record:embed:external:uri, ''"'') as external_link_uri
          ,to_timestamp_tz(
           regexp_substr(s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 1)
        || regexp_substr(s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 2)
          ,''YYYYMMDDHH24MISS''
           ) as scoop_started_at_timestamp
          ,to_timestamp_tz(
           regexp_substr(s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 3)
        || regexp_substr(s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 4)
          ,''YYYYMMDDHH24MISS''
           ) as scoop_stopped_at_timestamp
          ,regexp_substr(s3_path, ''^.+/([A-Z]+).+$'', 1, 1, ''c'', 1) as scoop_mode
          ,s3_path
          ,current_timestamp()
          ,current_user()
          ,current_role()
    from firehose_raw
    where value:commit:operation = ''create''
    )

    -- remove potential dupes in incoming data 
    ,deduped as (
    select *
    from init
    qualify row_number() over (
            partition by content_id 
            order     by post_created_at_timestamp
    ) = 1
    )

    -- use a "Exclusion Join" to prevent any deduped incoming records from matching existing records
    select a.*
    from deduped a 
    left join bluesky_db.main.firehose_processed b
           on a.content_id = b.content_id
    where b.content_id is null
    
    );
    
    row_count := SQLROWCOUNT;
    query_id := last_query_id();
    
    -- log 
    insert into bluesky_db.main.sproc_log (
    select  :call_id as call_id
           ,:step_id as step_id 
           ,:query_id as query_id 
           ,:initiated_at_timestamp as initiated_at_timestamp 
           ,:query_step as query_step
           ,:result as result
           ,:error_msg as error_msg
           ,:row_count as total_affected_rows
           ,:sproc_call as sproc_call
           ,:calling_user as calling_user
           ,:calling_role as calling_role
    );

    -- reset log vars
    query_step := ''Truncate FIREHOSE_RAW'';
    initiated_at_timestamp := current_timestamp();
    step_id := 3;

    truncate table bluesky_db.main.firehose_raw;

    query_id := last_query_id();
    row_count := null;

    -- log 
    insert into bluesky_db.main.sproc_log (
    select  :call_id as call_id
           ,:step_id as step_id 
           ,:query_id as query_id 
           ,:initiated_at_timestamp as initiated_at_timestamp 
           ,:query_step as query_step
           ,:result as result
           ,:error_msg as error_msg
           ,:row_count as total_affected_rows
           ,:sproc_call as sproc_call
           ,:calling_user as calling_user
           ,:calling_role as calling_role
    );
    
    return ''Success!'';
exception

    when other then
        result := ''FAILURE'';
        error_msg := SQLERRM;
        row_count := null;
        
        -- log 
        insert into bluesky_db.main.sproc_log (
        select  :call_id as call_id
               ,:step_id as step_id 
               ,:query_id as query_id 
               ,:initiated_at_timestamp as initiated_at_timestamp 
               ,:query_step as query_step
               ,:result as result
               ,:error_msg as error_msg
               ,:row_count as total_affected_rows
               ,:sproc_call as sproc_call
               ,:calling_user as calling_user
               ,:calling_role as calling_role
        );
        return ''Error Sproc in process_firehose_data: '' || SQLERRM;
end;
';