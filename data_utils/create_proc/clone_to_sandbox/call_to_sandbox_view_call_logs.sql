use role accountadmin;

select start_timestamp as execution_start_timestamp
      ,timestamp as execution_end_timestamp
      ,count(case 
               when resource_attributes['snow.executable.name'] ilike '%clone_to_sandbox%'
               then 1
             end
       ) over ( order by start_timestamp ) as clone_to_sandbox_call_number
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
order by start_timestamp desc
;
