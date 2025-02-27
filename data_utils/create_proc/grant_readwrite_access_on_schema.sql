/*
This needs work. Right now, while this sproc does apply the *new* GRANT statements correctly, it does 
not remove the existing ones. So in current state, running this for the arguments provided in the
example call at the bottom results in a Schema where SANDBOX_ENGINEER_FR correctly has privs,
but DEV_ENGINEER_FR incorrectly *still* has privs post-execution.

This might mean we need yet another sproc, but I'm not sure how else to approach this except with
a dedicated piece of code that does the following:

1. Figures out what RBAC already exists for user-defined roles on the target schema
2. Removes the detected RBAC one REVOKE statement at a time

So that probably means this stored procedure needs yet another inner proc

(✖╭╮✖)

*/

use role securityadmin;

create or replace procedure sherlock_wings.util.grant_readwrite_access_on_schema("SCHEMA_NAME" varchar, "READWRITE_AR_NAME" varchar)
returns varchar
language javascript
execute as owner
as 
  
$$

cmd_ls = [
    "GRANT USAGE ON SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON ALL TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME> REVOKE CURRENT GRANTS;"
   ,"GRANT SELECT ON FUTURE TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON ALL VIEWS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON FUTURE VIEWS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON ALL SEQUENCES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON ALL STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT READ ON ALL STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON FUTURE STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT READ ON FUTURE STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON ALL FILE FORMATS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON ALL STREAMS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON FUTURE STREAMS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON ALL PROCEDURES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON ALL FUNCTIONS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT INSERT ON ALL TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT UPDATE ON ALL TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT DELETE ON ALL TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT REFERENCES ON ALL TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT INSERT ON FUTURE TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT UPDATE ON FUTURE TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT DELETE ON FUTURE TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT REFERENCES ON FUTURE TABLES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT WRITE ON FUTURE STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT WRITE ON ALL STAGES IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT MONITOR ON ALL TASKS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT OPERATE ON ALL TASKS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT MONITOR ON FUTURE TASKS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ,"GRANT OPERATE ON FUTURE TASKS IN SCHEMA <SCHEMA_NAME> TO ROLE <ROLE_NAME>;"
   ];
   
for (var list_item of cmd_ls) {
   var cmd = list_item.replace('<SCHEMA_NAME>', SCHEMA_NAME).replace('<ROLE_NAME>', READWRITE_AR_NAME);
   var cmd = snowflake.createStatement( { 
    sqlText: cmd
    } 
   );
   try {
    cmd.execute(); 
   }
   catch (err) {
    return "Failed executing statement `"+cmd.getSqlText()+"`. Error message: `" + err + "`";
   }
}

return "Successfully executed " + cmd_ls.length + " SQL statements";
$$
;

-- example call
call sherlock_wings.util.grant_readwrite_access_on_schema('SANDBOX_EDW_DB.RAW', 'SANDBOX_EDW_DB_FULL_AR');
