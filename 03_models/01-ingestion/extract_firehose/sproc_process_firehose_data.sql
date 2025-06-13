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
    query_step := ''Copy files into INT_FIREHOSE_RAW from S3 Stage'';
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
    copy into bluesky_db.main.int_firehose_raw 
    from (select metadata$filename, $1 from @bluesky_db.main.stg_firehose)
    file_format = (type = json)
    pattern = :copy_path;
    
    row_count := SQLROWCOUNT;
    result := ''SUCCESS'';
    query_id := last_query_id();
    
    -- log 
    insert into bluesky_db.main.process_firehose_sproc_log (
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
    query_step := ''Process records from INT_FIREHOSE_RAW into FIREHOSE_PROCESSED'';
    initiated_at_timestamp := current_timestamp();
    step_id := 2;
    
    -- consume raw data
    merge into bluesky_db.main.firehose_processed tgt
    using (
       select value
             ,cast(trim(a.value:commit:record:createdAt, ''"'') as timestamp_tz) as post_created_at_timestamp
             ,to_timestamp_tz(cast(trim(a.value:time_us, ''"'') as number (38,0)) / 1000000) as usa_timestamp
             ,trim(a.value:commit:cid, ''"'') as content_id
             ,trim(a.value:commit:record:langs) as detected_language_codes
             ,trim(a.value:commit:record:text, ''"'') as post_text
             ,trim(a.value:commit:record:reply:parent:cid, ''"'') as reply_parent_content_id
             ,trim(a.value:commit:record:reply:parent:uri, ''"'') as reply_parent_uri
             ,trim(a.value:commit:record:reply:root:cid, ''"'') as reply_root_content_id
             ,trim(a.value:commit:record:reply:root:uri, ''"'') as reply_root_uri
             ,trim(a.value:commit:record:embed:external:title, ''"'') as external_link_title
             ,trim(a.value:commit:record:embed:external:uri, ''"'') as external_link_uri
             ,to_timestamp_tz(
                    regexp_substr(a.s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 1)
             || regexp_substr(a.s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 2)
             ,''YYYYMMDDHH24MISS''
                    ) as scoop_started_at_timestamp
             ,to_timestamp_tz(
                    regexp_substr(a.s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 3)
             || regexp_substr(a.s3_path, ''^.+[A-Z]_(\\\\d+)_(\\\\d+)UTC_to_(\\\\d+)_(\\\\d+)UTC.jsonl$'', 1, 1, ''c'', 4)
             ,''YYYYMMDDHH24MISS''
                    ) as scoop_stopped_at_timestamp
             ,regexp_substr(a.s3_path, ''^.+/([A-Z]+).+$'', 1, 1, ''c'', 1) as scoop_mode
             ,s3_path
             ,current_timestamp() as record_inserted_at_timestamp
             ,current_user() as record_inserted_by_user
             ,current_role() as record_inserted_with_role 
             ,b.language_name_in_english as first_detected_language
       from bluesky_db.main.int_firehose_raw a
       left join bluesky_db.main.iso_language_codes b
              on regexp_replace(trim(parse_json(a.value:commit:record:langs)[0], ''"'')
                            ,''\-[A-Za-z]+'', ''''
                            ) = b.iso_alpha_2_code
       where value:commit:operation = ''create''
       qualify row_number() over (partition by content_id order by content_id) = 1
       -- ^^ this is a weird one. deliberatley tried w. DISTINCT in this query and in a 
       --    consecutive CTE and neither worked. only this does. ¯\_(ツ)_/¯
    ) src on src.content_id = tgt.content_id
    when not matched then insert (
    value
   ,post_created_at_timestamp
   ,usa_timestamp
   ,content_id
   ,detected_language_codes
   ,post_text
   ,reply_parent_content_id
   ,reply_parent_uri
   ,reply_root_content_id
   ,reply_root_uri
   ,external_link_title
   ,external_link_uri
   ,scoop_started_at_timestamp
   ,scoop_stopped_at_timestamp
   ,scoop_mode
   ,s3_path
   ,record_inserted_at_timestamp
   ,record_inserted_by_user
   ,record_inserted_with_role
   ,first_detected_language
   )
   values (
    src.value
   ,src.post_created_at_timestamp
   ,src.usa_timestamp
   ,src.content_id
   ,src.detected_language_codes
   ,src.post_text
   ,src.reply_parent_content_id
   ,src.reply_parent_uri
   ,src.reply_root_content_id
   ,src.reply_root_uri
   ,src.external_link_title
   ,src.external_link_uri
   ,src.scoop_started_at_timestamp
   ,src.scoop_stopped_at_timestamp
   ,src.scoop_mode
   ,src.s3_path
   ,src.record_inserted_at_timestamp
   ,src.record_inserted_by_user
   ,src.record_inserted_with_role
   ,src.first_detected_language
   );
    
    row_count := SQLROWCOUNT;
    query_id := last_query_id();
    
    -- log 
    insert into bluesky_db.main.process_firehose_sproc_log (
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
    query_step := ''DELETE all records in INT_FIREHOSE_RAW'';
    initiated_at_timestamp := current_timestamp();
    step_id := 3;

    delete from bluesky_db.main.int_firehose_raw;

    query_id := last_query_id();
    row_count := SQLROWCOUNT;

    -- log 
    insert into bluesky_db.main.process_firehose_sproc_log (
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
        insert into bluesky_db.main.process_firehose_sproc_log (
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