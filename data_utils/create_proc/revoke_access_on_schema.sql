use role securityadmin;

create or replace procedure sherlock_wings.util.revoke_access_on_schema(SCHEMA_NAME varchar)
returns varchar
language javascript
execute as owner
as 
$$
var env_full_ar_name = SCHEMA_NAME.toUpperCase().split('.')[0] 

// Tiny exception with SANDBOX roles-- usually we are trying to generate a role name like 
// <ENVNAME>_EDW_DB_<SCHEM_NAME>_FULL_AR. However, because the Sandbox environment only gets schema rights on-the-fly
// from sprocs, and the "native" rights are all DB level, the names for the roles in Sandbox have no <SCHEMA_NAME>
// infix like the ones in Dev/QA/Prod do. So we do this little thingy here to get around that.

if ( !SCHEMA_NAME.includes('SANDBOX') ) {
    env_full_ar_name += '_' + SCHEMA_NAME.toUpperCase().split('.')[1];
}

env_full_ar_name += '_FULL_AR';

// Remove existing RBAC-- the "bare" OWNERSHIP privs will be filled out with additional privs in the application 
// of a subsequent sproc 
var revoke_ls = [
     'grant ownership on all tables in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all views in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all materialized views in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all procedures in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all functions in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all file formats in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all streams in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on all stages in schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
    ,'grant ownership on schema <SCHEMA_NAME> to role <ROLE_NAME> revoke current grants;'
];

for (let i = 0; i < revoke_ls.length; i++) {
    var cmd = revoke_ls[i].replace('<SCHEMA_NAME>', SCHEMA_NAME).replace('<ROLE_NAME>', env_full_ar_name);

    var cmd = snowflake.createStatement( { sqlText: cmd } );

    try { 
        cmd.execute(); 
    }
    
    catch (err) {
        return "Failed executing statement `"+cmd.getSqlText()+"`. Error message: `" + err + "`";
    }
}

return "Successfully executed " + revoke_ls.length + " SQL statements.";
$$
;

-- example call
-- call sherlock_wings.util.revoke_access_on_schema('SANDBOX_EDW_DB.RAW');
