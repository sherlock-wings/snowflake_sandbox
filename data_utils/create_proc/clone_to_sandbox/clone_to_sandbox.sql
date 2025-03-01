use role sandbox_sysadmin;

create or replace procedure sandbox_edw_db.util.clone_to_sandbox(SOURCE_ENVIRONMENT varchar)
returns variant
language javascript
execute as owner 
as
$$
// Validate input arg
var input_env = SOURCE_ENVIRONMENT.replace(' ', '').toUpperCase();
var allowed_envs = ['DEV', 'QA', 'PROD'];
if ( !allowed_envs.includes(input_env)) {
    return "Invalid Input '"+SOURCE_ENVIRONMENT+"'. Allowed inputs are 'DEV', 'QA', or 'PROD' (case insensitive)";
}

// get a list of all schemas in the source environment
var db_name = input_env + '_EDW_DB';
var get_schemas = "select schema_name from " + db_name + ".information_schema.schemata where schema_name <> 'INFORMATION_SCHEMA';";

var query_counter = 0;
var qry = snowflake.createStatement({sqlText:get_schemas});
try {
    var res = qry.execute();
    query_counter += 1;
    snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); // log all queries executed via telemetry
}
catch (err) {
    return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
}
var schema_ls = [];
while (res.next()) {
    schema_ls.push(res.getColumnValue(1));
}

// get current user
var get_user = 'select current_user();';

var qry = snowflake.createStatement({sqlText:get_user});
try {
    var res = qry.execute();
    query_counter += 1;
    snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); 
}
catch (err) {
    return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
}
var current_user = '';
while (res.next()) {
    current_user += res.getColumnValue(1);
}

// For each schema that was found, do this:
// 1. Clone the schema from the source env to the target env
// 2. Revoke the source env RBAC
// 3. Apply the target env RBAC
// 4. Repeat for all schemas

var create_clone_template = 'create or replace schema sandbox_edw_db.' + current_user + '_' + '<target> clone <source>';
for (let i = 0; i < schema_ls.length; i++) {

    // create the clone
    var clone_statement = create_clone_template.replace('<target>', schema_ls[i]);
    var clone_statement = clone_statement.replace('<source>', db_name+'.'+schema_ls[i]);
    
    var qry = snowflake.createStatement({sqlText:clone_statement});
    try {
        qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }

    // CHILD SPROC CALL: revoke src rbac 
    var target_schema = 'SANDBOX_EDW_DB.'+current_user+'_'+schema_ls[i];
    var source_schema = db_name+'.'+schema_ls[i];
    var remove_old_grants = "call sherlockwings_edw_db.util.revoke_current_access('"+source_schema+"', '"+target_schema+"');"
    
    var qry = snowflake.createStatement({sqlText:remove_old_grants});
    try {
        res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }
    
    res.next();
    var msg = res.getColumnValue(1).split(' ')[0];
    if ( msg != 'Successfully') {
        return "Error encountered during execution of procedure REVOKE_CURRENT_ACCESS. Error message: `"+res.getColumnValue(1)+"`";
    }
    
    // CHILD SPROC CALL: apply tgt rbac
    var apply_new_grants = "call sherlockwings_edw_db.util.grant_to_sandbox('"+target_schema+"');"
    var qry = snowflake.createStatement({sqlText:apply_new_grants});
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter, qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `+ " + err + "`";
    }
    res.next();
    var msg = res.getColumnValue(1).split(' ')[0];
    if ( msg != 'Successfully') {
        return "Error encountered during execution of procedure GRANT_TO_SANDBOX. Error message: `"+res.getColumnValue(1)+"`";
    }
    
}

return "Successfully cloned " + schema_ls + " schema from " + SOURCE_ENVIRONMENT + " to " + current_user + "'s Sandbox and transferred all access rights."
$$
;
