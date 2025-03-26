/*
The Clone-to-Sandbox Sproc runs a lot of RBAC-- any good architect should get nervous if the team starts using it and
no one can see what GRANT/REVOKE statements are actually getting executed.

This view gives that perspective. I'm not sure, however, if this data needs to be persisted. It might need persisting.

I can't find any information in Snowflake's documentation indicating how long they keep information in 
SNOWFLAKE.TELEMETRY.EVENTS. If that is a shorter time period, then a project using this view/sproc might consider
applying a stream and a task to get this data persisted long term.
*/

use role accountadmin;

create or replace view sherlockwings_edw_db.util.clone_to_sandbox_call_log_vw 
as (
select * from (
with base_tbl as (
select start_timestamp as execution_start_timestamp
      ,timestamp as execution_end_timestamp
      ,count(case 
               when resource_attributes['snow.executable.name'] ilike '%clone_to_sandbox%'
               then 1
             end
       ) over ( order by start_timestamp ) as call_number
      ,datediff(second, start_timestamp, timestamp) as execution_duration_seconds
      ,trim(resource_attributes['snow.query.id'], '"') as execution_query_id
      ,trim(resource_attributes['db.user'], '"') as executing_user_name
      ,trim(resource_attributes['snow.session.role.primary.name'], '"') as executing_role_name
      ,trim(resource_attributes['snow.database.name'], '"') as database_name
      ,trim(resource_attributes['snow.schema.name'], '"') as schema_name
      ,split_part(trim(resource_attributes['snow.executable.name'], '"'), '(', 1) as executable_object_name
      ,trim(resource_attributes['snow.executable.type'], '"') as executable_object_type
      ,record_attributes
from snowflake.telemetry.events 
where executable_object_type = 'PROCEDURE'
  and executable_object_name in ('GRANT_TO_SANDBOX', 'REVOKE_CURRENT_ACCESS', 'CLONE_TO_SANDBOX')
  and start_timestamp is not null
)

,stg as (
select execution_start_timestamp
      ,execution_end_timestamp
      ,execution_duration_seconds
      ,call_number
      ,row_number() over (
        partition by call_number
        order     by execution_start_timestamp
      ) as call_subsequence_number
      , * exclude (execution_start_timestamp
                  ,execution_end_timestamp
                  ,execution_duration_seconds
                  ,call_number
                  )           
from base_tbl
)

select a.execution_start_timestamp
      ,a.execution_end_timestamp
      ,a.execution_duration_seconds
      ,a.call_number
      ,a.call_subsequence_number
      ,a.execution_query_id
      ,a.executing_user_name
      ,a.executing_role_name
      ,a.database_name
      ,a.schema_name
      ,a.executable_object_name
      ,a.executable_object_type 
      ,try_cast(replace(trim(b.key, '"'), 'query', '') as number) as query_sequence_number
      ,trim(b.value, '"') as query_text
from stg a,
lateral flatten(input => a.record_attributes) b
order by execution_start_timestamp desc
        ,query_sequence_number desc
)
)
;

grant ownership on view sherlockwings_edw_db.util.clone_to_sandbox_call_log_vw to role sherlockwings_edw_db_util_full_ar;
