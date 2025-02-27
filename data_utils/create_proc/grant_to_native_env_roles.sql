use role sherlockwings_admin_fr;
use warehouse sherlockwings_compute_wh;
use schema sherlockwings_edw_db.util;

create or replace procedure sherlockwings_edw_db.util.grant_to_native_env_roles(SCHEMA_NAME varchar)
returns varchar
language javascript
execute as owner
as 
$$
var env_full_ar_name = SCHEMA_NAME.toUpperCase().split('.')[0] 

// Tiny exception with SANDBOX roles... usually we are trying to generate a role name like 
// <ENVNAME>_EDW_DB_<SCHEM_NAME>_FULL_AR. However, because the Sandbox environment only gets schema rights on-the-fly
// from sprocs, and the "native" rights are all DB level, the names for the roles in Sandbox have no <SCHEMA_NAME>
// infix like the ones in Dev/QA/Prod do. So we do this little thingy here to get around that.

if ( !SCHEMA_NAME.includes('SANDBOX') ) {
    env_full_ar_name += '_' + SCHEMA_NAME.toUpperCase().split('.')[1];
}

env_full_ar_name += '_FULL_AR';

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
-- call grant_to_native_env_roles('SANDBOX_EDW_DB.RAW');
