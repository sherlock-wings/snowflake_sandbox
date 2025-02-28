use role securityadmin;
use warehouse sherlockwings_compute_wh;

create or replace procedure sherlockwings_edw_db.util.revoke_current_access(SOURCE_SCHEMA varchar, TARGET_SCHEMA varchar)
returns variant
language javascript
execute as caller 
as
$$
var query_counter = 0;

var role_string = SOURCE_SCHEMA.toUpperCase().split('.')[0] + '_' + SOURCE_SCHEMA.toUpperCase().split('.')[1];
var read_role = role_string + '_' + 'R_AR';
var readwrite_role = role_string + '_' + 'RW_AR';
var full_role = role_string + '_' + 'FULL_AR';

var roles = {'read': read_role ,'readwrite': readwrite_role,'full': full_role};

var get_grants_template = "select command_text from sherlockwings_edw_db.util.def_schema_access_<access-type> where command_text ilike '%all%in schema%' and first_time_setup_ind = false order by command_ordinal";
var revoke_ls = [];

// Collect into a single list all REVOKE statements needed for revocation on Read, Read/Write, and Full access roles 
for (const access_type in roles) {
    var get_grants = get_grants_template.replace('<access-type>', access_type);
    var qry = snowflake.createStatement({sqlText:get_grants});
    
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText());
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }

    while (res.next()) {
        var revoke_statement = res.getColumnValue(1).replace('GRANT', 'REVOKE');
        var revoke_statement = revoke_statement.replace('<schema-name>', TARGET_SCHEMA);
        var revoke_statement = revoke_statement.replace('TO ROLE', 'FROM ROLE');
        var revoke_statement = revoke_statement.replace('<' + access_type + '-access-role-name>', roles[access_type]);
        revoke_ls.push(revoke_statement);
    }
}

// Revoke all access from all roles on target schema

for (let i = 0; i < revoke_ls.length; i++) {

    qry = snowflake.createStatement({sqlText: revoke_ls[i]});
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText());
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }
}

return "Successfully executed " + revoke_ls.length + " SQL statements";
$$
;
