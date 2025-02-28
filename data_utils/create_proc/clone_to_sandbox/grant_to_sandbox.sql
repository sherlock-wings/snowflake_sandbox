create or replace procedure sherlockwings_edw_db.util.grant_to_sandbox(TARGET_SCHEMA varchar)
returns variant
language javascript
execute as owner 
as
$$
var query_counter = 0;

var role_string = TARGET_SCHEMA.toUpperCase().split('.')[0];
var read_role = role_string + '_' + 'R_AR';
var readwrite_role = role_string + '_' + 'RW_AR';
var full_role = role_string + '_' + 'FULL_AR';

var roles = {'full': full_role, 'readwrite': readwrite_role, 'read': read_role};

var get_grants_template = "select command_text from sherlockwings_edw_db.util.def_schema_access_<access-type> where first_time_setup_ind = false order by command_ordinal";
var grant_ls = [];

// Collect into a single list all GRANT statements needed for revocation on Read, Read/Write, and Full access roles 
for (const access_type in roles) {
    var get_grants = get_grants_template.replace('<access-type>', access_type);
    var qry = snowflake.createStatement({sqlText:get_grants});
    
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); // log all queries executed via telemetry
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }

    while (res.next()) {
        var grant_statement = res.getColumnValue(1).replace('<schema-name>', TARGET_SCHEMA);
        var grant_statement = grant_statement.replace('<' + access_type + '-access-role-name>', roles[access_type]);
        grant_ls.push(grant_statement);
    }
}

// Grant all access to all roles on target schema
for (let i = 0; i < grant_ls.length; i++) {

    qry = snowflake.createStatement({sqlText: grant_ls[i]});
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText());
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }
}

return "Successfully executed " + grant_ls.length + " SQL statements";
$$
;
