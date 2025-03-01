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
    snowflake.setSpanAttribute("query"+query_counter.padStart(4, '0'), qry.getSqlText()); // log all queries executed via telemetry
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
    snowflake.setSpanAttribute("query"+query_counter.padStart(4, '0'), qry.getSqlText()); 
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
        snowflake.setSpanAttribute("query"+query_counter.padStart(4, '0'), qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }

    // CHILD SPROC CALL: revoke src rbac 
    var remove_old_grants = "call sherlockwings_edw_db.util.revoke_current_access('"+db_name+"."+schema_ls[i]+"', 'SANDBOX_EDW_DB."+schema_ls[i]+"');"
    var qry = snowflake.createStatement({sqlText:remove_old_grants});
    try {
        qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter.padStart(4, '0'), qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }

    // CHILD SPROC CALL: apply tgt rbac
    var apply_new_grants = "call sherlockwings_edw_db.util.grant_to_sandbox('SANDBOX_EDW_DB."+schema_ls[i]+"');"
    var qry = snowflake.createStatement({sqlText:apply_new_grants});
    try {
        var res = qry.execute();
        query_counter += 1;
        snowflake.setSpanAttribute("query"+query_counter.padStart(4, '0'), qry.getSqlText()); 
    }
    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }
}

return "Successfully cloned " + schema_ls + " schema from " + SOURCE_ENVIRONMENT + " to " + current_user + "'s Sandbox and transferred all access rights."
