use role gatsby_nonprod_developer_role;
use schema gatsby_dev.tmp_pcallahan;
use warehouse gatsby_read_dev;

/*
So this is a neat trick for doing deep dives on query optimization.
Get all the data served up in the Query History page in Snowsight and persist long term for analysis

Uses this weird sproc that you kinda have to run over and over again. The author says that it "Times out"
but the error shown usually doesn't look like a timeout. Regardless, you basically just run the section
beginning with DECLARE over and over again until your "operator-stats" table has basically the 
same number of unique query ids as your 'query-log' table

This is shamelessly stolen from
    https://hoffa.medium.com/deep-performance-analysis-with-the-new-query-operator-stats-in-snowflake-74837971c5d3

SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | 
SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | 
SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | 
SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | SECTION 1 | 

    Collect log data
*/
create table if not exists query_log_load_nam_variants as (
select top 0 *
from table(information_schema.query_history())
);

insert into query_log_load_nam_variants (
select a.* 
from table(information_schema.query_history()) a
left join query_log_load_nam_variants b
       on a.query_id = b.query_id
where a.schema_name = 'TMP_PCALLAHAN'
  and b.query_id is null 
);

/*


*/

create table if not exists query_operator_stats_load_nam_variants
as
select 1::integer session_id, ''::string query_tag, * 
from table(get_query_operator_stats(last_query_id()))
-- just for the schema
limit 0;



declare
  query_id string;
  query_tag string;
  session_id int;
  c1 cursor for 
    select query_id, session_id, query_tag
    from query_log_load_nam_variants 
    where query_id not in (select query_id from query_operator_stats_load_nam_variants);
begin
  open c1;
  for record in c1 do
    fetch c1 into query_id, session_id, query_tag;
    insert into query_operator_stats_load_nam_variants
      select :session_id, :query_tag, * from table(get_query_operator_stats(:query_id));  
  end for;
  return query_id;
end;

select count(*) from query_log_load_nam_variants;
select count(distinct query_id) as total_query_ids from query_operator_stats_load_nam_variants;

create or replace view query_log_detail_load_nam_variants as (
select a.QUERY_ID
      ,a.QUERY_TEXT
      ,a.WAREHOUSE_SIZE
      ,a.START_TIME
      ,a.END_TIME
      ,a.QUEUED_PROVISIONING_TIME
      ,a.QUEUED_REPAIR_TIME
      ,a.QUEUED_OVERLOAD_TIME
      ,a.COMPILATION_TIME
      ,a.EXECUTION_TIME
      ,a.TOTAL_ELAPSED_TIME
      ,b.STEP_ID
      ,b.OPERATOR_ID
      ,b.PARENT_OPERATORS
      ,b.OPERATOR_TYPE
      ,b.OPERATOR_STATISTICS
      ,b.EXECUTION_TIME_BREAKDOWN
      ,b.OPERATOR_ATTRIBUTES
      ,a.DATABASE_NAME
      ,a.SCHEMA_NAME
      ,a.QUERY_TYPE
      ,a.SESSION_ID
      ,a.USER_NAME
      ,a.USER_TYPE
      ,a.USER_DATABASE_NAME
      ,a.USER_SCHEMA_NAME
      ,a.ROLE_NAME
      ,a.WAREHOUSE_NAME
      ,a.WAREHOUSE_TYPE
      ,a.CLUSTER_NUMBER
      ,a.QUERY_TAG
      ,a.EXECUTION_STATUS
      ,a.ERROR_CODE
      ,a.ERROR_MESSAGE
      ,a.BYTES_SCANNED
      ,a.ROWS_PRODUCED
      ,a.TRANSACTION_BLOCKED_TIME
      ,a.OUTBOUND_DATA_TRANSFER_CLOUD
      ,a.OUTBOUND_DATA_TRANSFER_REGION
      ,a.OUTBOUND_DATA_TRANSFER_BYTES
      ,a.INBOUND_DATA_TRANSFER_CLOUD
      ,a.INBOUND_DATA_TRANSFER_REGION
      ,a.INBOUND_DATA_TRANSFER_BYTES
      ,a.CREDITS_USED_CLOUD_SERVICES
      ,a.LIST_EXTERNAL_FILE_TIME
      ,a.RELEASE_VERSION
      ,a.EXTERNAL_FUNCTION_TOTAL_INVOCATIONS
      ,a.EXTERNAL_FUNCTION_TOTAL_SENT_ROWS
      ,a.EXTERNAL_FUNCTION_TOTAL_RECEIVED_ROWS
      ,a.EXTERNAL_FUNCTION_TOTAL_SENT_BYTES
      ,a.EXTERNAL_FUNCTION_TOTAL_RECEIVED_BYTES
      ,a.IS_CLIENT_GENERATED_STATEMENT
      ,a.QUERY_HASH
      ,a.QUERY_HASH_VERSION
      ,a.QUERY_PARAMETERIZED_HASH
      ,a.QUERY_PARAMETERIZED_HASH_VERSION
      ,a.TRANSACTION_ID
      ,a.QUERY_ACCELERATION_BYTES_SCANNED
      ,a.QUERY_ACCELERATION_PARTITIONS_SCANNED
      ,a.QUERY_ACCELERATION_UPPER_LIMIT_SCALE_FACTOR
      ,a.BYTES_WRITTEN_TO_RESULT
      ,a.ROWS_WRITTEN_TO_RESULT
      ,a.ROWS_INSERTED
      ,a.QUERY_RETRY_TIME
      ,a.QUERY_RETRY_CAUSE
      ,a.FAULT_HANDLING_TIME
from query_log_load_nam_variants a
left join query_operator_stats_load_nam_variants b
       on a.query_id = b.query_id
where a.warehouse_name = 'GATSBY_INGEST_DEV'
);

select * from query_log_detail_load_nam_variants 
where query_text not like 'CALL%'
order by execution_time desc;