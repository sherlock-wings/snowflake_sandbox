use role sherlockwings_admin_fr;
use warehouse sherlockwings_compute_wh;

create or replace procedure sherlockwings_edw_db.util.get_sql_result(QUERY_TEXT varchar)
returns variant
language javascript
execute as caller 
as
$$
var qry = snowflake.createStatement( { 

    sqlText: QUERY_TEXT 
    
} );

try {
    res = qry.execute();
}

catch (err) {
    return "Failed executing statement `"+qry.getSqlText()+"`. Error message: `" + err + "`";
}

// Log query that is executed as an event in SNOWFLAKE.TELEMETRY.EVENTS

snowflake.setSpanAttribute("query", qry.getSqlText());

var col_count = res.getColumnCount();
var rows = {};

for (let i = 0; i < col_count; i++) {

    rows[ res.getColumnName(i+1) ] = [];
        
}

while (res.next()) {

    for (let i = 0; i < col_count; i++) {
    
        rows[ res.getColumnName(i+1) ].push( res.getColumnValue(i+1) );
    
    }

}

return rows;
$$
;

*/

-- call sherlockwings_edw_db.util.get_sql_result('select * from sherlockwings_edw_db.util.def_schema_access_read');
