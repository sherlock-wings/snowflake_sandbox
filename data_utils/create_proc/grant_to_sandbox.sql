use role securityadmin;
use warehouse sherlockwings_compute_wh;
use schema sherlockwings_edw_db.util;

create or replace procedure grant_to_sandbox(SCHEMA_NAME varchar)
returns varchar
language javascript
execute as owner
as 
$$
var env_full_ar_name = SCHEMA_NAME.toUpperCase().split('.')[0] + '_FULL_AR';

//Remove existing RBAC by applying grants from the Access Definition table for "Full" access rights. These will be given
//to the Full Access role in the Sandbox.
//
//Add to those grants by applying Read-Write access to the sandbox's Read-write role, again using an access definition 
//table. 

var get_grants_template = "select command_text from def_schema_access_<access-type> where first_time_setup_ind = 'n' order by command_ordinal;";
var access_types = ['full', 'readwrite', 'read'];

var grants_dict = {};

for (let i = 0; i < access_types.length; i++) {

    var qry = snowflake.createStatement( { 
    
        sqlText: get_grants_template.replace('<access-type>', access_types[i]) 
        
    } );

    try {
        res = qry.execute();
    }

    catch (err) {
        return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
    }
    
    let grants_ls = [];

    while (res.next()) {
        grants_ls.push(res.getColumnValue(1));
    }

    grants_dict[ access_types[i] ] = grants_ls;
}

return JSON.stringify(grants_dict);
$$
;

-- example call
call grant_to_sandbox('SANDBOX_EDW_DB.RAW');
